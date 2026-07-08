-- GEMBA Uygunsuzluk Takip Sistemi — Supabase Schema
-- Bu dosyayı MEVCUT bir Supabase projenizde (yeni proje açmanıza gerek yok,
-- free tier limiti proje sayısınadır, tablo sayısına değil) SQL Editor'de
-- tek seferde çalıştırın.

-- 1) UYGUNSUZLUK KAYITLARI
-- Not: durum (açık/kapalı) takibi yok — admin sadece gelen kayıtları görüntüler.
create table if not exists gemba_findings (
  id uuid primary key default gen_random_uuid(),
  area text not null,
  responsible text not null,
  photo_url text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_gemba_findings_area on gemba_findings(area);
create index if not exists idx_gemba_findings_responsible on gemba_findings(responsible);
create index if not exists idx_gemba_findings_created on gemba_findings(created_at desc);

-- 2) BÖLGE LİSTESİ (admin panelinden yönetilir; saha sayfasındaki dropdown bu tablodan okunur)
create table if not exists gemba_areas (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

-- 3) SORUMLU KİŞİ LİSTESİ (admin panelinden yönetilir; saha sayfasındaki dropdown bu tablodan okunur)
create table if not exists gemba_responsibles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

-- 4) ROW LEVEL SECURITY
alter table gemba_findings enable row level security;
alter table gemba_areas enable row level security;
alter table gemba_responsibles enable row level security;

drop policy if exists "public insert findings" on gemba_findings;
create policy "public insert findings"
on gemba_findings for insert
to anon
with check (true);

drop policy if exists "admin full access findings" on gemba_findings;
create policy "admin full access findings"
on gemba_findings for all
to authenticated
using (true)
with check (true);

drop policy if exists "public read areas" on gemba_areas;
create policy "public read areas"
on gemba_areas for select
to anon
using (true);

drop policy if exists "admin full access areas" on gemba_areas;
create policy "admin full access areas"
on gemba_areas for all
to authenticated
using (true)
with check (true);

drop policy if exists "public read responsibles" on gemba_responsibles;
create policy "public read responsibles"
on gemba_responsibles for select
to anon
using (true);

drop policy if exists "admin full access responsibles" on gemba_responsibles;
create policy "admin full access responsibles"
on gemba_responsibles for all
to authenticated
using (true)
with check (true);

-- 5) STORAGE BUCKET
insert into storage.buckets (id, name, public)
values ('gemba-photos', 'gemba-photos', true)
on conflict (id) do nothing;

drop policy if exists "public upload gemba photos" on storage.objects;
create policy "public upload gemba photos"
on storage.objects for insert
to anon
with check (bucket_id = 'gemba-photos');

drop policy if exists "public read gemba photos" on storage.objects;
create policy "public read gemba photos"
on storage.objects for select
to public
using (bucket_id = 'gemba-photos');

drop policy if exists "admin manage gemba photos" on storage.objects;
create policy "admin manage gemba photos"
on storage.objects for all
to authenticated
using (bucket_id = 'gemba-photos')
with check (bucket_id = 'gemba-photos');
