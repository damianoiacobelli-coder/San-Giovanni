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
