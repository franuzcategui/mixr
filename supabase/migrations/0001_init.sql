-- Extensions
create extension if not exists pgcrypto;

-- Tables
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  timezone text not null,
  swipe_start_at timestamptz not null,
  swipe_end_at timestamptz not null,
  is_paid boolean not null default false,
  is_test_mode boolean not null default true,
  test_mode_attendee_cap integer not null default 20,
  match_expires_days integer not null default 7,
  created_at timestamptz not null default now()
);

create table if not exists public.invites (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  token text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz null,
  created_at timestamptz not null default now()
);

create table if not exists public.event_members (
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'attendee')),
  status text not null default 'joined' check (status in ('joined', 'blocked')),
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  bio text null,
  interests jsonb null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profile_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  url text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.swipes (
  event_id uuid not null references public.events(id) on delete cascade,
  swiper_id uuid not null references auth.users(id) on delete cascade,
  swiped_id uuid not null references auth.users(id) on delete cascade,
  direction text not null check (direction in ('left', 'right')),
  created_at timestamptz not null default now(),
  unique (event_id, swiper_id, swiped_id)
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  -- Enforce uniqueness regardless of user order by storing canonical low/high values.
  user_low uuid generated always as (least(user_a, user_b)) stored,
  user_high uuid generated always as (greatest(user_a, user_b)) stored,
  unique (event_id, user_low, user_high)
);

-- Indexes
create index if not exists event_members_event_id_idx on public.event_members (event_id);
create index if not exists event_members_user_id_idx on public.event_members (user_id);

create index if not exists swipes_event_swiper_created_idx
  on public.swipes (event_id, swiper_id, created_at);

create index if not exists matches_event_user_a_idx on public.matches (event_id, user_a);
create index if not exists matches_event_user_b_idx on public.matches (event_id, user_b);
create index if not exists matches_expires_at_idx on public.matches (expires_at);

-- Trigger to update profiles.updated_at
create or replace function public.set_profiles_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_profiles_updated_at();

-- Enable RLS
alter table public.events enable row level security;
alter table public.invites enable row level security;
alter table public.event_members enable row level security;
alter table public.profiles enable row level security;
alter table public.profile_photos enable row level security;
alter table public.swipes enable row level security;
alter table public.matches enable row level security;

-- Policies: profiles
create policy profiles_select_own
on public.profiles
for select
using (auth.uid() = user_id);

create policy profiles_select_same_event
on public.profiles
for select
using (
  exists (
    select 1
    from public.event_members em_self
    join public.event_members em_other
      on em_self.event_id = em_other.event_id
    where em_self.user_id = auth.uid()
      and em_self.status = 'joined'
      and em_other.user_id = profiles.user_id
      and em_other.status = 'joined'
  )
);

create policy profiles_insert_own
on public.profiles
for insert
with check (auth.uid() = user_id);

create policy profiles_update_own
on public.profiles
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Policies: profile_photos
create policy profile_photos_select_own
on public.profile_photos
for select
using (auth.uid() = user_id);

create policy profile_photos_select_same_event
on public.profile_photos
for select
using (
  exists (
    select 1
    from public.event_members em_self
    join public.event_members em_other
      on em_self.event_id = em_other.event_id
    where em_self.user_id = auth.uid()
      and em_self.status = 'joined'
      and em_other.user_id = profile_photos.user_id
      and em_other.status = 'joined'
  )
);

create policy profile_photos_insert_own
on public.profile_photos
for insert
with check (auth.uid() = user_id);

create policy profile_photos_update_own
on public.profile_photos
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy profile_photos_delete_own
on public.profile_photos
for delete
using (auth.uid() = user_id);

-- Policies: event_members
create policy event_members_select_self
on public.event_members
for select
using (user_id = auth.uid());

create policy event_members_select_admin
on public.event_members
for select
using (
  exists (
    select 1
    from public.events e
    where e.id = event_members.event_id
      and e.created_by = auth.uid()
  )
  or exists (
    select 1
    from public.event_members em_admin
    where em_admin.event_id = event_members.event_id
      and em_admin.user_id = auth.uid()
      and em_admin.role = 'admin'
      and em_admin.status = 'joined'
  )
);

-- Policies: events
create policy events_select_member
on public.events
for select
using (
  exists (
    select 1
    from public.event_members em
    where em.event_id = events.id
      and em.user_id = auth.uid()
      and em.status = 'joined'
  )
);

create policy events_update_admin
on public.events
for update
using (
  created_by = auth.uid()
  or exists (
    select 1
    from public.event_members em_admin
    where em_admin.event_id = events.id
      and em_admin.user_id = auth.uid()
      and em_admin.role = 'admin'
      and em_admin.status = 'joined'
  )
)
with check (
  created_by = auth.uid()
  or exists (
    select 1
    from public.event_members em_admin
    where em_admin.event_id = events.id
      and em_admin.user_id = auth.uid()
      and em_admin.role = 'admin'
      and em_admin.status = 'joined'
  )
);

-- Policies: invites
create policy invites_select_admin
on public.invites
for select
using (
  exists (
    select 1
    from public.events e
    where e.id = invites.event_id
      and e.created_by = auth.uid()
  )
  or exists (
    select 1
    from public.event_members em_admin
    where em_admin.event_id = invites.event_id
      and em_admin.user_id = auth.uid()
      and em_admin.role = 'admin'
      and em_admin.status = 'joined'
  )
);

create policy invites_select_by_token
on public.invites
for select
using (
  token = (current_setting('request.jwt.claims', true)::jsonb ->> 'invite_token')
);

-- Policies: swipes
create policy swipes_select_own
on public.swipes
for select
using (
  (swiper_id = auth.uid() or swiped_id = auth.uid())
  and exists (
    select 1
    from public.event_members em
    where em.event_id = swipes.event_id
      and em.user_id = auth.uid()
      and em.status = 'joined'
  )
);

-- Policies: matches
create policy matches_select_own_active
on public.matches
for select
using (
  (user_a = auth.uid() or user_b = auth.uid())
  and expires_at > now()
  and exists (
    select 1
    from public.event_members em
    where em.event_id = matches.event_id
      and em.user_id = auth.uid()
      and em.status = 'joined'
  )
);
