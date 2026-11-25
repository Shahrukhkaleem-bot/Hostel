-- Hostel Buddy: complete seeker backend.
-- Prerequisite: 20261109_manager_backend.sql. Idempotent.
--
-- Adds:  hostel_reviews (7th table) · coins wallet on profiles · offer unlock
--        flow · browse/search/detail RPCs · seeker dashboard/bids/offers RPCs
-- Locks: hostels.contact is no longer publicly readable. It is only returned by
--        RPCs to the owner, or to a seeker who unlocked/accepted that hostel's offer.

-- ───────────────────────── wallet ─────────────────────────
alter table public.profiles
  add column if not exists coins integer not null default 500 check (coins >= 0);
-- No UPDATE policy exists on profiles, so clients can never edit their balance.

-- ───────────────────────── offers: unlock + decline reason ─────────────────────────
alter table public.bid_offers
  add column if not exists unlocked_at   timestamptz,
  add column if not exists decline_reason text;

create index if not exists bid_offers_bid_status_idx
  on public.bid_offers (bid_id, status);

-- ───────────────────────── 7. hostel_reviews ─────────────────────────
create table if not exists public.hostel_reviews (
  id           uuid primary key default gen_random_uuid(),
  hostel_id    uuid not null references public.hostels (id) on delete cascade,
  seeker_id    uuid not null references auth.users (id) on delete cascade,
  offer_id     uuid not null unique references public.bid_offers (id) on delete cascade,
  cleanliness  smallint check (cleanliness between 1 and 5),
  staff        smallint check (staff between 1 and 5),
  value        smallint check (value between 1 and 5),
  location     smallint check (location between 1 and 5),
  amenities    smallint check (amenities between 1 and 5),
  rating       numeric(2, 1) not null check (rating between 1 and 5),
  comment      text not null default '' check (char_length(comment) <= 1000),
  created_at   timestamptz not null default now()
);
create index if not exists hostel_reviews_hostel_idx
  on public.hostel_reviews (hostel_id, created_at desc);

alter table public.hostel_reviews enable row level security;
drop policy if exists "reviews readable" on public.hostel_reviews;
create policy "reviews readable" on public.hostel_reviews for select using (true);
-- Writes only through submit_review().

-- Denormalised rating on hostels keeps browse queries cheap.
alter table public.hostels
  add column if not exists rating_avg   numeric(2, 1),
  add column if not exists rating_count integer not null default 0;

create or replace function public.refresh_hostel_rating()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_hostel uuid := coalesce(new.hostel_id, old.hostel_id);
begin
  update public.hostels h
     set rating_avg   = (select round(avg(rating), 1) from public.hostel_reviews where hostel_id = v_hostel),
         rating_count = (select count(*) from public.hostel_reviews where hostel_id = v_hostel)
   where h.id = v_hostel;
  return null;
end $$;
drop trigger if exists hostel_reviews_rating on public.hostel_reviews;
create trigger hostel_reviews_rating
  after insert or delete on public.hostel_reviews
  for each row execute function public.refresh_hostel_rating();

-- ───────────────────────── lock hostels.contact ─────────────────────────
-- (If you add columns to hostels later, grant select on them too.)
do $$
declare cols text;
begin
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position) into cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'hostels' and column_name <> 'contact';
  execute 'revoke select on public.hostels from anon, authenticated';
  execute format('grant select (%s) on public.hostels to anon, authenticated', cols);
end $$;

-- Owner's own contact numbers (for the edit screen).
create or replace function public.my_hostel_contacts()
returns table (hostel_id uuid, contact text)
language sql stable security definer set search_path = public as $$
  select h.id, h.contact from public.hostels h where h.owner_id = auth.uid();
$$;

-- Contact for one hostel: owner, or a seeker who unlocked/accepted its offer.
create or replace function public.get_hostel_contact(p_hostel_id uuid)
returns text language plpgsql stable security definer set search_path = public as $$
declare v_contact text;
begin
  select h.contact into v_contact
    from public.hostels h
   where h.id = p_hostel_id
     and (
       h.owner_id = auth.uid()
       or exists (
         select 1
           from public.bid_offers o
           join public.bids b on b.id = o.bid_id
          where o.hostel_id = h.id
            and b.seeker_id = auth.uid()
            and (o.unlocked_at is not null or o.status = 'accepted')
       )
     );
  return v_contact;
end $$;

-- ───────────────────────── bids: protect priced offers ─────────────────────────
create or replace function public.bids_before_update()
returns trigger language plpgsql as $$
begin
  if (new.offer_amount, new.seater_label, new.hostel_type)
       is distinct from (old.offer_amount, old.seater_label, old.hostel_type)
     and exists (
       select 1 from public.bid_offers o
        where o.bid_id = old.id and o.status in ('offered', 'accepted')
     ) then
    raise exception 'This bid already has offers, so it can no longer be edited.';
  end if;
  return new;
