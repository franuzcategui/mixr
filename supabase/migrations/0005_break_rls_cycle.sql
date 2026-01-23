begin;

-- Break RLS recursion cycle between profiles <-> event_members <-> events
drop policy if exists event_members_select_event_creator on public.event_members;

commit;
