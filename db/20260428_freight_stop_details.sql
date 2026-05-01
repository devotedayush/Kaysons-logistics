alter table if exists public.freights
  add column if not exists stop_details jsonb not null default '[]'::jsonb;
