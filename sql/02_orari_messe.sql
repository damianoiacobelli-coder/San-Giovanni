-- San Giovanni Nettuno v6 - Orari ordinari / celebrazioni particolari
-- Eseguire una sola volta nel progetto Supabase esistente, dal SQL Editor.
-- Migrazione non distruttiva: preserva avvisi, canti, eventi, meditazioni,
-- sottoscrizioni push e la precedente tabella public.mass_times.

create table if not exists public.mass_schedule (
  id uuid primary key default gen_random_uuid(),
  season text not null check (season in ('solare','legale')),
  day_type text not null check (day_type in ('Feriale / Prefestivo','Festivo')),
  times_text text not null check (
    char_length(times_text) between 5 and 120
    and times_text ~ '^([01][0-9]|2[0-3]):[0-5][0-9](, ([01][0-9]|2[0-3]):[0-5][0-9])*$'
  ),
  published boolean not null default false,
  created_at timestamptz not null default now(),
  constraint mass_schedule_period_day_unique unique (season, day_type)
);

create table if not exists public.mass_exceptions (
  id uuid primary key default gen_random_uuid(),
  date_on date not null unique,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  times_text text not null check (
    char_length(times_text) between 5 and 120
    and times_text ~ '^([01][0-9]|2[0-3]):[0-5][0-9](, ([01][0-9]|2[0-3]):[0-5][0-9])*$'
  ),
  notes text not null default '' check (char_length(notes) <= 500),
  published boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists mass_exceptions_public_date_idx
  on public.mass_exceptions(published,date_on);

alter table public.mass_schedule enable row level security;
alter table public.mass_exceptions enable row level security;

revoke all on table public.mass_schedule, public.mass_exceptions from anon, authenticated;
grant select on table public.mass_schedule, public.mass_exceptions to anon, authenticated;
grant insert, update, delete on table public.mass_schedule, public.mass_exceptions to authenticated;

-- Lettura anonima consentita soltanto ai record pubblicati; gli amministratori
-- censiti in admin_members possono vedere bozze e modificare entrambe le tabelle.
drop policy if exists "Public read mass schedule" on public.mass_schedule;
create policy "Public read mass schedule" on public.mass_schedule
  for select to anon, authenticated using (published = true);
drop policy if exists "Staff read mass schedule" on public.mass_schedule;
create policy "Staff read mass schedule" on public.mass_schedule
  for select to authenticated using (
    exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  );
drop policy if exists "Staff insert mass schedule" on public.mass_schedule;
create policy "Staff insert mass schedule" on public.mass_schedule
  for insert to authenticated with check (
    exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  );
drop policy if exists "Staff update mass schedule" on public.mass_schedule;
create policy "Staff update mass schedule" on public.mass_schedule
  for update to authenticated using (
    exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  ) with check (
    exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  );
drop policy if exists "Staff delete mass schedule" on public.mass_schedule;
create policy "Staff delete mass schedule" on public.mass_schedule
  for delete to authenticated using (
    exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  );

drop policy if exists "Public read mass exceptions" on public.mass_exceptions;
create policy "Public read mass exceptions" on public.mass_exceptions
  for select to anon, authenticated using (published = true);
drop policy if exists "Staff read mass exceptions" on public.mass_exceptions;
create policy "Staff read mass exceptions" on public.mass_exceptions
  for select to authenticated using (
    exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  );
drop policy if exists "Staff insert mass exceptions" on public.mass_exceptions;
create policy "Staff insert mass exceptions" on public.mass_exceptions
  for insert to authenticated with check (
    exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  );
drop policy if exists "Staff update mass exceptions" on public.mass_exceptions;
create policy "Staff update mass exceptions" on public.mass_exceptions
  for update to authenticated using (
    exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  ) with check (
    exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  );
drop policy if exists "Staff delete mass exceptions" on public.mass_exceptions;
create policy "Staff delete mass exceptions" on public.mass_exceptions
  for delete to authenticated using (
    exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  );

-- Orari forniti dalla parrocchia. Non sovrascrivere eventuali modifiche future.
insert into public.mass_schedule(season,day_type,times_text,published) values
 ('solare','Feriale / Prefestivo','17:30',true),
 ('solare','Festivo','08:00, 11:00, 17:30',true),
 ('legale','Feriale / Prefestivo','18:30',true),
 ('legale','Festivo','08:00, 11:00, 18:30',true)
on conflict (season,day_type) do nothing;

-- Esempio: lasciato IN BOZZA per evitare di annunciare una celebrazione non verificata.
insert into public.mass_exceptions(date_on,title,times_text,notes,published) values
 ('2026-12-25','Natale','08:00, 11:00, 17:30','Orari da verificare e pubblicare',false)
on conflict (date_on) do nothing;
