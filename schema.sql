-- GEMBA Uygunsuzluk Takip Sistemi — Supabase Schema
-- Bu dosyayı Supabase projenizde SQL Editor'de çalıştırın.
-- Dosyanın tamamı tekrar tekrar çalıştırılabilir (idempotent) — daha önce
-- bir sürümünü çalıştırdıysanız, güncellenmiş bu dosyayı baştan sona
-- tekrar çalıştırmanız yeterli, mevcut verileriniz silinmez.

-- 1) UYGUNSUZLUK KAYITLARI
-- Not: durum (açık/kapalı) takibi yok — admin sadece gelen kayıtları görüntüler.
create table if not exists gemba_findings (
  id uuid primary key default gen_random_uuid(),
  area text not null,
  responsible text not null,
  photo_url text not null,
  created_at timestamptz not null default now()
);

-- Daha önceki bir sürümde bu tabloyu oluşturduysanız "reason" kolonu eksik olabilir.
alter table gemba_findings add column if not exists reason text not null default '';

-- "photo_url" hem fotoğraf hem video linkini tutar (kolon adı geriye dönük uyumluluk
-- için değiştirilmedi); media_type hangisi olduğunu belirtir.
alter table gemba_findings add column if not exists media_type text not null default 'photo';
alter table gemba_findings drop constraint if exists gemba_findings_media_type_check;
alter table gemba_findings add constraint gemba_findings_media_type_check check (media_type in ('photo','video'));

-- Serbest metin açıklama (opsiyonel).
alter table gemba_findings add column if not exists description text;

-- Aynı gönderimde birden fazla fotoğraf/video eklenirse, hepsi ayrı satır olarak
-- kaydedilir ama aynı submission_id'yi paylaşır (birbirine ait olduklarını belirtmek için).
alter table gemba_findings add column if not exists submission_id uuid;

create index if not exists idx_gemba_findings_area on gemba_findings(area);
create index if not exists idx_gemba_findings_responsible on gemba_findings(responsible);
create index if not exists idx_gemba_findings_reason on gemba_findings(reason);
create index if not exists idx_gemba_findings_created on gemba_findings(created_at desc);
create index if not exists idx_gemba_findings_submission on gemba_findings(submission_id);

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

-- 4) UYGUNSUZLUK NEDENİ LİSTESİ (admin panelinden yönetilir; saha sayfasındaki dropdown bu tablodan okunur)
create table if not exists gemba_reasons (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

-- 5) ROW LEVEL SECURITY
alter table gemba_findings enable row level security;
alter table gemba_areas enable row level security;
alter table gemba_responsibles enable row level security;
alter table gemba_reasons enable row level security;

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

drop policy if exists "public read reasons" on gemba_reasons;
create policy "public read reasons"
on gemba_reasons for select
to anon
using (true);

drop policy if exists "admin full access reasons" on gemba_reasons;
create policy "admin full access reasons"
on gemba_reasons for all
to authenticated
using (true)
with check (true);

-- 6) STORAGE BUCKET
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

-- 7) REALTIME
-- Admin paneli yeni bulguları sayfa yenilemeden anında görsün diye
-- gemba_findings tablosunu Supabase Realtime yayınına ekler.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'gemba_findings'
  ) then
    alter publication supabase_realtime add table gemba_findings;
  end if;
end $$;
