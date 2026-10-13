# Personal Team ile iPhone testi

Bu çalışma 13 Ekim 2026 tarihinde, kaynak commit `1f1aedb58a8ae64e3572c26d45bc5f11e00d6982` üzerinden hazırlandı. Asıl `Runner`, `XrayTunnel`, entitlements, Dart uygulaması ve bağımlılık sürümleri değiştirilmedi.

## Ayrı test çalışma alanı

`tool/prepare_ios_personal_team.py`, mevcut dosyaları `build/ios-personal-team/` altına kopyalar. Git tarafından yok sayılan bu klasör yeniden üretilebilir; kalıcı geliştirme değişiklikleri asıl kaynakta yapılmalıdır.

Test kopyasında:

- Uygulama adı **Oculve Test**; test için benzersiz bir Bundle ID kullanılır.
- Xcode'da kullanıcının kendi Personal Team'i seçilir ve Automatic Signing açılır.
- Runner'ın XrayTunnel bağımlılığı ve extension gömme aşaması çıkarılır. XrayTunnel kaynakları ve target'ı korunur.
- Runner için boş test entitlements kullanılır. Network Extension, App Groups, Associated Domains ve üretime ait paylaşılan Keychain grubu bu sürümde talep edilmez.
- VPN bağlantı düğmesi açıklayıcı hata verir; native VPN izni veya tünel başlatma çağrısı yapmaz.
- Domain yetkisi olmadığı için iOS passkey kullanılabilirliği kapatılır; standart erişim kodu/TOTP giriş akışı korunur.
- XRay framework, Swift paketinin içine kopyalanır ve paket manifestinde açıkça bu yerel dosya seçilir. Flutter'ın paket symlink'i üzerinden hatalı framework yolu çözümlenmesi önlenir.
- CocoaPods target'larının minimum iOS sürümü Xcode 27 ile uyumlu olacak şekilde 15.0 yapılır. Mevcut `prepare_ios_vpn.sh` de üretilen Flutter Swift paketini iOS 15'e hizalar.

API adresi gerçek `https://www.oculve.com` olarak kalır. Backend, veritabanı ve sunucu yapılandırması değiştirilmez.

## Kurulum ve doğrulama sonucu

- Eşleştirilmiş fiziksel iPhone'da Developer Mode açık olmalıdır.
- Personal Team ile Debug derlendi ve yüklendi; Flutter karşılama ekranı cihaz ekran görüntüsünde doğrulandı.
- Son kurulum geliştirme imzalı **Release** sürümüdür. Kullanıcı uygulamayı simgesinden açtı; bu sürüm debugger bağlantısına ihtiyaç duymaz.
- Telefonda gerçek Keychain yazma, okuma ve test anahtarını silme başarılı.
- Gerçek `OculveApi` ile HTTPS `GET /api/user/me`, kimlik bilgisi gönderilmeden beklendiği gibi **401** döndü. Sertifika doğrulaması devre dışı bırakılmadı.
- Test kopyasındaki `lib/personal_team_probe.dart`, asıl uygulamayı başlatıp tek seferlik cihaz kontrolü yapar. Sonucu uygulamanın geçici klasörüne yazar; erişim kodları, oturum token'ları, API gövdeleri ve cihaz kimlikleri kaydedilmez. Sonraki açılışlarda sonuç dosyası varsa kontrolü tekrarlamaz.
- Son yeniden açılıştan sonra Ayarlar ekranının da cihazda düzgün görüntülendiği doğrulandı. Kullanıcı hesap/sunucu ayrıntılı testinin atlanmasını istedi; kullanıcı bilgilerinin doğruluğu ve sunucu listesi bu kurulumda doğrulanmadı.
- Mac'teki hedeflenmiş mevcut Flutter testlerinin 24'ü geçti. Fiziksel cihaz integration-test denemeleri başarılı bir sonuç üretmedi; Xcode 27 başlatma/sonuç yorumlama uyuşmazlıkları ve testin açılış bekleme sorunu görüldü. Bunlar başarılı test olarak sayılmadı.
- Device Hub ekran kontrolü, telefonun iOS 27 veya üstünde olmasını istiyor. Telefon yükseltilmedi; mevcut iOS üzerinde ekran görüntüleri Apple cihaz araçlarıyla alındı.
- VPN ve iOS passkey test sürümünde kapalıdır. App Store/TestFlight dağıtımı veya ücretli işlem yapılmadı.

