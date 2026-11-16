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
