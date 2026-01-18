begin;

-- Add event payment fields.
alter table public.events
  add column if not exists checkout_session_id text,
  add column if not exists paid_at timestamptz;

-- Remove invite token policy; invite validation handled via service role.
drop policy if exists invites_select_by_token on public.invites;

-- Tighten swipe reads to only the initiating swiper within joined events.
drop policy if exists swipes_select_own on public.swipes;
create policy swipes_select_own
on public.swipes
for select
using (
  swiper_id = auth.uid()
  and exists (
    select 1
    from public.event_members em
    where em.event_id = swipes.event_id
      and em.user_id = auth.uid()
      and em.status = 'joined'
  )
);

-- Ensure swipe window integrity constraint exists.
do $$
declare
  constraint_name text;
begin
  select conname into constraint_name
  from pg_constraint
  where conrelid = 'public.events'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) = 'CHECK ((swipe_end_at > swipe_start_at))';

  if constraint_name is not null then
    execute format('alter table public.events drop constraint %I', constraint_name);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.events'::regclass
      and contype = 'c'
      and conname = 'events_swipe_window_check'
  ) then
    execute 'alter table public.events add constraint events_swipe_window_check check (swipe_end_at > swipe_start_at)';
  end if;
end;
$$;

-- Add indexes for member and swipe lookups.
create index if not exists event_members_event_user_status_idx
  on public.event_members (event_id, user_id, status);

create index if not exists swipes_event_swiped_direction_idx
  on public.swipes (event_id, swiped_id, direction);

commit;
