# GEMBA Uygunsuzluk Takip Sistemi

Saha (gemba) turlarında görülen uygunsuzlukları telefonla fotoğraflayıp anında kaydetmek,
ardından bir admin panelinde görüntülemek için basit, framework'süz bir sistem.

- `gemba.html` — saha sayfası, login yok, herkes kullanabilir. Telefona uygulama gibi
  kurulabilen bir PWA'dır (bkz. aşağıdaki "Sahada uygulama gibi kurulum" bölümü).
- `admin.html` — admin paneli, Supabase Auth (email/şifre) ile korunur. Sadece gelen
  bulguları görüntüler; başka hiçbir işlem yapmaz.
- `schema.sql` — Supabase veritabanı şeması ve RLS politikaları.
- `cleanup.sql` — 7 günden eski bulguları (fotoğraf + kayıt) otomatik silen, Supabase Cron
  ile çalışan opsiyonel bakım scripti (bkz. aşağıdaki "Otomatik silme" bölümü).
- `manifest.json`, `service-worker.js`, `icons/` — `gemba.html`'in PWA (yüklenebilir
  uygulama) olarak çalışmasını sağlayan dosyalar.

Build adımı yoktur. Dosyalar herhangi bir statik hosting'e (GitHub Pages, Vercel, Netlify vb.)
doğrudan yüklenebilir.

## Saha kişisinin akışı (gemba.html)

1. Bölge seç
2. Sorumlu kişi seç
3. Uygunsuzluk nedeni seç
4. Fotoğraf çek (kamera doğrudan açılır, galeri değil)
5. Önizlemeyi kontrol et, Gönder

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

- `gemba_findings`, `gemba_areas`, `gemba_responsibles`, `gemba_reasons` tablolarını oluşturur
- Row Level Security (RLS) politikalarını uygular: anon kullanıcılar sadece bulgu ekleyebilir,
  bölge/sorumlu/neden listelerini okuyabilir; admin (authenticated) her şeyi yapabilir
- `gemba-photos` adında herkese açık okunabilir bir Storage bucket oluşturur
- Realtime'ı açar: saha sayfasından yeni bir bulgu gönderildiğinde, admin panelinde açık olan
  **Bulgular** sekmesi sayfa yenilemeden anında güncellenir

> `schema.sql` tamamen tekrar çalıştırılabilir (idempotent) şekilde yazılmıştır. Daha önce bu
> dosyanın eski bir sürümünü çalıştırdıysanız (örn. "reason" kolonu eklenmeden önce), güncel
> dosyayı baştan sona tekrar çalıştırmanız yeterlidir — mevcut verileriniz silinmez.

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

### 6. Bölge, sorumlu kişi ve uygunsuzluk nedeni listelerini doldurun

`admin.html`'e admin hesabınızla giriş yapın, **Listeler** sekmesine geçin. Üstteki üç
seçenekten (Bölgeler / Sorumlu Kişiler / Uygunsuzluk Nedenleri) hangisini dolduracaksanız
onu seçip ekleyin:

