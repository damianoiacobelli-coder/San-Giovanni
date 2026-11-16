-- Usare se non hai ancora applicato la v6 o la v7.
-- Eseguire questa migrazione UNICA se non hai ancora applicato la v6.
-- Include sia gli orari Messe della v6 sia il nuovo repertorio canti v7.

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


-- San Giovanni Nettuno v7: repertori canti suddivisi per tre Messe e otto momenti.
-- Migrazione NON DISTRUTTIVA, eseguibile dopo la v3 e indipendente dalla v5 push.
-- Mantiene tutti i canti esistenti. Le assegnazioni vanno create esplicitamente.

-- Testo completo del canto, opzionale in fase di preparazione.
alter table public.songs add column if not exists lyrics text not null default '';
-- Non eliminare o sostituire i dati già presenti nella tabella songs.
do $$ begin
  if not exists (select 1 from pg_constraint where conname='songs_lyrics_length_v7' and conrelid='public.songs'::regclass) then
    alter table public.songs add constraint songs_lyrics_length_v7 check (char_length(lyrics) <= 12000);
  end if;
end $$;

-- Una stessa canzone può apparire in più Messe e momenti.
create table if not exists public.song_placements (
  id uuid primary key default gen_random_uuid(),
  song_id uuid not null references public.songs(id) on delete cascade,
  service_category text not null check (service_category in (
    'Messa Vespertina Sabato','Messa domenicale dei ragazzi','Messa Domenica ore 11'
  )),
  moment text not null check (moment in (
    'Ingresso','Gloria','Alleluia','Offertorio','Santo','Agnello di Dio','Comunione','Finale'
  )),
  sort_order integer not null default 0 check (sort_order >= 0 and sort_order <= 999),
  published boolean not null default false,
  created_at timestamptz not null default now(),
  constraint song_placements_unique_song_per_slot unique (song_id,service_category,moment)
);
create index if not exists song_placements_public_index on public.song_placements
 (service_category,moment,published,sort_order);

alter table public.song_placements enable row level security;
revoke all on table public.song_placements from anon, authenticated;
grant select on table public.song_placements to anon,authenticated;
grant insert,update,delete on table public.song_placements to authenticated;

-- Visitatore: vede solo assegnazioni pubblicate a canti anch'essi pubblicati.
drop policy if exists "Public read song placements" on public.song_placements;
create policy "Public read song placements" on public.song_placements
 for select to anon,authenticated using (
   published = true and exists(
     select 1 from public.songs s where s.id = song_id and s.published = true
   )
 );
-- Staff: può visualizzare e modificare anche le bozze.
drop policy if exists "Staff read song placements" on public.song_placements;
create policy "Staff read song placements" on public.song_placements
 for select to authenticated using (
   exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
 );
drop policy if exists "Staff insert song placements" on public.song_placements;
create policy "Staff insert song placements" on public.song_placements
 for insert to authenticated with check (
   exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
 );
drop policy if exists "Staff update song placements" on public.song_placements;
create policy "Staff update song placements" on public.song_placements
 for update to authenticated using (
   exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
 ) with check (
   exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
 );
drop policy if exists "Staff delete song placements" on public.song_placements;
create policy "Staff delete song placements" on public.song_placements
 for delete to authenticated using (
   exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
 );

-- Non vengono inserite automaticamente canzoni o assegnazioni.
-- Il responsabile crea le assegnazioni dal pannello amministrativo.

-- SAN GIOVANNI NETTUNO v8 — Repertori / categorie e slot completamente configurabili
-- Da eseguire DOPO la migrazione v7 (03_canti_messe.sql), oppure usare lo script cumulativo.
-- Migrazione idempotente e non distruttiva per i testi dei canti e le assegnazioni esistenti.
-- Categorie e slot si possono nascondere (published=false) o eliminare definitivamente.
-- Eliminare una categoria cancella i suoi slot e le relative assegnazioni, NON i canti.

begin;
create table if not exists public.song_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 120),
  sort_order integer not null default 0 check (sort_order between 0 and 999),
  published boolean not null default false,
  created_at timestamptz not null default now(),
  constraint song_categories_name_unique unique (name)
);
create unique index if not exists song_categories_unique_name_ci on public.song_categories(lower(btrim(name)));

create table if not exists public.song_slots (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.song_categories(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 100),
  sort_order integer not null default 0 check (sort_order between 0 and 999),
  published boolean not null default false,
  created_at timestamptz not null default now(),
  constraint song_slots_category_name_unique unique (category_id,name)
);
create unique index if not exists song_slots_category_unique_name_ci on public.song_slots(category_id,lower(btrim(name)));
create index if not exists song_slots_category_order_idx on public.song_slots(category_id,sort_order);

