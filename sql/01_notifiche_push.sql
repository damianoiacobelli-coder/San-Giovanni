-- AGGIORNAMENTO VERSIONE 5: NON rieseguire lo schema della versione 3.
-- Eseguire UNA VOLTA da Supabase > SQL Editor.
-- Registra solo le sottoscrizioni volontarie a notifiche pubbliche.
-- Non salva nomi, email o dati di minori.

create table if not exists public.push_subscriptions (
  endpoint text primary key check (char_length(endpoint) between 20 and 2048),
  p256dh text not null check (char_length(p256dh) between 80 and 150),
  auth text not null check (char_length(auth) between 16 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.push_dispatches (
  notice_id uuid primary key references public.notices(id) on delete cascade,
  requested_at timestamptz not null default now(),
  success_count integer,
  failure_count integer
);

alter table public.push_subscriptions enable row level security;
alter table public.push_dispatches enable row level security;

-- I browser NON possono leggere/scrivere le sottoscrizioni via API Supabase.
-- L'unico accesso è attraverso Netlify Functions, con chiave segreta custodita lato server.
revoke all on table public.push_subscriptions from public, anon, authenticated;
revoke all on table public.push_dispatches from public, anon, authenticated;
grant all on table public.push_subscriptions, public.push_dispatches to service_role;

-- Non creare policy permissive per queste due tabelle.
-- Per verificare:
-- select count(*) from public.push_subscriptions;
-- select * from public.push_dispatches order by requested_at desc limit 10;
