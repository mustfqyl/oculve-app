# Oculve — yenilenen kota ile yerel geliştirme raporu

14 Ekim 2026. Önceki 15 paket korunarak 18 ek paket (16–33) uygulandı. Mevcut kullanıcı değişiklikleri çalışma ağacında korundu. HEAD `317507c`; commit, push, merge, deploy, production hesap/veritabanı/sunucu değişikliği yapılmadı. ChatGPT `sources/` aynası değiştirilmedi. Son kota kontrolü %99 kullanım; bu rapor güvenli teslim kaydıdır, bütün ürünün kusursuz veya production ready olduğunun beyanı değildir.

## Kullanıcı açısından değişenler

- Paralel kayıt istekleri artık tek cihaz kimliği üretir; kalıcı yazma bitmeden ikinci istek başka kimlikle ilerleyemez.
- Gecikmiş hesap yanıtı yeni hesap durumunu geri alamaz. Hesap URL'si değişirse sunucular doğru URL'den yüklenir; yeni verilerle eski profiller başarı olarak eşleştirilmez.
- Çakışan girişlerde en yeni giriş kendi oturumuna sahip olur. Eski çıkış, yeni girişi silemez. Bozuk JSON veya eksik/boş oturum çerezi, eski hesabı yeni girişin başarısı gibi gösteremez.
- İki aşamalı giriş ve passkey akışları korunur. Challenge aşamasında erken gönderilmiş oturum kaydedilmez. Sunucu hesabı oluşturmuş ama oturum yanıtı eksikse kaydedilmiş kodla tekrar giriş yolu korunur; hesap oluşturma körlemesine tekrarlanmaz.
- Android, iOS ve macOS kapanış başarısını native kapanış tamamlanınca bildirir. Başarısız kapanış başarı gibi gösterilmez; doğrudan ölçüm koruması kapanış doğrulanana kadar kalır.
- İptal edilmiş bağlantının gecikmiş temizliği veya zaman aşımı eski hatayı yeni duruma geri yazamaz. Zamanlayıcıdaki kapanış hatası yakalanmadan dışarı çıkmaz.
- Android servis yenilenmesi, eski native temizliği ile yeni başlangıcı aynı kuyrukta sıralar. Son servis kapanınca kuyruk kapanır; geç callback yeni iş açamaz.
- Android sistem VPN iznini iptal edince uygulama hemen izin hatasını gösterir, otomatik tekrarları keser ve eski “bağlı” olaylarını yok sayar. Elle izin vererek tekrar bağlantı çalışabilir. Kayıt/silme sırası, gecikmiş profil yazısının iptal edilmiş yetkiyi yeniden oluşturmasını önler.
- Native bozuk durum/hata içeriği konsola ham olarak yazılmaz. Çakışan başlatmalar fazladan durum dinleyicisi açmaz.
- Gecikmiş trafik ölçümleri tüm bayt farkını bir saniyelik hız olarak göstermez; Android ve Apple gerçek geçen süreyi kullanır. Android DPI Bypass sayacı doğru `byedpi` kanalını sorgular; normal VPN `proxy` kanalını kullanmaya devam eder.
- Büyük abonelikte tekrar kontrolünün bütün önceki sunucuları taraması kaldırıldı. Aynı yerel debug testinde 10.000 sunucu / 1.79 MB import 453 ms → 186 ms oldu (yaklaşık %59 kısa). Sunucu sayısı, sırası, ilk ad ve konfigürasyon kimliği korundu. Bu mobil FPS veya uygulama RAM ölçümü değildir.

## Doğrulama kanıtı

Değişen alanlara odaklı testler çalıştırıldı; aynı başarılı gruplar gerekçesiz tekrarlanmadı.

