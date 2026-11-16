-- PARROCCHIA SAN GIOVANNI NETTUNO · v10 — gruppi e calendario catechesi
-- Da eseguire dopo sql/05_riquadri_messe.sql (oppure la v9 già installata).
-- Migrazione non distruttiva e idempotente: non modifica avvisi, Messe, canti, push.
-- Nessun dato personale di bambini, recapito o genitore in queste tabelle.
-- Non pubblica automaticamente calendari: tutti i gruppi/incontri si creano dall'app.

begin;
create table if not exists public.catechism_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check(char_length(btrim(name)) between 1 and 100),
  course text not null check (course in ('Primo anno','Secondo anno','Terzo anno','Cresima','Dopocomunione','Altro')),
  school_year text not null check(char_length(btrim(school_year)) between 1 and 12),
  description text not null default '' check(char_length(description)<=500),
  location text not null default '' check(char_length(location)<=180),
  sort_order integer not null default 0 check(sort_order between 0 and 999),
  published boolean not null default false,
  created_at timestamptz not null default now()
);
-- Non consentiamo due gruppi con stesso nome nel medesimo anno e percorso.
create unique index if not exists catechism_groups_unique_ci
  on public.catechism_groups(course,school_year,lower(btrim(name)));
create index if not exists catechism_groups_visible_idx on public.catechism_groups(published,course,sort_order);

create table if not exists public.catechism_meetings (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.catechism_groups(id) on delete restrict,
  date_on date not null check(date_on between date '2020-01-01' and date '2100-12-31'),
  time_of_day time without time zone not null default '10:00',
  title text not null check(char_length(btrim(title)) between 1 and 150),
  location text not null default '' check(char_length(location)<=180),
  notes text not null default '' check(char_length(notes)<=1000),
  status text not null default 'scheduled' check(status in ('scheduled','cancelled')),
  published boolean not null default false,
  created_at timestamptz not null default now(),
  constraint catechism_one_meeting_per_slot unique(group_id,date_on,time_of_day)
);
create index if not exists catechism_meetings_calendar_idx on public.catechism_meetings(group_id,date_on,time_of_day);
create index if not exists catechism_meetings_public_idx on public.catechism_meetings(published,date_on);

alter table public.catechism_groups enable row level security;
alter table public.catechism_meetings enable row level security;
revoke all on table public.catechism_groups, public.catechism_meetings from anon,authenticated;
grant select on table public.catechism_groups, public.catechism_meetings to anon,authenticated;
grant insert,update,delete on table public.catechism_groups, public.catechism_meetings to authenticated;

-- Chi visita il sito vede soltanto gruppi pubblicati.
drop policy if exists "Catechism public groups" on public.catechism_groups;
create policy "Catechism public groups" on public.catechism_groups
  for select to anon,authenticated using(published=true);
-- I collaboratori registrati nella tabella admin_members vedono anche le bozze.
drop policy if exists "Catechism staff read groups" on public.catechism_groups;
create policy "Catechism staff read groups" on public.catechism_groups
  for select to authenticated using(
    exists(select 1 from public.admin_members a
      where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  );
drop policy if exists "Catechism staff insert groups" on public.catechism_groups;
create policy "Catechism staff insert groups" on public.catechism_groups
  for insert to authenticated with check(
    exists(select 1 from public.admin_members a
      where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  );
drop policy if exists "Catechism staff update groups" on public.catechism_groups;
create policy "Catechism staff update groups" on public.catechism_groups
  for update to authenticated
  using(exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor')))
  with check(exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor')));
drop policy if exists "Catechism staff delete groups" on public.catechism_groups;
create policy "Catechism staff delete groups" on public.catechism_groups
  for delete to authenticated
  using(exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor')));

-- Il pubblico vede incontri pubblicati SOLO se anche il gruppo è pubblicato.
drop policy if exists "Catechism public meetings" on public.catechism_meetings;
create policy "Catechism public meetings" on public.catechism_meetings
  for select to anon,authenticated using(
    published=true and exists(
      select 1 from public.catechism_groups g where g.id=group_id and g.published=true
    )
  );
drop policy if exists "Catechism staff read meetings" on public.catechism_meetings;
create policy "Catechism staff read meetings" on public.catechism_meetings
  for select to authenticated using(
    exists(select 1 from public.admin_members a
      where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  );
drop policy if exists "Catechism staff insert meetings" on public.catechism_meetings;
create policy "Catechism staff insert meetings" on public.catechism_meetings
  for insert to authenticated with check(
    exists(select 1 from public.admin_members a
      where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
  );
drop policy if exists "Catechism staff update meetings" on public.catechism_meetings;
create policy "Catechism staff update meetings" on public.catechism_meetings
  for update to authenticated
  using(exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor')))
  with check(exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor')));
drop policy if exists "Catechism staff delete meetings" on public.catechism_meetings;
create policy "Catechism staff delete meetings" on public.catechism_meetings
  for delete to authenticated
  using(exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor')));

commit;
