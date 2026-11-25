-- Hostel Buddy: complete manager backend.
-- Prerequisite: supabase/hostels.sql (creates public.hostels + hostel-photos bucket).
-- Idempotent: safe to run more than once.
--
-- Tables (6):  profiles · hostels · rooms · bids · bid_offers · notifications
-- Writes that touch more than one row/table go through SECURITY DEFINER RPCs,
-- so clients can never forge offers, notifications or other users' data.

-- ───────────────────────── helpers ─────────────────────────
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ───────────────────────── 1. profiles ─────────────────────────
-- Mirror of auth.users metadata so other users' names can be joined safely.
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null default '',
  phone       text not null default '',
  city        text not null default '',
  role        text check (role in ('seeker', 'manager')),
  occupation  text,
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create or replace function public.sync_profile()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.profiles (id, full_name, phone, city, role, occupation, avatar_url)
  values (
    new.id,
    coalesce(nullif(m->>'full_name', ''), nullif(m->>'name', ''), ''),
    coalesce(nullif(m->>'phone', ''), new.phone, ''),
    coalesce(m->>'city', ''),
    case when m->>'role' in ('seeker', 'manager') then m->>'role' end,
    nullif(m->>'occupation', ''),
    coalesce(nullif(m->>'avatar_url', ''), nullif(m->>'picture', ''))
  )
  on conflict (id) do update set
    full_name  = excluded.full_name,
    phone      = excluded.phone,
    city       = excluded.city,
    role       = excluded.role,
    occupation = excluded.occupation,
    avatar_url = excluded.avatar_url,
    updated_at = now();
  return new;
end $$;

drop trigger if exists on_auth_user_sync on auth.users;
create trigger on_auth_user_sync
  after insert or update of raw_user_meta_data on auth.users
  for each row execute function public.sync_profile();

-- Backfill users that signed up before this migration.
insert into public.profiles (id, full_name, phone, city, role, occupation, avatar_url)
select u.id,
       coalesce(nullif(u.raw_user_meta_data->>'full_name', ''), nullif(u.raw_user_meta_data->>'name', ''), ''),
       coalesce(nullif(u.raw_user_meta_data->>'phone', ''), u.phone, ''),
       coalesce(u.raw_user_meta_data->>'city', ''),
       case when u.raw_user_meta_data->>'role' in ('seeker', 'manager') then u.raw_user_meta_data->>'role' end,
       nullif(u.raw_user_meta_data->>'occupation', ''),
       coalesce(nullif(u.raw_user_meta_data->>'avatar_url', ''), nullif(u.raw_user_meta_data->>'picture', ''))
from auth.users u
on conflict (id) do nothing;

alter table public.profiles enable row level security;
drop policy if exists "own profile read" on public.profiles;
create policy "own profile read" on public.profiles
  for select using (id = (select auth.uid()));

-- ───────────────────────── 2. hostels (extend) ─────────────────────────
alter table public.hostels
  add column if not exists is_active  boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();

-- Lower-cased city for index-friendly, case-insensitive matching.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'hostels' and column_name = 'city_key'
  ) then
    alter table public.hostels
      add column city_key text generated always as (lower(btrim(city))) stored;
  end if;
end $$;

drop index if exists public.hostels_city_idx;
create index if not exists hostels_match_idx
  on public.hostels (city_key, hostel_type) where is_active;
create unique index if not exists hostels_owner_name_city_uq
  on public.hostels (owner_id, lower(btrim(name)), city_key);

drop trigger if exists hostels_updated_at on public.hostels;
create trigger hostels_updated_at before update on public.hostels
  for each row execute function public.set_updated_at();

drop policy if exists "hostels are readable" on public.hostels;
drop policy if exists "owner inserts"        on public.hostels;
drop policy if exists "owner updates"        on public.hostels;
drop policy if exists "owner deletes"        on public.hostels;
create policy "hostels readable" on public.hostels
  for select using (is_active or owner_id = (select auth.uid()));
create policy "owner inserts" on public.hostels
  for insert with check (owner_id = (select auth.uid()));
create policy "owner updates" on public.hostels
  for update using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy "owner deletes" on public.hostels
  for delete using (owner_id = (select auth.uid()));

create or replace function public.owns_hostel(p_hostel_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.hostels h
    where h.id = p_hostel_id and h.owner_id = auth.uid()
  );
$$;

