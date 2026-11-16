# Away Guard: araştırma sonuçları

**Soru:** Kullanıcı Mac'inin başından kalktığında ekranı gizlemek için, kamera kullanmadan "uzaklaştı" bilgisini güvenilir biçimde alabilir miyiz?

**Test ortamı:** Mac17,3 (Apple Silicon), macOS 27.0, kodsuz imzayla (ad-hoc) çalışan küçük deneme uygulamaları. Kendi iPhone'u, bir "Tunay" cihazı ve Apple Watch eşleşmişti. Tek cihazda, tek oturumda denendi; **gerçek bir "yürüyüp uzaklaşma" testi henüz yapılmadı**.

## Özet

| Sinyal | Çalışıyor mu? | Güvenilirlik | Not |
|---|---|---|---|
| **iPhone yakınlığı (BLE RSSI)** | ✅ Evet | Orta | CoreBluetooth taramasıyla isim ve canlı RSSI görüldü |
| **Apple Watch yakınlığı** | ✅ Evet | Orta-iyi | iPhone ile aynı yöntem, sinyali daha güçlü ve kararlı çıktı |
| **MacBook hareketi (ivmeölçer)** | ✅ Evet, root'suz | İyi ama belgesiz | ~100 Hz veri akıyor; Apple dokümante etmemiş, ileride bozulabilir |
| Klavye/fare boşta süresi | ✅ Evet | İyi | Yardımcı sinyal, zaten kolay |
| Bluetooth kulaklık bağlantısı | ⚠️ Kısmen | Zayıf | Yalnızca *bağlı* cihazda RSSI var; kulaklık bağlı değilse işe yaramaz |
| Gerçek ekran kilidi | ✅ Evet | İyi | Bu Mac'te "şifre: hemen" ayarlı |

## 1. iPhone ve Apple Watch yakınlığı

**Düz `IOBluetooth` yolu işe yaramıyor.** `IOBluetoothDevice.pairedDevices()` eşleşmiş cihazları listeliyor ama bağlı olmayanlarda `rawRSSI = 0`, `RSSI = 0` veriyor. iPhone ve Watch çoğu zaman "bağlı değil" görünüyor.