Cihaz kontrol sonucu ve kurulum/derleme kayıtları `build/ios-personal-team/build/` altında bulunur. Son cihaz görüntüsü `iphone-final.png`, kontrol sonucu `oculve-device-smoke.json` dosyasıdır.

## Yeniden hazırlama

Codex bu hazırlığı şu araçla tekrar yapabilir:

```sh
python3 tool/prepare_ios_personal_team.py --team <PERSONAL_TEAM_ID> --bundle-id <TEST_BUNDLE_ID>
```

Ardından tüm bağımlılık/derleme işlemleri kopyanın kökünden yapılır. Flutter config-only hazırlığından sonra `tool/prepare_ios_vpn.sh` çalıştırılır. CocoaPods gerekiyorsa **kopyanın ios klasöründen** çalıştırılır. Xcode'da açılacak dosya `build/ios-personal-team/ios/Runner.xcworkspace`, scheme `Runner` ve hedef fiziksel iPhone'dur.

Debug sürümü Flutter/Xcode debugger ile açılır. Telefonda simgesinden bağımsız açılabilmesi için aynı Personal Team ile geliştirme imzalı Release sürümü kullanılabilir. Bu, App Store veya TestFlight dağıtımı değildir.

Mevcut cihaz profili 20 Ekim 2026 saat 12:03:39 Türkiye saatiyle sona erer. Yeniden imzalayıp yükleme gerekir; sonraki hazırlamada yeni profilin son kullanma tarihi ayrıca kontrol edilmelidir.

## Apple Developer onayından sonra

Asıl `ios/Runner.xcworkspace` kullanılmalıdır; test kopyasını üretim sürümüne çevirmek gerekmez. Runner ve XrayTunnel için ücretli ekibin imzalama/provisioning ayarları tamamlanmalıdır. App `com.oculve.app`, extension `com.oculve.app.XrayTunnel`, ortak App Group `group.com.oculve.app` korunmalıdır.

Network Extension (Packet Tunnel) ve App Groups yetkileri/profilleri iki target ile uyumlu olmalıdır. Passkey için Associated Domains ve sunucudaki apple-app-site-association uygulama kimliği doğrulanmalıdır.

İncelemede ayrıca VPN ortak Keychain grubunun eşleştirilmesi gerektiği görüldü: Dart şu anda `group.com.oculve.app` geçirirken iOS entitlements `$(AppIdentifierPrefix)com.oculve.app` tanımlıyor. Native `TunnelSecretStore` erişim grubunu doğrudan Security API'ye geçiriyor. Gerçek VPN etkinleştirilmeden önce iki target'ın imzalı ortak Keychain grubu ile runtime değeri aynı yapılmalı ve cihazda doğrulanmalıdır. Bu çalışma üretim VPN kodunu değiştirmedi.

Sonrasında gerçek cihazda tünel açılışı, internet/DNS, bağlantı kesme ve yeniden bağlanma ayrı olarak test edilmelidir; arayüz testinin başarılı olması VPN'in çalıştığını kanıtlamaz.

## Mevcut kapsam dışı kontrol bulguları

Genel analizde mevcut `auth_repository.dart` içinde kullanılmayan `_refreshAfterRegistration` uyarısı ve `connection_settings_pages_test.dart` içinde artık bulunmayan `BypassWebsitesScreen` referansı görüldü. Bunlar bu kurulum değişikliğinden kaynaklanmıyor; üretim koduna kapsam dışı düzeltme yapılmadı. Hedeflenen mevcut giriş/kayıt/arayüz testlerinin 24'ü geçti.
