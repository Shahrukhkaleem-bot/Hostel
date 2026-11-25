-- Run once in the Supabase SQL editor.

create table if not exists public.hostels (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name         text not null check (char_length(trim(name)) > 0),
  hostel_type  text not null check (hostel_type in ('Boys Hostel', 'Girls Hostel')),
  city         text not null,
  area         text not null default '',
  contact      text not null default '',
  description  text not null default '',
  total_rooms  integer not null check (total_rooms between 1 and 200),
  room_types   text[] not null default '{}',
  facilities   text[] not null default '{}',
  photo_urls   text[] not null default '{}',
  created_at   timestamptz not null default now()
);

create index if not exists hostels_owner_idx on public.hostels (owner_id);
create index if not exists hostels_city_idx on public.hostels (city);

alter table public.hostels enable row level security;

-- Seekers browse every hostel; only the owner can change theirs.
create policy "hostels are readable" on public.hostels
  for select using (true);
create policy "owner inserts" on public.hostels
  for insert with check (auth.uid() = owner_id);
create policy "owner updates" on public.hostels
  for update using (auth.uid() = owner_id);
create policy "owner deletes" on public.hostels
  for delete using (auth.uid() = owner_id);

-- Photos: public bucket, each user writes only under their own uid/ folder.
insert into storage.buckets (id, name, public)
values ('hostel-photos', 'hostel-photos', true)
on conflict (id) do nothing;

create policy "hostel photos are readable" on storage.objects
  for select using (bucket_id = 'hostel-photos');
create policy "owner uploads hostel photos" on storage.objects
  for insert with check (
    bucket_id = 'hostel-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "owner deletes hostel photos" on storage.objects
  for delete using (
    bucket_id = 'hostel-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