-- Ripristino dei tre repertori originari solo se mancanti, senza sovrascrivere modifiche.
insert into public.song_categories(name,sort_order,published) values
 ('Messa Vespertina Sabato',0,true),
 ('Messa domenicale dei ragazzi',1,true),
 ('Messa Domenica ore 11',2,true)
on conflict (name) do nothing;

-- Gli otto slot iniziali vengono creati per ciascuno dei tre repertori.
with starter(name,pos) as (values
 ('Ingresso',0),('Gloria',1),('Alleluia',2),('Offertorio',3),
 ('Santo',4),('Agnello di Dio',5),('Comunione',6),('Finale',7))
insert into public.song_slots(category_id,name,sort_order,published)
select c.id,starter.name,starter.pos,true
from public.song_categories c cross join starter
where c.name in ('Messa Vespertina Sabato','Messa domenicale dei ragazzi','Messa Domenica ore 11')
on conflict (category_id,name) do nothing;

-- Compatibilità con le assegnazioni v7; colonne legacy preservate, ora facoltative.
alter table public.song_placements add column if not exists slot_id uuid references public.song_slots(id) on delete cascade;
update public.song_placements p
set slot_id=s.id
from public.song_slots s
join public.song_categories c on c.id=s.category_id
where p.slot_id is null and c.name=p.service_category and s.name=p.moment;

do $$ begin
  if exists (select 1 from public.song_placements where slot_id is null) then
    raise exception 'Alcune assegnazioni v7 non corrispondono a una categoria o a uno slot. Migrazione annullata, nessun dato modificato.';
  end if;
end $$;
alter table public.song_placements alter column slot_id set not null;
alter table public.song_placements alter column service_category drop not null;
alter table public.song_placements alter column moment drop not null;
create unique index if not exists song_placements_unique_song_slot_v8 on public.song_placements(song_id,slot_id);
create index if not exists song_placements_slot_published_idx on public.song_placements(slot_id,published,sort_order);

-- Sicurezza: il visitatore vede solo categorie e slot pubblicati;
-- soltanto un admin può modificare la struttura, mentre editor/admin gestiscono i canti.
alter table public.song_categories enable row level security;
alter table public.song_slots enable row level security;
revoke all on table public.song_categories, public.song_slots from anon, authenticated;
grant select on table public.song_categories, public.song_slots to anon, authenticated;
grant insert,update,delete on table public.song_categories, public.song_slots to authenticated;

-- Categoria pubblica o per staff autenticato.
drop policy if exists "Public read song categories" on public.song_categories;
create policy "Public read song categories" on public.song_categories for select to anon,authenticated using (published=true);
drop policy if exists "Staff read song categories" on public.song_categories;
create policy "Staff read song categories" on public.song_categories for select to authenticated using (
  exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
);
drop policy if exists "Admin insert song categories" on public.song_categories;
create policy "Admin insert song categories" on public.song_categories for insert to authenticated with check (
  exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role='admin')
);
drop policy if exists "Admin update song categories" on public.song_categories;
create policy "Admin update song categories" on public.song_categories for update to authenticated using (
  exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role='admin')
) with check (
  exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role='admin')
);
drop policy if exists "Admin delete song categories" on public.song_categories;
create policy "Admin delete song categories" on public.song_categories for delete to authenticated using (
  exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role='admin')
);

-- Slot visibile solo se pubblicato e appartenente a una categoria pubblicata.
drop policy if exists "Public read song slots" on public.song_slots;
create policy "Public read song slots" on public.song_slots for select to anon,authenticated using (
  published=true and exists(select 1 from public.song_categories c where c.id=category_id and c.published=true)
);
drop policy if exists "Staff read song slots" on public.song_slots;
create policy "Staff read song slots" on public.song_slots for select to authenticated using (
  exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor'))
);
drop policy if exists "Admin insert song slots" on public.song_slots;
create policy "Admin insert song slots" on public.song_slots for insert to authenticated with check (
  exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role='admin')
);
drop policy if exists "Admin update song slots" on public.song_slots;
create policy "Admin update song slots" on public.song_slots for update to authenticated using (
  exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role='admin')
) with check (
  exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role='admin')
);
drop policy if exists "Admin delete song slots" on public.song_slots;
create policy "Admin delete song slots" on public.song_slots for delete to authenticated using (
  exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role='admin')
);

-- Aggiorna la policy di lettura delle assegnazioni: mai esporre quelle nascoste.
drop policy if exists "Public read song placements" on public.song_placements;
create policy "Public read song placements" on public.song_placements for select to anon,authenticated using (
  published=true
  and exists(select 1 from public.songs s where s.id=song_id and s.published=true)
  and exists (
    select 1 from public.song_slots ss
    join public.song_categories c on c.id=ss.category_id
    where ss.id=slot_id and ss.published=true and c.published=true
  )
);
commit;
