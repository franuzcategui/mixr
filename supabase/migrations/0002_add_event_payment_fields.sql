alter table public.events
  add column if not exists checkout_session_id text,
  add column if not exists paid_at timestamptz;
