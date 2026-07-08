# GEMBA Uygunsuzluk Takip Sistemi

Saha (gemba) turlarında görülen uygunsuzlukları telefonla fotoğraflayıp anında kaydetmek,
ardından bir admin panelinde görüntülemek için basit, framework'süz bir sistem.

- `gemba.html` — saha sayfası, login yok, herkes kullanabilir. Telefona uygulama gibi
  kurulabilen bir PWA'dır (bkz. aşağıdaki "Sahada uygulama gibi kurulum" bölümü).
- `admin.html` — admin paneli, Supabase Auth (email/şifre) ile korunur. Sadece gelen
  bulguları görüntüler; başka hiçbir işlem yapmaz.
- `schema.sql` — Supabase veritabanı şeması ve RLS politikaları.
- `manifest.json`, `service-worker.js`, `icons/` — `gemba.html`'in PWA (yüklenebilir
  uygulama) olarak çalışmasını sağlayan dosyalar.

Build adımı yoktur. Dosyalar herhangi bir statik hosting'e (GitHub Pages, Vercel, Netlify vb.)
doğrudan yüklenebilir.

## Saha kişisinin akışı (gemba.html)

1. Bölge seç
2. Sorumlu kişi seç
3. Fotoğraf çek (kamera doğrudan açılır, galeri değil)
4. Önizlemeyi kontrol et, Gönder

Not alanı yoktur — sistem bilinçli olarak bu kadar basit tutulmuştur.

## Kurulum

### 1. Mevcut bir Supabase projesini kullanın

**Yeni proje açmanıza gerek yok.** Supabase free plan limiti proje *sayısınadır* (2 proje),
tablo sayısına değildir. Zaten sahip olduğunuz 2 projeden birine bu sistemin tablolarını
ekleyebilirsiniz — aynı projede başka bir uygulamanın tabloları varsa bile `gemba_` öneki
sayesinde çakışma olmaz.

### 2. `schema.sql`'i çalıştırın

Seçtiğiniz Supabase projesinde **SQL Editor**'ü açın, `schema.sql` dosyasının tüm içeriğini
yapıştırıp **Run** butonuna basın. Bu adım:

- `gemba_findings`, `gemba_areas`, `gemba_responsibles` tablolarını oluşturur
- Row Level Security (RLS) politikalarını uygular: anon kullanıcılar sadece bulgu ekleyebilir,
  bölge/sorumlu listelerini okuyabilir; admin (authenticated) her şeyi yapabilir
- `gemba-photos` adında herkese açık okunabilir bir Storage bucket oluşturur

> Daha önce eski (durum/not alanlı) şemayı bu projede çalıştırdıysanız, önce
> `drop table if exists gemba_findings cascade;` ile eski tabloyu silip sonra `schema.sql`'i
> çalıştırın.

### 3. Admin kullanıcı oluşturun

Supabase panelinde **Authentication > Users** sekmesine gidin, **Add user** ile admin için
bir e-posta/şifre oluşturun (Auto Confirm User seçeneğini işaretleyin ki e-posta doğrulaması
beklemeden giriş yapılabilsin). Bu kullanıcı `admin.html`'e giriş yapmak için kullanılacak.

### 4. URL ve anon key'i dosyalara yapıştırın

Supabase panelinde **Project Settings > API** sayfasından `Project URL` ve `anon public` key'i
kopyalayın. Hem `gemba.html` hem `admin.html` dosyalarının en üstündeki `<script>` bloğunda
şu satırları güncelleyin:

```js
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

### 5. Statik hosting'e atın

`gemba.html`, `admin.html`, `manifest.json`, `service-worker.js` ve `icons/` klasörünü
**aynı dizin yapısıyla** tercih ettiğiniz statik hosting'e (GitHub Pages, Vercel, Netlify vb.)
yükleyin. PWA'nın çalışması için sitenin **HTTPS** üzerinden servis edilmesi gerekir (bu
hosting'lerin hepsi varsayılan olarak HTTPS sağlar).

### 6. Bölgeleri ve sorumlu kişileri ekleyin

`admin.html`'e admin hesabınızla giriş yapın:

- **Bölgeler** sekmesinden gemba turlarında gezilecek bölgeleri (örn. "Baskı Hattı 1",
  "Depo", "Kalite Kontrol") ekleyin.
- **Sorumlu Kişiler** sekmesinden uygunsuzluklardan sorumlu tutulacak kişileri ekleyin.

Bu iki liste, saha sayfasındaki (`gemba.html`) dropdown'ları otomatik olarak besler.

## Sahada uygulama gibi kurulum (PWA)

Saha ekibindeki kişiler `gemba.html` linkini telefon tarayıcısında açtıktan sonra:

- **Android (Chrome):** sağ üstteki ⋮ menüsünden **"Ana ekrana ekle" / "Uygulama yükle"**
- **iPhone (Safari):** paylaş butonundan **"Ana Ekrana Ekle"**

seçeneğine dokunarak, telefonlarına gerçek bir uygulama gibi ikonla açılan bir kısayol
kurabilirler. Bu bir `.apk` değildir; Play Store/App Store'a ihtiyaç duymaz, build veya
imzalama gerektirmez, siteyi her güncellediğinizde otomatik olarak günceldir.

## Kullanım

- **Saha ekibi:** Ana ekrana eklenen Gemba ikonuna dokunur. Bölge ve sorumlu kişi seçip
  fotoğraf çeker, önizler, gönderir.
- **Admin:** `admin.html`'e giriş yapıp gelen bulguları (fotoğraf, bölge, sorumlu kişi,
  tarih) sırayla görüntüler; bölge veya sorumlu kişiye göre filtreler. Admin panelinde
  başka hiçbir işlem (durum değiştirme, not ekleme vb.) yoktur.

## Notlar

- Mail/SMTP bildirimi yoktur.
- QR kod üretimi/okuma yoktur; bölge ve sorumlu kişi seçimi düz dropdown'lar ile yapılır.
- `admin.html` içinde hiçbir hardcoded şifre/PIN bulunmaz; yetkilendirme tamamen Supabase
  Auth ve RLS politikaları üzerinden sağlanır.
- Admin panelinin tek görevi gelen kayıtları görüntülemektir; açık/kapalı durum takibi veya
  kapatma işlemi kasıtlı olarak yoktur.
