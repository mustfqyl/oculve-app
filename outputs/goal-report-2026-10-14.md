# Oculve — 14 Ekim 2026 yerel geliştirme raporu

**Yerel çalışma teslimi.** Geliştirme 05:02 İstanbul’da kotanın %100 tüketilmesiyle güvenli noktada durdu. Otomatik devam 11:12 İstanbul’da geldi; 07:20 sınırı geçmiş olduğundan yeni geliştirme açılmadı. Teslim raporu bu devamda sonlandırıldı. Aşağıdaki kod, test ve uygulama çıktıları güvenli devam noktasıdır. Bu rapor bütün uygulamanın kusursuz veya production-ready olduğu anlamına gelmez.

## Kullanıcı açısından iyileşenler

- Konum ekranından ayrılınca veya Optimal bağlantıyı iptal edince bekleyen pingler gereksiz ağ işi açmıyor. Socket/isolate yolunda devam eden batch de sonlandırılıyor. Eski sonuç yeni ölçümü veya seçimi ezmiyor; çok adresli DNS yanıtında eşzamanlı adres ölçümü üçle sınırlı, bütün adresler korunuyor.
- Yavaş akan API, DNS, SOCKS ve HTTP yanıtları yükleme/bağlantı akışını süresiz tutamıyor. Toplam süre ve yanıt boyutu sınırları uygulanıyor, başarısız aktarımın kaynakları kapatılıyor. Apple socket yardımcılarında fractional timeout'un yanlışlıkla sınırsız beklemeye dönüşmesi düzeltildi.
- VPN kapanırken yeni bağlantı başlatılması engellendi. Apple trafik sorguları üst üste binmiyor; kapanmadan sonra gelen eski yanıt sayaçları yeniden doldurmuyor.
- Android 7'de bulunmayan süreç API'leri sürüm kontrolüyle kullanılıyor. Plugin'in daha eski Android dalında da TLS hostname doğrulaması korunuyor; doğrulanamayan TLS socket'i kapatılıyor. Minimum Android sürümü yükseltilmedi. Süreç API'lerinin sürüm sınırı [resmî Android API farkından](https://developer.android.com/sdk/api_diff/26/changes/java.lang.Process) doğrulandı.
- LAN paylaşımında kimlik doğrulamamış bir istemci bayt damlatarak bağlantı kotasını süresiz işgal edemiyor. Başarılı relay'in uzun süreli kullanımına yeni bir süre sınırı konmadı.
- macOS'ta sonucu kullanılmadan atılan ağ tanılaması için çalıştırılan 15 komut ve logda tamamen sansürlenen otomatik debug IPC/file okumaları kaldırıldı; mevcut gizlilik mesajı korunuyor. İstatistik yükleme animasyonu sistemin hareket azaltma ayarına uyuyor.
- API byte tamponu ve tamamlanmış pingin iptal dinleyicisi gözden geçirilerek gereksiz veri tutulması azaltıldı. Tüm uygulama için nicel CPU/RAM kazancı ölçülmedi.

## Doğrulama

| Alan | Kanıt |
|---|---|
| Ortak Flutter/Dart | Son ping/çözümleyici/VPN grubu 72 test; son isolate cleanup 3 gerçek socket testi. API/oturum/cihaz kimliği 13, DoH 8, LAN/proxy 10, istatistik/background 12 ilgili test geçti. Aynı testler farklı paketlerde tekrarlandığından bu sayılar benzersiz toplam olarak toplanmamalı. |
| Android | Etkilenen JVM grubunda 17 test geçti. Native lint: 0 error, 15 warning. Warning'ler ağırlıklı bağımlılık güncelliği, style ve test verification uyarıları; kritik API hataları giderildi. Debug APK derlendi. Android cihaz/emulator çalışması yapılmadı. |
| Apple | iOS/macOS üretim Swift polling ve gerçek loopback deadline fixture'ları geçti. 11 odaklı Swift privacy/DNS testi, manager policy kontrolleri, SOCKS/HTTP transport ve yanlış parola/sertifika reddi geçti. Gstatic üzerinden gerçek güvenilir HTTPS pozitif kontrolü geçti. |
| Gömülü Xray | macOS'ta gerçek 26.9.9 runtime ile 12 modun gizlilik, auth/rotation, DNS relay/refusal, domain routing, sayaç ve management listener sınırları geçti. Host VPN/proxy/DNS ayarları değiştirilmedi. |
| Uzun kullanım | 1000 gerçek yerel start/HTTP-transfer/stats/stop çevrimi geçti. Başlangıç/bitiş açık FD=7; son RSS=24,608,768 byte, yaklaşık 23.5 MiB. Bu ayrı Xray test sürecidir; Flutter uygulaması veya imzalı Packet Tunnel RAM ölçümü değildir. |

