# Perch — Proje Planı

> MacBook çentiğini (notch) müzik çalar + günlük planlayıcıya çeviren, native macOS uygulaması.
> **Not:** Bu proje iPhone için değil, **MacBook (macOS)** içindir.

Durum: **v0.1 (müzik) ve v0.2 (zamanlayıcı + Pomodoro) yazıldı**, kullanıcı testinde. v0.3 (yapılacaklar), dosya rafı + AirDrop ve v0.4 (sesli not) yazıldı. **v1.0 cila yazıldı** (ayarlar, TR/EN, menü çubuğu, ikon, README, .dmg, MIT). Away Guard araştırması tamam, sıradaki: kilitsiz prototip (canlı RSSI grafiği) ile yürüme testi.

---

## 1. Fikir

Çentik, üzerine gelince açılan bir panel olur. Rakipler (boring.notch, NotchNook, Alcove vb.) müzik ve dosya rafına odaklı.
Biz bunların üstüne **zaman ve plan araçlarını** ekliyoruz: alarm, zamanlayıcı, Pomodoro, yapılacaklar ve **sesli hızlı not**.

Pazarlama cümlesi: *"Çentiğin hem müzik çalar hem planlayıcın."*

## 2. Özellikler

### Temel (rakiplerde de var)
- [x] Müzik paneli: kapak, sanatçı/şarkı, ilerleme çubuğu, ileri/geri/oynat
- [ ] Kapaktan renk alan arka plan
- [x] Dosya rafı (çentiğe sürükle-bırak)
- [x] Pano geçmişi (metin, bellekte)
- [x] Pil / sistem durumu (Sistem sekmesi: CPU, RAM, ağ, pil, disk)

### Bizim farkımız
- [~] **Alarm ve zamanlayıcı:** (zamanlayıcı bitti, saatli alarm henüz yok) çentikte geri sayım, bitince genişleyip uyarır, birden fazla zamanlayıcı
- [x] **Pomodoro:** çalışma/mola döngüsü, mola gelince müziği kısma
- [x] **Yapılacaklar listesi:** çentikten hızlı görev ekle, tik at
- [x] **Sesli hızlı not:** kısayola bas, konuş, ses kaydı + yazıya çevrilmiş metin kaydedilsin
- [x] **AirDrop alanı:** dosyayı çentikteki AirDrop kutusuna bırak, AirDrop ile gönder
- [x] **Sesli notu Apple Notes'a kaydet:** AppleScript ile Notes'a yazıya çevrilmiş metin eklenir, iCloud ile iPhone'a senkronlanır. (Ses dosyası eklenemez, Notes'un AppleScript'i ek desteklemiyor; ses uygulamada kalır.)
- [ ] Takvim entegrasyonu: sıradaki etkinliğe kalan süre, toplantıya tek tıkla katıl
- [ ] Hatırlatıcılar (su iç, ayağa kalk)
- [ ] Alışkanlık takibi (seri sayacı)

### 🧪 Beta / opsiyonel: Uzaklaşınca Ekranı Gizle (Away Guard)
**Durum:** Taslak. İlk projenin odağı değil, sonradan bakılacak. Zorunlu değil, **Ayarlar'dan açılıp kapatılabilen beta özellik** olacak.

**Amaç:** Kafede/ortak alanda MacBook başında çalışırken kısa süreliğine kalkınca (tuvalet vb.) ekranın başkaları tarafından görülmesini engellemek. Kamera kullanılmaz.

**Uzaklaşmayı anlama sinyalleri (kullanıcı seçer, birden fazlası birleştirilebilir):**
- [ ] iPhone Bluetooth sinyal gücü (yakınlık/uzaklık)
- [ ] Apple Watch yakınlığı
- [ ] MacBook hareketi (taşındı mı) — Apple Silicon'da erişilebilirliği araştırılacak
- [ ] Klavye/fare boşta kalma süresi (yardımcı sinyal)
- [ ] Bluetooth kulaklık bağlantısı (yardımcı sinyal)

**Ekranı gizleme seçenekleri (kullanıcı seçer):**
- [ ] Gerçek kilit (ekranı uyut + şifre/Touch ID iste)
- [ ] Gizlilik katmanı: bulanıklaştır / karart / oyalayıcı ekran
- [ ] Bildirim önizlemelerini gizle
- Not: Overlay tek başına güvenlik sayılmaz, gerçek kilitle birlikte önerilir.

**Çentik entegrasyonu:** "Koruma açık" ikonu, gizlenmeden önce geri sayım, geri gelince karşılama, tek tıkla duraklatma.

