-- GEMBA — 7 günden eski bulguları otomatik silme (Supabase Cron)
-- Bu dosyanın kendisinde HİÇBİR gizli anahtar yoktur ve GitHub'a güvenle
-- yüklenebilir. Servis anahtarı, aşağıdaki ADIM 0'da SQL Editor'e SİZİN
-- YAPIŞTIRACAĞINIZ ayrı bir komutla gemba_secrets tablosuna kaydedilir.
-- Bu tablo RLS ile tamamen kilitlidir: hiçbir "policy" tanımlanmadığı için
-- ne anon (herkes) ne de authenticated (admin) API üzerinden bu tabloyu
-- okuyabilir/yazabilir — sadece veritabanının kendi içinde çalışan,
-- aşağıdaki security definer fonksiyon erişebilir.

-- ============================================================
-- ADIM 0 — Önce bu bölümü SQL Editor'de çalıştırın (tabloyu oluşturur)
-- ============================================================

create table if not exists gemba_secrets (
  key text primary key,
  value text not null
);

alter table gemba_secrets enable row level security;
-- Kasıtlı olarak hiçbir policy eklenmiyor: RLS açık + policy yok = anon/authenticated
-- rolleri için tablo tamamen erişilemez. Sadece bu dosyanın fonksiyonu (postgres
-- rolüyle, RLS'i by-pass ederek) okuyabilir.

-- ============================================================
-- ADIM 1 — Anahtarınızı SADECE BİR KERE kaydedin
-- (Bu satırı bu dosyaya değil, sadece SQL Editor'e ayrı yapıştırıp çalıştırın)
-- ============================================================
-- insert into gemba_secrets (key, value)
-- values ('gemba_service_key', 'BURAYA_SUPABASE_SECRET_KEYİNİZİ_YAPIŞTIRIN')
-- on conflict (key) do update set value = excluded.value;
--
-- Secret key'i Project Settings > API Keys sayfasından alabilirsiniz
-- (sb_secret_... ile başlayan anahtar).

-- ============================================================
-- ADIM 2 — Bu dosyanın geri kalanını SQL Editor'de çalıştırın
-- ============================================================

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

create or replace function gemba_cleanup_old_findings()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  rec record;
  storage_path text;
  service_key text;
  project_url text := 'https://xeettwmxooxtwxzevitk.supabase.co';
begin
  select value into service_key
  from gemba_secrets
  where key = 'gemba_service_key'
  limit 1;

  if service_key is null then
    raise notice 'gemba_service_key bulunamadı (ADIM 1''i çalıştırdınız mı?), temizlik atlandı.';
    return;
  end if;

  for rec in
    select id, photo_url
    from gemba_findings
    where created_at < now() - interval '7 days'
  loop
    storage_path := split_part(rec.photo_url, '/gemba-photos/', 2);

    if storage_path is not null and storage_path <> '' then
      perform net.http_delete(
        url := project_url || '/storage/v1/object/gemba-photos/' || storage_path,
        headers := jsonb_build_object(
          'apikey', service_key,
          'Authorization', 'Bearer ' || service_key
        )
      );
    end if;

    delete from gemba_findings where id = rec.id;
  end loop;
end;
$$;

-- Her gün gece 03:00'te (UTC) çalışır
select cron.unschedule('gemba-cleanup-old-findings')
where exists (select 1 from cron.job where jobname = 'gemba-cleanup-old-findings');

select cron.schedule(
  'gemba-cleanup-old-findings',
  '0 3 * * *',
  $$ select gemba_cleanup_old_findings(); $$
);

-- ============================================================
-- ADIM 3 — Test edin
-- ============================================================
-- Zamanlamayı beklemeden manuel olarak bir kere çalıştırıp
-- hata almadığınızı doğrulayın:
--
-- select gemba_cleanup_old_findings();
--
-- 7 günden eski hiç kaydınız yoksa bu komut sessizce biter (hata vermez,
-- hiçbir şey de silmez) — bu normaldir.