end $$;
drop trigger if exists bids_before_update on public.bids;
create trigger bids_before_update before update on public.bids
  for each row execute function public.bids_before_update();

-- ───────────────────────── browse / search / detail ─────────────────────────
create or replace function public.browse_hostels(
  p_city     text    default null,
  p_type     text    default null,
  p_query    text    default null,
  p_seater   integer default null,
  p_max_rent integer default null,
  p_limit    integer default 30,
  p_offset   integer default 0
)
returns table (
  id            uuid,
  name          text,
  hostel_type   text,
  city          text,
  area          text,
  facilities    text[],
  photo_url     text,
  rating_avg    numeric,
  rating_count  integer,
  min_rent      integer,
  vacant_rooms  bigint
)
language sql stable set search_path = public as $$
  select h.id, h.name, h.hostel_type, h.city, h.area, h.facilities,
         h.photo_urls[1], h.rating_avg, h.rating_count,
         r.min_rent, coalesce(r.vacant, 0)
    from public.hostels h
    left join lateral (
      select min(rent) filter (where rent > 0) as min_rent, count(*) as vacant
        from public.rooms
       where hostel_id = h.id and status = 'vacant'
         and (p_seater is null or seater = p_seater)
    ) r on true
   where h.is_active
     and (p_city is null or btrim(p_city) = '' or h.city_key = lower(btrim(p_city)))
     and (p_type is null or p_type = '' or h.hostel_type = p_type)
     and (p_query is null or btrim(p_query) = ''
          or h.name ilike '%' || btrim(p_query) || '%'
          or h.area ilike '%' || btrim(p_query) || '%')
     and (p_seater is null or r.vacant > 0)
     and (p_max_rent is null or r.min_rent <= p_max_rent)
   order by (r.vacant > 0) desc, h.rating_avg desc nulls last, h.created_at desc
   limit least(greatest(p_limit, 1), 100)
  offset greatest(p_offset, 0);
$$;

create or replace function public.hostel_detail(p_hostel_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  select jsonb_build_object(
    'id', h.id, 'name', h.name, 'hostel_type', h.hostel_type,
    'city', h.city, 'area', h.area, 'description', h.description,
    'facilities', h.facilities, 'room_types', h.room_types, 'photo_urls', h.photo_urls,
    'rating_avg', h.rating_avg, 'rating_count', h.rating_count,
    'rooms', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'seater', x.seater, 'vacant', x.vacant, 'total', x.total, 'min_rent', x.min_rent)
               order by x.seater)
          from (
            select seater,
                   count(*) filter (where status = 'vacant') as vacant,
                   count(*) as total,
                   min(rent) filter (where rent > 0) as min_rent
              from public.rooms where hostel_id = h.id group by seater
          ) x), '[]'::jsonb),
    'reviews', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'name', split_part(coalesce(nullif(p.full_name, ''), 'Guest'), ' ', 1),
                 'rating', r.rating, 'comment', r.comment, 'created_at', r.created_at)
               order by r.created_at desc)
          from (select * from public.hostel_reviews
                 where hostel_id = h.id order by created_at desc limit 10) r
          left join public.profiles p on p.id = r.seeker_id), '[]'::jsonb)
  ) into v
  from public.hostels h
  where h.id = p_hostel_id and (h.is_active or h.owner_id = auth.uid());
  return v;
end $$;

-- ───────────────────────── seeker dashboard / lists ─────────────────────────
create or replace function public.seeker_dashboard()
returns table (open_bids bigint, offers_received bigint, accepted_deals bigint, avg_offer integer, coins integer)
language sql stable security definer set search_path = public as $$
  select
    (select count(*) from public.bids b
      where b.seeker_id = auth.uid() and b.status = 'open' and b.expires_at > now()),
    (select count(*) from public.bid_offers o join public.bids b on b.id = o.bid_id
      where b.seeker_id = auth.uid() and o.status = 'offered' and o.unlocked_at is null
        and b.status = 'open' and b.expires_at > now()),
    (select count(*) from public.bid_offers o join public.bids b on b.id = o.bid_id
      where b.seeker_id = auth.uid() and o.status = 'accepted'),
    (select round(avg(b.offer_amount))::integer from public.bids b
      where b.seeker_id = auth.uid() and b.status = 'open' and b.expires_at > now()),
    (select p.coins from public.profiles p where p.id = auth.uid());
$$;