**CoreBluetooth taraması işe yarıyor** (BLEUnlock'ın kullandığı yöntem). 9 saniyelik taramada:

| Cihaz | Ortalama RSSI | Paket | Not |
|---|---|---|---|
| Tunay Apple Watch'u | -49 dBm | 10 | Apple üretici verisi (tip 0x10) |
| "Tunay " (eşleşmiş Apple cihazı) | -59 dBm | 13 | Apple üretici verisi |
| iPhone 6s | -59 dBm | 10 | Apple üretici verisi |

- Cihazlar **adlarıyla** görünüyor (eşleşmiş olduklarından macOS kimliklerini çözüyor), yani cihaz seçimi kullanıcıya ad listesiyle yaptırılabilir.
- Saniyede yaklaşık 1 paket geliyor; bu, "uzaklaştı" kararı için yeterli.
- `system_profiler SPBluetoothDataType` de aynı RSSI değerlerini **canlı** gösteriyor (4 örnekte iPhone -66 → -56 oynadı). Yedek veri kaynağı olarak düşünülebilir ama kırılgan.
- **İzin:** Uygulamanın `Info.plist`'inde `NSBluetoothAlwaysUsageDescription` zorunlu; yoksa macOS süreci anında öldürüyor (çıkış kodu 134, doğrulandı). Kullanıcıya bir Bluetooth izin penceresi çıkıyor.

**Kullanılabilirlik yorumu (web kaynakları + bu test):**
- RSSI gürültülü; tek örnekle karar verilmemeli. Hareketli ortalama + histerezis (örneğin 10 sn ortalama, 15 sn eşik altında kalma) şart.
- BLE yayını şifresiz ve kimlik doğrulamasız; bu yüzden **yalnızca kilitleme için güvenli, kilit açmak için değil** (BLEUnlock yazarı da böyle öneriyor). Away Guard zaten sadece gizleme/kilitleme yapacağı için uygun.
- **Telefon masada kalırsa** uygulama "yakında" sanır. Apple Watch bu yüzden daha iyi sinyal; ikisini birleştirme ya da hareket sinyali bunu hafifletir.

## 2. Apple Watch

Apple'ın kendi "Watch ile kilit açma" özelliği için herkese açık API yok. Ancak Watch, iPhone gibi BLE ile yayın yapıyor ve eşleşmiş olduğu için adıyla görünüyor; bu yüzden **yakınlık için yeterli**. Kilit açma yapılmayacak.

## 3. MacBook hareket sensörü

- `ioreg`'de `AppleSPUHIDDevice` altında `accel`, `gyro`, `devmotion6`, `als` vb. düğümler var.
- Web'deki kaynaklar bunun **root gerektirdiğini** yazıyordu. **macOS 27'de root'suz çalıştı:** `IOHIDManagerOpen` başarılı (`0x0`, `uid=501`), sürücü servisine `SensorPropertyReportingState`, `SensorPropertyPowerState`, `ReportInterval` yazmak başarılı.
- Veri akışı doğrulandı: 3 saniyede **299 rapor** (22 bayt, yaklaşık 100 Hz). Ham baytlardan Z ekseni ≈ -1 g okundu (Mac masada düz), X ve Y ≈ 0, fiziksel olarak tutarlı.
- **Riskler:** Belgesiz arayüz, macOS güncellemesiyle kırılabilir. App Store'a uygun değil (zaten hedef değil). Bu sensör her Mac modelinde olmayabilir.
- **Kullanım fikri:** Mac masadayken ivme sabit; taşınınca/açıkken oynayınca değişir. "Mac taşındı + telefon uzaklaştı" gibi kombinasyonlar için faydalı.

## 4. Ekranı gizleme

- Bu Mac'te `sysadminctl -screenLock status` → "screenLock delay is immediate". Yani ekran uyuyunca hemen şifre isteniyor.
- Seçenekler:
  1. **`pmset displaysleepnow`:** Herkese açık komut, ekranı uyutur; "şifre hemen" ayarı açıksa kilitlenir. (Çalıştırılmadı.)
  2. **`SACLockScreenImmediate`** (`login.framework`, özel API): Sembol mevcut, doğrudan kilitler. Özel API olduğu için güncellemelerde değişebilir. (Çağrılmadı.)
  3. **Kendi gizlilik katmanı:** Tüm ekranları kaplayan bulanık/siyah pencere. Tek başına güvenlik **değil**: klavye girdisi arkadaki uygulamaya gitmeye devam eder. Yalnızca kilitle birlikte öneri.
- Bildirim önizlemelerini gizlemek sistem ayarı; uygulamadan değiştirmek yerine, katman açıkken ekran görünürlüğünü kapatmak daha güvenli.

## Önerilen mimari (MVP)

1. **Sinyal:** Seçilen iPhone/Watch'un RSSI'ı (CoreBluetooth, sürekli pasif tarama) + klavye/fare boşta süresi.
2. **Karar:** 10 sn hareketli ortalama, kullanıcının ayarladığı eşik ve süre (varsayılan örn. -80 dBm üstü yok + 15 sn); geri sayım rozeti çentikte ("10 sn sonra kilitlenecek"), tek tıkla iptal.
3. **Eylem:** Gerçek kilit (varsayılan), isteğe bağlı gizlilik katmanı.
4. **Faz 2:** MacBook hareket sensörü (taşınma tespiti), Watch + iPhone birleşimi.
5. **Ayarlar:** Varsayılan **kapalı**, "beta" etiketli, cihaz seçimi ad listesiyle, hassasiyet kaydırıcısı.

## Açık riskler ve sonraki adım

- **Yürüme testi yok:** RSSI'ın bir odadan çıkınca ne kadar düştüğünü ve ne kadar süre geç kaldığını gerçek hayatta ölçmedik. İlk prototip, kilit atmadan, canlı RSSI grafiği gösteren bir sekme olmalı; eşikleri bununla kalibre ederiz.
- iPhone ekranı uzun süre kapalı kalınca yayın sıklığı azalabilir; uzun süreli ölçüm gerekli.
- Bluetooth izin penceresi kullanıcıyı ürkütebilir; ayarlardan açılınca ve gerekçesi açıklanarak istenmeli.
- Sensör ve özel API seçenekleri README'de "deneysel" olarak etiketlenmeli.

## Kaynaklar

- [BLEUnlock](https://github.com/ts1/BLEUnlock): RSSI ile kilitleme/açma, iPhone ve Apple Watch desteği
- [Apple Developer Forums: Apple Watch uzaklığı](https://developer.apple.com/forums/thread/722595)
- [macimu (PyPI)](https://pypi.org/project/macimu/): Apple Silicon ivmeölçer (belgesiz)