- Son auth/kayıt/TOTP/passkey/session grubu: 42 test; API body deadline ve storage yarışları: 5 test. `auth-ack-final-boundaries.log`, `delivery-api-boundaries.log`.
- VPN yaşam döngüsü, izin, olay ve hata grubu: 43 test; gerçek EventChannel codec/privacy sınırı ayrıca geçti. `revoke-event-dart-boundaries.log`, `revoke-codec-test.log`.
- Android native revocation, aynı uygulama receiver güvenliği, consent, profil IO, kuyruk, recovery ve FD grubu: 13 test. Son DPI/stat output/rate grubu: 7 test. `revoke-event-native-final.log`, `dpi-traffic-final.log`.
- Native çalışma kuyruğu 1.000 lifecycle çevriminde her seferinde kapandı; eski gecikmeli iş iptal edildi. JVM canlı thread sayısı başlangıç/son 11 → 11. Bu tam Android uygulama/VPN veya RAM soak testi değildir. `delivery-queue-soak.log`.
- Apple üretim polling metotlarıyla gecikmiş cevap, tek ölçüm ve kapanış sonrası eski cevap kontrolleri geçti. iOS/macOS manager policy sınırları da geçti. `apple-rate-final.log`, `ios-stop-policy.log`, `macos-stop-policy.log`.
- Profil import/hesap sırası grubu: 16 test; karşılaştırılabilir tek dosya benchmarkı ayrı kaydedildi. `import-scale-final.log`, `import-scale-comparable.log`.
- İlgili analizler temiz; bütünleştirme analizinde sorun yoktu. Son çalışma ağacı whitespace kontrolü ayrıca kaydedildi.

Log adları `/tmp/oculve-v2-` öneki taşır; ayrıntılı tarihçe [ilerleme kaydında](/Users/mustfq/Desktop/oculve-app/outputs/goal-progress-v2-2026-10-14.md). Test IO/HTTP/OS sınırlarının mock olduğu yerler bu kayıtta açıkça belirtilmiştir; gerçek production işlemi yapılmış gibi sunulmaz.

## İncelenebilir kod ve güncel çıktılar

- Gerçek kaynak: `/Users/mustfq/Desktop/oculve-app`; değişiklikler çalışma ağacında, kullanıcı tarafından incelenebilir ve henüz yayımlanmamıştır.
- Android debug APK, Paket33 dahil: [app-debug.apk](/Users/mustfq/Desktop/oculve-app/build/app/outputs/flutter-apk/app-debug.apk).
- iOS Simulator, son ortak Dart kaynakları dahil: [Runner.app](/Users/mustfq/Desktop/oculve-app/build/ios/iphonesimulator/Runner.app).
- Unsigned macOS, son ortak Dart kaynakları dahil: [Oculve.app](/Users/mustfq/Desktop/oculve-app/build/macos-unsigned/Build/Products/Debug/Oculve.app).
- Son build logları: `final-android.log`, `delivery-build-ios.log`, `delivery-build-macos.log`.
- [Çalışma ağacı kaydı](/Users/mustfq/Desktop/oculve-app/outputs/goal-worktree-status-v2-2026-10-14.txt).

## Yayın ve doğrulama sınırları

Fiziksel Android/iOS/iPad cihazında imzalı gerçek VPN, uzun süreli tam uygulama CPU/RAM ve OS izin/lifecycle smoke testi yapılamadı. Android emülatör/ADB cihazı mevcut değildi. Apple Developer/Google Developer, dağıtım imzası, entitlement/association ve mağaza yayın süreci bu çalışmayla tamamlanmış değildir. Windows/Linux native çalışma ortamında güncel cihaz testi yapılmadı; ortak kod davranışları ilgili testlerle korundu.

Yerel web login/registration kaynakları yalnız sözleşme doğrulaması için okundu; canlı deployment/account doğrulaması yapılmadı. Önceki 1.000 çevrimli gerçek bağımsız Xray sonucu tam Flutter uygulamasının RAM değeri değildir. Build, simulator ve unit test başarısı gerçek cihazda Packet Tunnel/VPN kanıtının yerine geçmez.