create or replace function public.seeker_my_bids()
returns table (
  id uuid, city text, hostel_type text, seater_label text, amenities text[],
  offer_amount integer, status text, created_at timestamptz, expires_at timestamptz,
  offer_count bigint
)
language sql stable security definer set search_path = public as $$
  select b.id, b.city, b.hostel_type, b.seater_label, b.amenities, b.offer_amount,
         b.status, b.created_at, b.expires_at,
         (select count(*) from public.bid_offers o where o.bid_id = b.id and o.status = 'offered')
    from public.bids b
   where b.seeker_id = auth.uid()
     and (b.status = 'closed' or (b.status = 'open' and b.expires_at > now()))
   order by b.created_at desc;
$$;

-- tab: received (not unlocked) · pending (unlocked, awaiting decision) · closed (accepted)
create or replace function public.seeker_offers()
returns table (
  offer_id uuid, bid_id uuid, hostel_id uuid, hostel_name text, area text, city text,
  hostel_type text, seater_label text, bid_amount integer, offered_price integer,
  tab text, contact text, offered_at timestamptz, reviewed boolean, my_rating numeric
)
language sql stable security definer set search_path = public as $$
  select o.id, b.id, h.id, h.name, h.area, h.city, h.hostel_type, b.seater_label,
         b.offer_amount, o.offered_price,
         case when o.status = 'accepted' then 'closed'
              when o.unlocked_at is not null then 'pending'
              else 'received' end,
         case when o.unlocked_at is not null or o.status = 'accepted' then h.contact end,
         o.updated_at, rv.id is not null, rv.rating
    from public.bid_offers o
    join public.bids b on b.id = o.bid_id
    join public.hostels h on h.id = o.hostel_id
    left join public.hostel_reviews rv on rv.offer_id = o.id
   where b.seeker_id = auth.uid()
     and (o.status = 'accepted'
          or (o.status = 'offered' and b.status = 'open' and b.expires_at > now()))
   order by o.updated_at desc;
$$;

-- ───────────────────────── seeker actions ─────────────────────────
-- Spend 100 coins to reveal the hostel's contact and move the offer to "pending".
create or replace function public.unlock_offer(p_offer_id uuid)
returns table (coins integer, contact text)
language plpgsql security definer set search_path = public as $$
declare
  c_cost constant integer := 100;
  v_offer public.bid_offers;
  v_bid   public.bids;
  v_host  public.hostels;
  v_coins integer;
begin
  select * into v_offer from public.bid_offers where id = p_offer_id for update;
  if not found or v_offer.status <> 'offered' then
    raise exception 'Offer is not available.';
  end if;
  select * into v_bid from public.bids where id = v_offer.bid_id;
  if v_bid.seeker_id <> auth.uid() then
    raise exception 'Not your bid.' using errcode = '42501';
  end if;
  if v_bid.status <> 'open' or v_bid.expires_at <= now() then
    raise exception 'This bid has expired.';
  end if;
  select * into v_host from public.hostels where id = v_offer.hostel_id;

  select p.coins into v_coins from public.profiles p where p.id = auth.uid() for update;
  if v_offer.unlocked_at is null then
    if v_coins is null or v_coins < c_cost then
      raise exception 'Not enough coins. You need % coins to continue.', c_cost;
    end if;
    update public.profiles set coins = profiles.coins - c_cost where id = auth.uid()
      returning profiles.coins into v_coins;
    update public.bid_offers set unlocked_at = now() where id = p_offer_id;

    insert into public.notifications (user_id, type, title, body, data)
    values (v_offer.manager_id, 'offer', 'A seeker is interested',
            'A seeker unlocked your Rs ' || v_offer.offered_price || '/mo offer for ' || v_host.name || '.',
            jsonb_build_object('bid_id', v_bid.id, 'offer_id', p_offer_id, 'hostel_id', v_host.id));
  end if;

  return query select v_coins, v_host.contact;
end $$;

