begin;

-- Fix RLS infinite recursion on public.event_members
-- Root cause: event_members_select_admin references public.event_members inside its USING clause.

drop policy if exists event_members_select_admin on public.event_members;

-- Replace with a non-recursive policy: event creator can view all members for events they created.
drop policy if exists event_members_select_event_creator on public.event_members;

create policy event_members_select_event_creator
on public.event_members
for select
using (
  exists (
    select 1
    from public.events e
    where e.id = event_members.event_id
      and e.created_by = auth.uid()
  )
);

commit;

