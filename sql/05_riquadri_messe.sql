-- SAN GIOVANNI NETTUNO v9 — riquadri celebrazioni (Natale, Pasqua, ecc.)
-- Eseguire DOPO aver installato SQL cumulativo v8.
-- Script ripetibile: non cancella né modifica gli orari o gli avvisi esistenti.

begin;
create table if not exists public.mass_collections (
  id uuid primary key default gen_random_uuid(),
  title text not null check(char_length(btrim(title)) between 1 and 120),
  notes text not null default '' check(char_length(notes)<=500),
  sort_order integer not null default 0 check(sort_order between 0 and 999),
  published boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.mass_exceptions
  add column if not exists collection_id uuid references public.mass_collections(id) on delete set null;
alter table public.mass_exceptions
  add column if not exists day_label text not null default '';
alter table public.mass_exceptions
  add column if not exists sort_order integer not null default 0;

create index if not exists mass_exceptions_collection_idx on public.mass_exceptions(collection_id,date_on);
create index if not exists mass_collections_visible_idx on public.mass_collections(published,sort_order);

alter table public.mass_collections enable row level security;
revoke all on table public.mass_collections from anon, authenticated;
grant select on table public.mass_collections to anon, authenticated;
grant insert, update, delete on table public.mass_collections to authenticated;

drop policy if exists "Public read mass collections" on public.mass_collections;
create policy "Public read mass collections" on public.mass_collections for select to anon, authenticated
using(published=true);

drop policy if exists "Staff read mass collections" on public.mass_collections;
create policy "Staff read mass collections" on public.mass_collections for select to authenticated
using(exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor')));

drop policy if exists "Staff insert mass collections" on public.mass_collections;
create policy "Staff insert mass collections" on public.mass_collections for insert to authenticated
with check(exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor')));

drop policy if exists "Staff update mass collections" on public.mass_collections;
create policy "Staff update mass collections" on public.mass_collections for update to authenticated
using(exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor')))
with check(exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor')));

drop policy if exists "Staff delete mass collections" on public.mass_collections;
create policy "Staff delete mass collections" on public.mass_collections for delete to authenticated
using(exists(select 1 from public.admin_members a where a.user_id=(select auth.uid()) and a.role in ('admin','editor')));

-- Si conservano le eccezioni precedenti (es. Natale 25/12/2026 in bozza).
-- Il raggruppamento viene creato dall'amministratore, senza pubblicazioni inattese.
commit;