create or replace function public.decline_offer(p_offer_id uuid, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_offer public.bid_offers;
  v_seeker uuid;
  v_host text;
begin
  select * into v_offer from public.bid_offers where id = p_offer_id for update;
  if not found or v_offer.status <> 'offered' then
    raise exception 'Offer is not available.';
  end if;
  select seeker_id into v_seeker from public.bids where id = v_offer.bid_id;
  if v_seeker <> auth.uid() then
    raise exception 'Not your bid.' using errcode = '42501';
  end if;

  update public.bid_offers
     set status = 'declined', decline_reason = nullif(btrim(left(p_reason, 300)), '')
   where id = p_offer_id;

  select name into v_host from public.hostels where id = v_offer.hostel_id;
  insert into public.notifications (user_id, type, title, body, data)
  values (v_offer.manager_id, 'offer', 'Offer declined',
          'A seeker declined your offer for ' || v_host
            || coalesce(' (' || nullif(btrim(left(p_reason, 100)), '') || ')', '') || '.',
          jsonb_build_object('offer_id', p_offer_id, 'hostel_id', v_offer.hostel_id));
end $$;

-- Replaces the earlier version: the offer must be unlocked first, and one
-- matching vacant room is reserved so the manager's dashboard stays accurate.
create or replace function public.accept_offer(p_offer_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_offer public.bid_offers;
  v_bid   public.bids;
  v_host  text;
  v_room  uuid;
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
  if v_offer.unlocked_at is null then
    raise exception 'Continue with this offer first (it costs coins) before accepting.';
  end if;

  update public.bid_offers set status = 'accepted' where id = p_offer_id;
  update public.bid_offers set status = 'declined'
   where bid_id = v_bid.id and id <> p_offer_id and status = 'offered';
  update public.bids set status = 'closed' where id = v_bid.id;

  select id into v_room from public.rooms
   where hostel_id = v_offer.hostel_id and status = 'vacant'
     and (v_bid.seater is null or seater = v_bid.seater)
   order by rent
   limit 1 for update skip locked;
  if v_room is not null then
    update public.rooms set status = 'reserved' where id = v_room;
  end if;

  select name into v_host from public.hostels where id = v_offer.hostel_id;
  insert into public.notifications (user_id, type, title, body, data)
  values (v_offer.manager_id, 'offer', 'Offer accepted',
          'A seeker accepted your Rs ' || v_offer.offered_price || '/mo offer for ' || v_host || '.',
          jsonb_build_object('bid_id', v_bid.id, 'offer_id', p_offer_id, 'hostel_id', v_offer.hostel_id));
end $$;

create or replace function public.submit_review(
  p_offer_id    uuid,
  p_cleanliness integer default null,
  p_staff       integer default null,
  p_value       integer default null,
  p_location    integer default null,
  p_amenities   integer default null,
  p_comment     text    default ''
)
returns numeric language plpgsql security definer set search_path = public as $$
declare
  v_offer public.bid_offers;
  v_seeker uuid;
  v_avg numeric;
  v_host text;
begin
  select * into v_offer from public.bid_offers where id = p_offer_id;
  if not found or v_offer.status <> 'accepted' then
    raise exception 'You can only review a hostel after accepting its offer.';
  end if;
  select seeker_id into v_seeker from public.bids where id = v_offer.bid_id;
  if v_seeker <> auth.uid() then
    raise exception 'Not your deal.' using errcode = '42501';
  end if;

  select round(avg(x)::numeric, 1) into v_avg
    from unnest(array[p_cleanliness, p_staff, p_value, p_location, p_amenities]) x
   where x between 1 and 5;
  if v_avg is null then
    raise exception 'Give at least one star rating.';
  end if;

  begin
    insert into public.hostel_reviews
      (hostel_id, seeker_id, offer_id, cleanliness, staff, value, location, amenities, rating, comment)
    values
      (v_offer.hostel_id, auth.uid(), p_offer_id,
       nullif(p_cleanliness, 0), nullif(p_staff, 0), nullif(p_value, 0),
       nullif(p_location, 0), nullif(p_amenities, 0), v_avg, coalesce(btrim(p_comment), ''));
  exception when unique_violation then
    raise exception 'You already reviewed this hostel.';
  end;

  select name into v_host from public.hostels where id = v_offer.hostel_id;
  insert into public.notifications (user_id, type, title, body, data)
  values (v_offer.manager_id, 'system', 'New review',
          'You received a ' || v_avg || '★ review for ' || v_host || '.',
          jsonb_build_object('hostel_id', v_offer.hostel_id));
  return v_avg;
end $$;

-- ───────────────────────── privileges ─────────────────────────
revoke all on function public.refresh_hostel_rating() from public, anon, authenticated;
revoke execute on function
  public.my_hostel_contacts(),
  public.get_hostel_contact(uuid),
  public.browse_hostels(text, text, text, integer, integer, integer, integer),
  public.hostel_detail(uuid),
  public.seeker_dashboard(),
  public.seeker_my_bids(),
  public.seeker_offers(),
  public.unlock_offer(uuid),
  public.decline_offer(uuid, text),
  public.submit_review(uuid, integer, integer, integer, integer, integer, text)
from public, anon;
grant execute on function
  public.my_hostel_contacts(),
  public.get_hostel_contact(uuid),
  public.browse_hostels(text, text, text, integer, integer, integer, integer),
  public.hostel_detail(uuid),
  public.seeker_dashboard(),
  public.seeker_my_bids(),
  public.seeker_offers(),
  public.unlock_offer(uuid),
  public.decline_offer(uuid, text),
  public.submit_review(uuid, integer, integer, integer, integer, integer, text)
to authenticated;