Hatalar yalnızca yeni testler eklenerek örtülmedi: eski kontrol mantığıyla ping/DoH/API/Native socket/stop yarışları başarısız sonuç verdi; düzeltmelerle ilgili kontroller geçti. macOS tanılaması aynı üretim struct'ında 15 komuttan 0 komuta indi. Apple 150 ms socket bütçesi eski kaynakta 334–1425 ms sonunda yanlış başarı verirken güncel kaynak 151–152 ms sonunda kapandı.

## İncelenebilir çıktılar

Kaynak: `/Users/mustfq/Desktop/oculve-app`, `main`, başlangıç HEAD `317507c`; değişiklikler yerel çalışma ağacında, commit/push yapılmadı. Başlangıçta mevcut kullanıcı değişiklikleri korunuyor; oturum/theme/native manager gibi önceden değişmiş alanların tamamı bu çalışmada yeni yapılmış gibi sahiplenilmiyor.

- [Android debug APK](/Users/mustfq/Desktop/oculve-app/build/app/outputs/flutter-apk/app-debug.apk)
- [iOS Simulator uygulaması](/Users/mustfq/Desktop/oculve-app/build/ios/iphonesimulator/Runner.app)
- [Unsigned macOS uygulaması](/Users/mustfq/Desktop/oculve-app/build/macos-unsigned/Build/Products/Debug/Oculve.app)
- [İlerleme, paket kanıtları ve devam kuyruğu](/Users/mustfq/Desktop/oculve-app/outputs/goal-progress-2026-10-14.md)
- [Temiz uzun kullanım ölçümü](/Users/mustfq/Desktop/oculve-app/outputs/goal-native-soak-2026-10-14.txt)
- [Çalışma ağacı dosya listesi](/Users/mustfq/Desktop/oculve-app/outputs/goal-worktree-status-2026-10-14.txt)

Üç uygulama çıktısı son doğrulanmış kaynakla yeniden derlendi. Yeniden üretilebilir yeni kontroller `vendor/flutter_vless/tool/test_apple_traffic_polling.sh`, `test_apple_socket_deadlines.sh` ve `test_macos_runtime_soak.sh` içindedir.

## Kalan sınırlar ve devam

Production backend, veritabanı, sunucu, kullanıcı hesabı ve synced sources değiştirilmedi. Push/merge/deploy/mağaza yayını yapılmadı.

**Production-ready kanıtı yok:** fiziksel iPhone/iPad/Android cihazında imzalı gerçek VPN, Apple Network Extension/App Group yetkileri, mağaza/release imzası, canlı hesapla uçtan uca bağlantı ve bütün uygulamanın CPU/RAM profili doğrulanmadı. Windows/Linux native uygulama buildleri bu macOS ortamında doğrulanmadı; ortak davranışın odaklı testleri mevcut. Bu kontroller build/simulator başarısıyla ikame edilmedi.

Devamda kaynak kaydı esas alınmalı; tamamlanan dosyalar tekrar keşfedilmemeli. Apple watchdog'un gerçek cihazda stop/recovery gecikmesi ve gerçek cihaz kaynak profili kalan önemli doğrulama alanlarıdır. Yeni iş ancak somut kritik bulguya dayanmalı; 06:50'den sonra büyük iş açılmamalı.
