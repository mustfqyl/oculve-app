# Bağlıyken sunucu değiştirme — 13 Ekim 2026

Konum sayfasındaki bağlantıyı kesme uyarısı kaldırıldı. Konum sayfası ve masaüstü menüsü aynı sunucu değiştirme işlemini kullanıyor. Geçiş, eski bağlantıyı durdurup sıfırdan bağlanmak yerine ayrı bir korumalı değiştirme komutuyla yapılıyor. Başarısız geçiş, zaman aşımı ve motor hatasında uygulama otomatik olarak korumayı kaldırmıyor; kullanıcı Disconnect seçerse kaldırılıyor. Optimal seçimi geçiş sırasında fiziksel ağda yeni ping ölçümleri başlatmıyor.

## Platform uygulamaları

- Android: mevcut TUN arayüzü tutuluyor; arayüz politikasını değiştirmeyi gerektiren talepler eski tüneli kapatmadan reddediliyor. Yeni sunucu adresleri eski, kimlik doğrulanmış Xray bağlantısı üzerinden sertifikası kontrol edilen HTTPS DNS ile çözülüyor. Kurtarma sırasında yalnızca hazırlanmış adresler kullanılıyor; fiziksel DNS'e dönüş yapılmıyor. Raporlarda `TUN_RETAINED` olayı görülebiliyor.
- iOS ve macOS: çalışan Network Extension oturumuna yeni Keychain referansı gönderiliyor. Yapılandırma ile kullanıcı bilgileri mesajda taşınmıyor. İşçiler değiştirilirken oturum ve sanal DNS açık kalıyor. Gerekli yeni adresler eski bağlantı üzerinden sertifikası kontrol edilen şifreli DNS ile hazırlanıyor. Stop sırasında gecikmiş kurtarma işleri yeni motor başlatamıyor.
- Windows: mevcut WFP koruması sunucu değişimi boyunca tutuluyor. Yeni adreslerin çözümü çalışan eski tünel üzerinden yapılıyor; koruma kaldırılarak DNS istisnası açılmıyor. Uygulamanın varsayılan HTTPS DNS ayarı destekleniyor ve seçili çıkıştan geçiriliyor.
- Linux: aynı yetkili yardımcı işlem yeni profili alıyor. İşçiler veya rotalar kaldırılmadan önce ayrı nftables tablosu atomik olarak hazırlanıyor. Yalnızca ayrı cgroup içindeki Oculve işçileri fiziksel ağ çıkışına sahip; IPv6 ve fiziksel DNS engelleniyor. Hata veya beklenmeyen kapanış filtreyi kaldırmıyor. Güncel yardımcının kurulması, nftables ve cgroup v2 gerekiyor. Ayrıntı: `native/linux/README.md`.

Mevcut, kullanıcı tarafından seçilmiş split routing ve uygulama istisnaları korunuyor; bunlar kasıtlı doğrudan bağlantılardır. Koruma, VPN üzerinden yönlendirilmesi gereken trafik için uygulanır.

## Doğrulama

- Flutter: 69 test geçti; bağlı konumların seçilebilir olması, desteklenmeyen platformun korumasız fallback kullanmaması, geçiş hatası/zaman aşımı/motor hatasında stop çağrılmaması ve doğrudan ping yapılmaması dahil.
- Android: 52 yerel birim testi geçti. Fiziksel cihaz test paketi derlendi. İki gerçek yerel VLESS sunucusu arasında değişirken TUN'un korunmasını ve yeni sunucu üzerinden uygulama baytlarının taşınmasını kontrol eden cihaz testi eklendi; telefon bağlı olmadığı için çalıştırılmadı.
- Apple: iOS 63 ve macOS 87 destek testi geçti; macOS'ta 1 test atlandı. Gerçek yönetici kodunu kullanan Keychain/Network Extension test düzenekleri geçti; geçişte Stop çağrılmadığı ve mesajın yalnızca referans içerdiği kontrol edildi.
- iOS simülatör uygulaması ve VPN uzantısı derlendi. macOS uygulaması ve VPN uzantısı imzasız derlendi. Bu derlemeler canlı VPN kanıtı değildir.
- Windows C++ yapılandırma testleri geçti; Windows'un yerel VPN motoru Windows üzerinde derlenip çalıştırılmadı.
- Linux: 19 yapılandırma/koruma testi geçti; gerçek Linux çekirdeği üzerinde filtre ve ağ testi yapılmadı.
- Değiştirilen Dart dosyalarının analizi ve diff boşluk kontrolleri geçti.

Android test paketi `Oculve-0.1.0-Android-v6-ServerSwitch.apk` adıyla üretildi. Sürüm 0.1.0, build 6, profile/AOT. Önceki v5 ile imza aynı; üzerine güncellenebilir. Xray/ByeDPI/tun2socks ikilileri önceki sürümle aynı. Test anahtarları APK'ya dahil değil. Paket doğrulama bilgileri `build/server-switch/apk-verification.json` içinde.

## Canlı test sınırı

Bu turda fiziksel Android/iPhone, Windows veya Linux ağında sunucu değişimi sırasında IP/DNS paket yakalama testi yapılamadı. Dolayısıyla bütün platformlarda sızıntı olmadığı doğrulanmış bir sonuç olarak sunulmuyor. Özellikle geçiş sırasında yeni TCP/UDP/DNS istekleri, mevcut akışlar, IPv6, geçersiz sunucu ve bağlantıyı kesme senaryoları gerçek cihazlarda kontrol edilmeli. iOS canlı VPN testi ayrıca uygun Network Extension imzası gerektiriyor.

Bu çalışma üretim API verilerini değiştirmedi, dağıtım/push yapmadı ve Android ısınma incelemesini kapsamadı.

## Uygulama sırasında kullanılan platform belgeleri

- [Apple: çalışan uzantıya mesaj gönderme](https://developer.apple.com/documentation/networkextension/netunnelprovidersession/sendprovidermessage(_:responsehandler:))
- [Apple: tünel ağ ayarları](https://developer.apple.com/documentation/networkextension/netunnelprovider)
- [Netfilter: nftables filtreleri ve cgroup eşleştirme](https://netfilter.org/projects/nftables/manpage.html)