**Bilinen sınırlar (README'de dürüstçe yazılacak):**
- Telefon masada kalırsa uygulama "yakında" sanır
- Bluetooth sinyali oynak, hassasiyet ayarı gerekir
- "Gizlilik yardımcısı" olarak pazarlanır, "güvenlik uygulaması" olarak değil

**Araştırma sonucu (2026-11-16):** Üç sorunun cevabı da **evet**. iPhone ve Apple Watch yakınlığı CoreBluetooth taramasıyla (RSSI) okunabiliyor, MacBook hareket sensörü bu Mac'te root'suz akıyor, ekran kilidi "hemen" ayarıyla çalışıyor. Yürüme testi henüz yapılmadı. Ayrıntı ve önerilen mimari: [AWAY_GUARD_RESEARCH.md](AWAY_GUARD_RESEARCH.md).

## 3. Sürüm planı

| Sürüm | İçerik |
|-------|--------|
| **v0.1** | Çentik paneli iskeleti + müzik paneli |
| **v0.2** | Zamanlayıcı / alarm + Pomodoro |
| **v0.3** | Yapılacaklar listesi |
| **v0.4** | Sesli hızlı not (kayıt + yazıya çevirme) |
| **v1.0** ✅ | Cila, ayarlar, Türkçe/İngilizce dil, README, .dmg |
| **Beta (sonra)** | 🧪 Away Guard: uzaklaşınca ekranı gizle (opsiyonel, ayarlardan aç/kapat) |
| Sonra | Takvim, hatırlatıcılar, alışkanlık takibi, not özetleme |

## 4. Teknik notlar

- **Dil / UI:** Swift + SwiftUI (pencere yönetimi için AppKit)
- **Geliştirme ortamı:** VS Code + Xcode komut satırı araçları (Xcode 27, Swift 6.4 kurulu). Uygulama paketi için Swift Package Manager ya da Xcode projesi, karar verilecek.
- **Müzik bilgisi:**
  - macOS 15.4'ten beri özel MediaRemote API'sine yetki kontrolü geldi.
  - Çözüm: [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (sistem `perl` üzerinden).
  - Yedek: Spotify / Apple Music için AppleScript.
  - Yeni macOS sürümlerinde (27) tekrar test edilecek.
- **Alarm / bildirim:** UserNotifications
- **Takvim / hatırlatıcı:** EventKit
- **Ses kaydı:** AVFoundation
- **Yazıya çevirme:** Apple Speech / SpeechAnalyzer (cihaz içinde, gizlilik dostu)
  - ✅ Türkçe (tr-TR) `SFSpeechRecognizer` cihaz içi destek DOĞRULANDI (macOS 27). Yeni `SpeechTranscriber` listesinde Türkçe yok, o yüzden eski API kullanılıyor. Kalite gerçek kullanımda denenecek. Başlamadan kontrol et. Olmazsa yerel Whisper modeli alternatif.
- **İzinler:** Mikrofon, konuşma tanıma, (sonra) takvim
- **Çentiksiz Mac'ler:** Yüzen kapsül olarak çalışsın (isteğe bağlı)

## 5. Açık sorular / yapılacak araştırma

1. Türkçe konuşma tanıma: Apple cihaz içi destek var mı, kalite nasıl?
2. MediaRemote sorunu macOS 27'de çözüldü mü, adapter hâlâ gerekli mi?
3. VS Code'da Swift geliştirme akışı: SPM mı, Xcode projesi mi?
4. Uygulama imzalama: Apple Developer hesabı var mı? (Yoksa kullanıcı "Open Anyway" yapmak zorunda, README'de anlatılacak.)
5. Uygulama adı ne olsun? → **Perch** olarak karar verildi

## 6. GitHub ve pazarlama

- Lisans: MIT
- README: GIF'li demo, özellik listesi, kurulum adımları, Türkçe + İngilizce
- Releases'te indirilebilir `.dmg`
- Rakiplerden ayrışma: zaman/plan araçları + sesli not
- Paylaşım yerleri: Product Hunt, Reddit r/macapps, X
- Rakipler: [boring.notch](https://github.com/TheBoredTeam/boring.notch), [DynamicNotch](https://github.com/jackson-storm/dynamicnotch), [Atoll](https://github.com/Atoll-Labs/Atoll), [Notchly](https://www.ifun.de/notchly-neue-dynamic-island-app-fuer-macbooks-280329/)

## 7. Sıradaki adım

1. Türkçe konuşma tanıma desteğini araştır
2. Uygulama adına karar ver
3. v0.1'i başlat: boş çentik paneli + müzik