- **Bölgeler:** gemba turlarında gezilecek bölgeler (örn. "Baskı Hattı 1", "Depo").
- **Sorumlu Kişiler:** uygunsuzluklardan sorumlu tutulacak kişiler.
- **Uygunsuzluk Nedenleri:** karşılaşılabilecek uygunsuzluk türleri (örn. "5S Standardına
  Uygun Değil", "Güvenlik Ekipmanı Eksik").

Bu üç liste, saha sayfasındaki (`gemba.html`) dropdown'ları otomatik olarak besler.

## Otomatik silme (7 gün sonra, opsiyonel)

`cleanup.sql`, yüklenen fotoğrafları ve kayıtları **7 gün sonra otomatik olarak** hem
`gemba_findings` tablosundan hem de Storage'daki fiziksel dosya olarak siler. Silinmesine
**2 gün veya daha az** kalan bulgular admin panelinde bir uyarı rozetiyle
("Yarın silinecek", "2 gün sonra silinecek") işaretlenir — bunun için ekstra bir kurulum
gerekmez, admin panelini her açtığınızda otomatik hesaplanır.

Silmenin kendisi ise Supabase'in **pg_cron** özelliğiyle sunucu tarafında, siz panele
girmeseniz bile her gece çalışır. Anahtarınız **Supabase Vault**'ta şifreli saklanır; hiçbir
dosyada düz metin olarak durmaz, ne saha sayfası (anon) ne de admin paneli (authenticated)
bunu API üzerinden okuyabilir. Kurulumu:

1. **Project Settings > API Keys** sayfasından `sb_secret_...` ile başlayan **secret key**'inizi
   kopyalayın.
2. Supabase panelinde **SQL Editor**'de, `cleanup.sql` dosyasının **ADIM 0** yorumundaki
   komutu kopyalayıp `BURAYA_...` kısmını gerçek anahtarınızla değiştirerek çalıştırın (bu
   komutu hiçbir dosyaya kaydetmeyin, sadece SQL Editor'e bir kere yapıştırın).
3. `cleanup.sql`'in **ADIM 1** bölümünü (eklentiler + fonksiyon + zamanlama) çalıştırın.
   Bu bölümde hiçbir gizli anahtar yoktur, GitHub'a güvenle yüklenebilir.
4. Test etmek için SQL Editor'de `select gemba_cleanup_old_findings();` çalıştırın — hata
   almamalısınız (7 günden eski kaydınız yoksa sessizce biter, bu normaldir).

Yanlışlıkla placeholder metni ("BURAYA_...") gerçek anahtar yerine kaydettiyseniz, tekrar
`create_secret` çalıştırmak yerine (isim çakışması karışıklık yaratabilir), ilk komutun
döndürdüğü id'yi kullanarak düzeltin: `select vault.update_secret('dönen-id', 'doğru-anahtar');`

Bu adım opsiyoneldir — çalıştırmazsanız sistemin geri kalanı normal şekilde çalışmaya devam
eder, sadece eski fotoğraflar otomatik silinmez.

## Sahada uygulama gibi kurulum (PWA)

Saha ekibindeki kişiler `gemba.html` linkini telefon tarayıcısında açtıktan sonra:

- **Android (Chrome):** sağ üstteki ⋮ menüsünden **"Ana ekrana ekle" / "Uygulama yükle"**
- **iPhone (Safari):** paylaş butonundan **"Ana Ekrana Ekle"**

seçeneğine dokunarak, telefonlarına gerçek bir uygulama gibi ikonla açılan bir kısayol
kurabilirler. Bu bir `.apk` değildir; Play Store/App Store'a ihtiyaç duymaz, build veya
imzalama gerektirmez, siteyi her güncellediğinizde otomatik olarak günceldir.

## Kullanım

- **Saha ekibi:** Ana ekrana eklenen Gemba ikonuna dokunur. Bölge, sorumlu kişi ve
  uygunsuzluk nedeni seçip fotoğraf çeker, önizler, gönderir.
- **Admin:** `admin.html`'e giriş yapıp **Bulgular** sekmesinde gelen bulguları (fotoğraf,
  bölge, sorumlu kişi, neden, tarih) sırayla görüntüler; bölge/sorumlu/nedene göre filtreler.
  **Listeler** sekmesinden bölge, sorumlu kişi ve uygunsuzluk nedeni listelerini yönetir.
  Admin panelinde başka hiçbir işlem (durum değiştirme, not ekleme vb.) yoktur.

## Notlar

- Mail/SMTP bildirimi yoktur.
- QR kod üretimi/okuma yoktur; bölge, sorumlu kişi ve uygunsuzluk nedeni seçimi düz
  dropdown'lar ile yapılır.
- `admin.html` içinde hiçbir hardcoded şifre/PIN bulunmaz; yetkilendirme tamamen Supabase
  Auth ve RLS politikaları üzerinden sağlanır.
- Admin panelinin tek görevi gelen kayıtları görüntülemektir; açık/kapalı durum takibi veya
  kapatma işlemi kasıtlı olarak yoktur.
