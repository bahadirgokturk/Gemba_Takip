-- GEMBA — 7 günden eski bulguları otomatik silme (Supabase Cron)
-- Bu dosyanın kendisinde HİÇBİR gizli anahtar yoktur ve GitHub'a güvenle
-- yüklenebilir. Servis anahtarı, aşağıdaki adım 0'da SQL Editor'e SİZİN
-- YAPIŞTIRACAĞINIZ ayrı bir komutla, şifreli olarak Supabase Vault'a
-- kaydedilir — hiçbir dosyada düz metin olarak durmaz.

-- ============================================================
-- ADIM 0 — SADECE BİR KERE, SQL Editor'e AYRI çalıştırın
-- (Bu komutu bu dosyaya değil, sadece SQL Editor'e yapıştırın)
-- ============================================================
-- select vault.create_secret(
--   'BURAYA_SUPABASE_SECRET_KEYİNİZİ_YAPIŞTIRIN',
--   'gemba_service_key'
-- );
--
-- Secret key'i Project Settings > API Keys sayfasından alabilirsiniz
-- (sb_secret_... ile başlayan anahtar).

-- ============================================================
-- ADIM 1 — Bu dosyanın geri kalanını SQL Editor'de çalıştırın
-- ============================================================

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault;

create or replace function gemba_cleanup_old_findings()
returns void
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  rec record;
  storage_path text;
  service_key text;
  project_url text := 'https://xeettwmxooxtwxzevitk.supabase.co';
begin
  select decrypted_secret into service_key
  from vault.decrypted_secrets
  where name = 'gemba_service_key'
  limit 1;

  if service_key is null then
    raise notice 'gemba_service_key Vault''da bulunamadı, temizlik atlandı.';
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
-- ADIM 2 — Test edin
-- ============================================================
-- Zamanlamayı beklemeden manuel olarak bir kere çalıştırıp
-- hata almadığınızı doğrulayın:
--
-- select gemba_cleanup_old_findings();
--
-- 7 günden eski hiç kaydınız yoksa bu komut sessizce biter (hata vermez,
-- hiçbir şey de silmez) — bu normaldir.