-- ───────────────────────── 3. rooms ─────────────────────────
create table if not exists public.rooms (
  id           uuid primary key default gen_random_uuid(),
  hostel_id    uuid not null references public.hostels (id) on delete cascade,
  room_number  text not null check (char_length(btrim(room_number)) between 1 and 20),
  floor        smallint not null default 1 check (floor between -2 and 50),
  seater       smallint not null default 2 check (seater between 1 and 20),
  rent         integer  not null default 0 check (rent >= 0),
  status       text     not null default 'vacant' check (status in ('vacant', 'occupied', 'reserved')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (hostel_id, room_number)
);

-- Covering index: dashboard stats + room list filters are index-only scans.
create index if not exists rooms_hostel_status_idx
  on public.rooms (hostel_id, status) include (rent, seater);

drop trigger if exists rooms_updated_at on public.rooms;
create trigger rooms_updated_at before update on public.rooms
  for each row execute function public.set_updated_at();

alter table public.rooms enable row level security;
drop policy if exists "rooms readable"  on public.rooms;
drop policy if exists "owner adds room" on public.rooms;
drop policy if exists "owner edits room" on public.rooms;
drop policy if exists "owner deletes room" on public.rooms;
create policy "rooms readable" on public.rooms
  for select using (
    public.owns_hostel(hostel_id)
    or exists (select 1 from public.hostels h where h.id = hostel_id and h.is_active)
  );
create policy "owner adds room" on public.rooms
  for insert with check (public.owns_hostel(hostel_id));
create policy "owner edits room" on public.rooms
  for update using (public.owns_hostel(hostel_id))
  with check (public.owns_hostel(hostel_id));
create policy "owner deletes room" on public.rooms
  for delete using (public.owns_hostel(hostel_id));

-- Rooms can't be moved between hostels.
create or replace function public.rooms_lock_hostel()
returns trigger language plpgsql as $$
begin
  if new.hostel_id <> old.hostel_id then
    raise exception 'A room cannot be moved to another hostel.';
  end if;
  return new;
end $$;
drop trigger if exists rooms_lock_hostel on public.rooms;
create trigger rooms_lock_hostel before update of hostel_id on public.rooms
  for each row execute function public.rooms_lock_hostel();

-- ───────────────────────── 4. bids (seeker requests) ─────────────────────────
create table if not exists public.bids (
  id            uuid primary key default gen_random_uuid(),
  seeker_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  city          text not null check (char_length(btrim(city)) > 0),
  city_key      text generated always as (lower(btrim(city))) stored,
  hostel_type   text not null check (hostel_type in ('Boys Hostel', 'Girls Hostel')),
  seater_label  text not null check (char_length(btrim(seater_label)) > 0),
  seater        smallint check (seater between 1 and 20),   -- null for custom labels
  amenities     text[] not null default '{}',
  offer_amount  integer not null check (offer_amount > 0),
  status        text not null default 'open' check (status in ('open', 'closed', 'cancelled')),
  expires_at    timestamptz not null default now() + interval '24 hours',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists bids_match_idx
  on public.bids (city_key, hostel_type, created_at desc) where status = 'open';
create index if not exists bids_seeker_idx
  on public.bids (seeker_id, created_at desc);

drop trigger if exists bids_updated_at on public.bids;
create trigger bids_updated_at before update on public.bids
  for each row execute function public.set_updated_at();

-- Server decides lifetime/status; clients cannot back-date or pre-close a bid.
create or replace function public.bids_before_insert()
returns trigger language plpgsql as $$
begin
  new.status     := 'open';
  new.created_at := now();
  new.expires_at := now() + interval '24 hours';
  return new;
end $$;
drop trigger if exists bids_before_insert on public.bids;
create trigger bids_before_insert before insert on public.bids
  for each row execute function public.bids_before_insert();

alter table public.bids enable row level security;
drop policy if exists "seeker reads own bids"   on public.bids;
drop policy if exists "seeker places bid"       on public.bids;
drop policy if exists "seeker edits own bid"    on public.bids;
drop policy if exists "seeker deletes own bid"  on public.bids;
create policy "seeker reads own bids" on public.bids
  for select using (seeker_id = (select auth.uid()));
create policy "seeker places bid" on public.bids
  for insert with check (seeker_id = (select auth.uid()));
create policy "seeker edits own bid" on public.bids
  for update using (seeker_id = (select auth.uid()) and status = 'open')
  with check (seeker_id = (select auth.uid()));
create policy "seeker deletes own bid" on public.bids
  for delete using (seeker_id = (select auth.uid()));

-- Seekers may only change these columns.
revoke update on public.bids from authenticated, anon;
grant update (hostel_type, seater_label, seater, amenities, offer_amount, status)
  on public.bids to authenticated;

-- ───────────────────────── 5. bid_offers (manager responses) ─────────────────────────
create table if not exists public.bid_offers (
  id             uuid primary key default gen_random_uuid(),
  bid_id         uuid not null references public.bids (id) on delete cascade,
  hostel_id      uuid not null references public.hostels (id) on delete cascade,
  manager_id     uuid not null references auth.users (id) on delete cascade,
  status         text not null check (status in ('offered', 'rejected', 'accepted', 'declined', 'withdrawn')),
  offered_price  integer check (offered_price > 0),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (bid_id, hostel_id),
  check (status in ('rejected', 'withdrawn') or offered_price is not null)
);

create index if not exists bid_offers_hostel_idx
  on public.bid_offers (hostel_id, status, updated_at desc);
create index if not exists bid_offers_manager_idx
  on public.bid_offers (manager_id);

drop trigger if exists bid_offers_updated_at on public.bid_offers;
create trigger bid_offers_updated_at before update on public.bid_offers
  for each row execute function public.set_updated_at();

alter table public.bid_offers enable row level security;
drop policy if exists "manager reads own offers" on public.bid_offers;
drop policy if exists "seeker reads offers on own bids" on public.bid_offers;
create policy "manager reads own offers" on public.bid_offers
  for select using (manager_id = (select auth.uid()));
create policy "seeker reads offers on own bids" on public.bid_offers
  for select using (
    status in ('offered', 'accepted', 'declined')
    and exists (
      select 1 from public.bids b
      where b.id = bid_id and b.seeker_id = (select auth.uid())
    )
  );
-- No insert/update/delete policies: all writes go through the RPCs below.

-- ───────────────────────── 6. notifications ─────────────────────────
create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  type        text not null default 'system' check (type in ('bid', 'offer', 'system', 'chat')),
  title       text not null,
  body        text not null default '',
  data        jsonb not null default '{}'::jsonb,
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);
create index if not exists notifications_unread_idx
  on public.notifications (user_id) where not is_read;

alter table public.notifications enable row level security;
drop policy if exists "own notifications read"   on public.notifications;
drop policy if exists "own notifications update" on public.notifications;
drop policy if exists "own notifications delete" on public.notifications;
create policy "own notifications read" on public.notifications
  for select using (user_id = (select auth.uid()));
create policy "own notifications update" on public.notifications
  for update using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "own notifications delete" on public.notifications
  for delete using (user_id = (select auth.uid()));

revoke update on public.notifications from authenticated, anon;
grant update (is_read) on public.notifications to authenticated;

-- ───────────────────────── triggers: fan-out notifications ─────────────────────────
-- New bid → notify the owner of every active hostel that matches (city + type),
-- and confirm to the seeker.
create or replace function public.bids_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (user_id, type, title, body, data)
  select h.owner_id, 'bid', 'New bid in ' || new.city,
         new.seater_label || ' · Rs ' || new.offer_amount || '/mo for ' || h.name,
         jsonb_build_object('bid_id', new.id, 'hostel_id', h.id)
  from public.hostels h
  where h.is_active
    and h.city_key = new.city_key
    and h.hostel_type = new.hostel_type
    and h.owner_id <> new.seeker_id;

  insert into public.notifications (user_id, type, title, body, data)
  values (new.seeker_id, 'bid', 'Bid placed successfully',
          'Your bid for ' || new.seater_label || ' at Rs ' || new.offer_amount || '/mo is now live.',
          jsonb_build_object('bid_id', new.id));
  return new;
end $$;
drop trigger if exists bids_after_insert on public.bids;
create trigger bids_after_insert after insert on public.bids
  for each row execute function public.bids_after_insert();

-- ───────────────────────── RPC: manager side ─────────────────────────

-- Dashboard numbers for one hostel in a single round trip.
create or replace function public.manager_dashboard(p_hostel_id uuid)
returns table (
  declared_rooms   integer,
  total_rooms      bigint,
  vacant_rooms     bigint,
  occupied_rooms   bigint,
  reserved_rooms   bigint,
  pending_bids     bigint,
  offered_bids     bigint,
  accepted_bids    bigint,
  monthly_revenue  bigint
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.owns_hostel(p_hostel_id) then
    raise exception 'Not your hostel.' using errcode = '42501';
  end if;

  return query
  with h as (
    select * from public.hostels where id = p_hostel_id
  ),
  r as (
    select count(*)                                          as total,
           count(*) filter (where status = 'vacant')         as vacant,
           count(*) filter (where status = 'occupied')       as occupied,
           count(*) filter (where status = 'reserved')       as reserved,
           coalesce(sum(rent) filter (where status = 'occupied'), 0) as revenue
    from public.rooms where hostel_id = p_hostel_id
  ),
  o as (
    select count(*) filter (where status = 'offered')  as offered,
           count(*) filter (where status = 'accepted') as accepted
    from public.bid_offers where hostel_id = p_hostel_id
  ),
  p as (
    select count(*) as pending
    from public.bids b, h
    where b.status = 'open' and b.expires_at > now()
      and b.city_key = h.city_key and b.hostel_type = h.hostel_type
      and not exists (
        select 1 from public.bid_offers x
        where x.bid_id = b.id and x.hostel_id = h.id
      )
  )
  select h.total_rooms, r.total, r.vacant, r.occupied, r.reserved,
         p.pending, o.offered, o.accepted, r.revenue::bigint
  from h, r, o, p;
end $$;

-- Inbox: p_status = pending | offered | accepted | all
create or replace function public.manager_incoming_bids(
  p_hostel_id uuid,
  p_status    text default 'pending',
  p_search    text default null,
  p_limit     integer default 50,
  p_offset    integer default 0
)
returns table (
  bid_id             uuid,
  seeker_name        text,
  seeker_phone       text,
  seater_label       text,
  seater             smallint,
  amenities          text[],
  offer_amount       integer,
  bid_created_at     timestamptz,
  expires_at         timestamptz,
  offer_id           uuid,
  response_status    text,
  offered_price      integer,
  has_matching_room  boolean
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.owns_hostel(p_hostel_id) then
    raise exception 'Not your hostel.' using errcode = '42501';
  end if;
  if p_status not in ('pending', 'offered', 'accepted', 'all') then
    raise exception 'Invalid status filter.';
  end if;

  return query
  select b.id,
         coalesce(nullif(pr.full_name, ''), 'Seeker'),
         case when o.status = 'accepted' then pr.phone end,
         b.seater_label, b.seater, b.amenities, b.offer_amount,
         b.created_at, b.expires_at,
         o.id,
         coalesce(o.status, 'pending'),
         o.offered_price,
         (b.seater is not null and exists (
            select 1 from public.rooms r
            where r.hostel_id = h.id and r.status = 'vacant' and r.seater = b.seater
          ))
  from public.hostels h
  join public.bids b
    on b.city_key = h.city_key and b.hostel_type = h.hostel_type
  left join public.bid_offers o
    on o.bid_id = b.id and o.hostel_id = h.id
  left join public.profiles pr on pr.id = b.seeker_id
  where h.id = p_hostel_id
    and (
      (p_status = 'pending'  and o.id is null and b.status = 'open' and b.expires_at > now())
      or (p_status = 'offered'  and o.status = 'offered')
      or (p_status = 'accepted' and o.status = 'accepted')
      or (p_status = 'all' and (
            (o.id is null and b.status = 'open' and b.expires_at > now())
            or o.status in ('offered', 'accepted')))
    )
    and (
      p_search is null or btrim(p_search) = ''
      or pr.full_name ilike '%' || btrim(p_search) || '%'
      or b.seater_label ilike '%' || btrim(p_search) || '%'
      or b.offer_amount::text like '%' || btrim(p_search) || '%'
    )
  order by coalesce(o.updated_at, b.created_at) desc
  limit least(greatest(p_limit, 1), 200)
  offset greatest(p_offset, 0);
end $$;

-- Accept at the same price or counter with a higher one.
create or replace function public.respond_to_bid(
  p_bid_id uuid, p_hostel_id uuid, p_price integer
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_bid   public.bids;
  v_host  public.hostels;
  v_offer uuid;
  v_old   text;
begin
  select * into v_host from public.hostels
   where id = p_hostel_id and owner_id = auth.uid();
  if not found then
    raise exception 'Not your hostel.' using errcode = '42501';
  end if;

  select * into v_bid from public.bids where id = p_bid_id for update;
  if not found then raise exception 'Bid not found.'; end if;
  if v_bid.status <> 'open' or v_bid.expires_at <= now() then
    raise exception 'This bid is no longer open.';
  end if;
  if v_bid.city_key <> v_host.city_key or v_bid.hostel_type <> v_host.hostel_type then
    raise exception 'This bid does not match your hostel.';
  end if;
  if p_price is null or p_price < v_bid.offer_amount then
    raise exception 'Price must be the same or higher than the seeker offer.';
  end if;

  select status into v_old from public.bid_offers
   where bid_id = p_bid_id and hostel_id = p_hostel_id;
  if v_old = 'accepted' then
    raise exception 'This offer was already accepted.';
  end if;

  insert into public.bid_offers (bid_id, hostel_id, manager_id, status, offered_price)
  values (p_bid_id, p_hostel_id, auth.uid(), 'offered', p_price)
  on conflict (bid_id, hostel_id) do update
    set status = 'offered', offered_price = excluded.offered_price
  returning id into v_offer;

  insert into public.notifications (user_id, type, title, body, data)
  values (v_bid.seeker_id, 'offer', 'New offer received',
          v_host.name || ' offered Rs ' || p_price || '/mo on your ' || v_bid.seater_label || ' bid.',
          jsonb_build_object('bid_id', p_bid_id, 'offer_id', v_offer, 'hostel_id', p_hostel_id));

  return v_offer;
end $$;

-- Reject = hide this bid from my inbox (the seeker is not notified).
create or replace function public.reject_bid(p_bid_id uuid, p_hostel_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.owns_hostel(p_hostel_id) then
    raise exception 'Not your hostel.' using errcode = '42501';
  end if;

  insert into public.bid_offers (bid_id, hostel_id, manager_id, status)
  values (p_bid_id, p_hostel_id, auth.uid(), 'rejected')
  on conflict (bid_id, hostel_id) do update
    set status = 'rejected', offered_price = null
    where public.bid_offers.status <> 'accepted';
end $$;

-- Delete a sent offer (before the seeker accepts it).
create or replace function public.withdraw_offer(p_offer_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare v_n integer;
begin
  update public.bid_offers
     set status = 'withdrawn'
   where id = p_offer_id and manager_id = auth.uid() and status = 'offered';
  get diagnostics v_n = row_count;
  if v_n = 0 then
    raise exception 'Offer not found or already accepted.';
  end if;
end $$;

-- ───────────────────────── RPC: seeker side ─────────────────────────

-- Seeker picks an offer: it wins, the others are declined, the bid closes.
create or replace function public.accept_offer(p_offer_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_offer public.bid_offers;
  v_bid   public.bids;
  v_host  text;
begin
  select * into v_offer from public.bid_offers where id = p_offer_id for update;
  if not found or v_offer.status <> 'offered' then
    raise exception 'Offer is not available.';
  end if;

  select * into v_bid from public.bids where id = v_offer.bid_id for update;
  if v_bid.seeker_id <> auth.uid() then
    raise exception 'Not your bid.' using errcode = '42501';
  end if;
  if v_bid.status <> 'open' then
    raise exception 'This bid is already closed.';
  end if;

  update public.bid_offers set status = 'accepted' where id = p_offer_id;
  update public.bid_offers set status = 'declined'
   where bid_id = v_bid.id and id <> p_offer_id and status = 'offered';
  update public.bids set status = 'closed' where id = v_bid.id;

  select name into v_host from public.hostels where id = v_offer.hostel_id;
  insert into public.notifications (user_id, type, title, body, data)
  values (v_offer.manager_id, 'offer', 'Offer accepted',
          'A seeker accepted your Rs ' || v_offer.offered_price || '/mo offer for ' || v_host || '.',
          jsonb_build_object('bid_id', v_bid.id, 'offer_id', p_offer_id, 'hostel_id', v_offer.hostel_id));
end $$;

-- ───────────────────────── maintenance ─────────────────────────
create or replace function public.expire_stale_bids()
returns integer language plpgsql security definer set search_path = public as $$
declare v_n integer;
begin
  update public.bids set status = 'cancelled'
   where status = 'open' and expires_at <= now();
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke all on function public.expire_stale_bids() from public, anon, authenticated;

-- ───────────────────────── privileges ─────────────────────────
revoke all on function public.sync_profile()        from public, anon, authenticated;
revoke all on function public.bids_after_insert()   from public, anon, authenticated;
revoke execute on function
  public.manager_dashboard(uuid),
  public.manager_incoming_bids(uuid, text, text, integer, integer),
  public.respond_to_bid(uuid, uuid, integer),
  public.reject_bid(uuid, uuid),
  public.withdraw_offer(uuid),
  public.accept_offer(uuid),
  public.owns_hostel(uuid)
from public, anon;
grant execute on function
  public.manager_dashboard(uuid),
  public.manager_incoming_bids(uuid, text, text, integer, integer),
  public.respond_to_bid(uuid, uuid, integer),
  public.reject_bid(uuid, uuid),
  public.withdraw_offer(uuid),
  public.accept_offer(uuid),
  public.owns_hostel(uuid)
to authenticated;

-- ───────────────────────── realtime ─────────────────────────
do $$
declare t text;
begin
  foreach t in array array['notifications', 'bids', 'bid_offers', 'rooms'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
