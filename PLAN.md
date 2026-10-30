# Bypass DPI yol haritası (architect planı, 2026-10-29)
(Önceki stabilizasyon planı commit 23ff416 ile bitti; ayrıntısı git geçmişinde ve STATUS.md'de.)

## Durum
- Kullanıcı onayladı ("plan yap ve harekete koyul"). Mimari korunur: packetFlow -> HEV -> Xray -> byedpi. Xray'siz mimari yalnız A7 ölçümü tetiklerse (A8).
- Zaten yapıldı: DoH IP yaması (`dpiDnsServers`), kök neden host'ta kanıtlandı (--no-domain + hostname DoH).
- Sıradaki: A0 (simülatör), A1+A3 (Dart config), sonra A2, A4, A5, A9. Cihaz kapıları kullanıcıda: A6 (Mac fd), A2/A4/A5 gerçek operatör, A7 RAM, A3 QUIC davranışı.
- Kanıt türleri: B build/test, S simülatör, D imzalı cihaz. Simülatör kanıtı cihaz kanıtı değildir.

## Steps
- [ ] A0. DPI simülatörü + ciadpi matrisi (`test/dpi_sim/`, host, CI uyumlu)
- [ ] A1. DPI config'inde hostname hedefi kalmasın (DNS IP, çoklu yol, özel hostname kuralı)
- [ ] A2. Profil yedek döngüsü + yeni stratejiler (--tlsrec, --oob/--disoob, --timeout, auto grupları)
- [ ] A3. UDP/QUIC: UDP 443 hızlı reject (Xray routing)
- [ ] A4. "Bypass etkin" kanıtı: engelli-site probe, CONNECTED'dan ayrı durum, ES/TR/EN metin
- [ ] A5. Ağ başına öğrenme (hash'li, yalnız cihazda) + kesilmede sonraki profil
- [ ] A6. macOS fd kalıcı çözümü (dup/tek sahip) — Mac cihaz kapısı
- [ ] A7. RAM: GOMEMLIMIT/GOGC, geo yok, phys_footprint ölçümü — cihaz kapısı
- [ ] A8. (Yalnız A7 kriteri tutarsa) Xray'siz mimari — ayrı plan
- [ ] A9. DPI tükenince VLESS'e otomatik geri dönüş (`dpiExhausted`)
- [ ] A10. iOS/macOS tutarlılığı: drift testi her adımda; Windows/Linux yalnız config testi

## Ayrıntı (kısa)
**A0.** Python stateless SNI-filtreleyen ara kutu (SNI listesine RST/drop/block-page; yeniden birleştirme yok), yerel TLS sunucusu, `ciadpi` (vendor/byedpi/upstream'den /tmp'de derle). Matris: profil x (reset, drop, ilk-segment, tlsrec-kuralı). Kabul: bypass'sız curl engelli SNI'da başarısız, bir profilde başarılı; deterministik, ağsız.
**A1.** `xray_preferences.dart` configureDpiBypass/dpiDnsServers: DPI modunda hiçbir outbound/DNS hedefi çözülmemiş hostname olmasın. Bilinmeyen hostname'li DNS sunucuları düşürülür, hiçbiri kalmazsa varsayılan IP'li DoH seti (1.1.1.1, 8.8.8.8, 9.9.9.9). Kabul: config testleri.
**A2.** Swift `startNativeRuntime` (`for profile in [selected]` -> `profileCandidates`, deneme başı ~4 sn, toplam ~20 sn), `engine.c` auto grupları: tlsrec, split, disorder, oob, karışık; `--timeout 3`; bellekte cache (hostname/IP diske yazılmaz). Her iki Apple ağacı + drift testi. Kabul: simülatörde "yalnız tlsrec geçer"/"yalnız oob geçer" senaryolarında <=2 denemede doğru grup.
**A3.** UDP 443 ve genel UDP için blackhole; DNS UDP 53 muaf. Kabul: config testi. Dipnot: VoIP/oyun UDP DPI modunda çalışmaz.
**A4.** Durumlar `connected`, `bypassVerified`, `bypassUnverified` (CONNECTED değişmez, altında küçük satır). Probe hedefi log'a yazılmaz.
**A5.** Ağ anahtarı = tuzlu hash (ham SSID/operatör saklanmaz), App Group içinde yedeklenmeyen konum, TTL.
**A6.** Hipotez: Xray stop'ta NE utun fd'sini kapatıyor. Doğrulama: stop öncesi/sonrası `fcntl(fd,F_GETFD)` logu. Çözüm: fd'yi bir kez al, Xray'e `dup` ver, tek sahipli kapatma (çift kapatma riski!).
**A7.** Hedef zirve footprint < 40 MB (limit ~50). A8 kriteri: > 45 MB veya jetsam >= 1/saat.
**A9.** Varsayılan açık/kapalı ürün kararı; DPI motoru durdurulup Xray VLESS başlar (iki motor birlikte RAM tutmaz).

## Kurallar
- Her adımdan önce git status; vendor/ altına yaz; commit/push kullanıcı onayıyla (bu seferki "tek commit" onayı geçerliydi, yenisi sorulur).
- Kullanıcıya görünen metin: app_strings.dart ES/TR/EN birlikte, localization testi.
- Roller: builder kod, tester doğrulama, reviewer diff, architect tasarım. Cihaz kanıtı ayrı raporlanır.

## Pasif öğrenme ve son çare (architect, onaylı)
- [x] P1 ağ kimliği anahtarı (iface + iface IPv4 ağı hash'i; ham adres saklanmaz; eski `v1.<iface>` anahtarı fallback) – TunnelDpiRuntime iOS/macOS
- [x] P2 engine: first_group rotasyonu, ok/fail sayacı, exhausted sayacı + geriye uyumlu C API (`start_grouped`, `group_stats`, `exhausted`)
- [x] P3 Swift: periyodik stats (45 sn + stop) → kalıcı grup sırası; kaydetme artık ok_count >= 3'e bağlı, tek prob kaydetmiyor
- [x] P4 başlangıç probu öğrenilmiş profilde bağlantıyı bekletmez (2 sn sonra arka plan doğrulaması, başarısızsa öğrenilen değer silinir)
- [~] P5 İPTAL (kullanıcı istemedi: durum göstergesi, geri çekilme, VLESS bildirimi yapılmayacak) – eski not: durum yüzeyi (bypass doğrulandı/deneniyor/etkisiz) + geri çekilme 30sn→30dk; VLESS geçişi yalnız kullanıcı onayıyla (A9)
- Cihaz kapıları: ok_count doğruluğu, RAM, AUTO timeout 5s→2.5s ölçümü (şimdilik DEĞİŞTİRME)

## Durum (2026-10-30 gece, commit YOK, cihaza kurulum YOK)
- Biten: DPI P1-P4 (pasif öğrenme), tünel durumu restore, hız paralelleştirme, UI turu (satır kayması, DNS, troubleshooting, connect alevi), karanlık parlaklık HEAD'e döndü, tek paylaşılan arka plan (AppBackdrop) + fade-through geçiş.
- Geçiş kök nedeni: ilk rota MaterialPageRoute idi, Cupertino rotaya canTransitionTo=false → alttaki sayfa secondaryAnimation almadı, solmadı. Çözüm: main.dart onGenerateRoute: appRoute(SessionGate). Test: test/page_transition_fade_test.dart.
- Doğrulama (build/test kanıtı): analyze temiz, flutter test 514/19 atlandı, Python 61, iOS tünel 74, macOS 98, byedpi 7, iOS --no-codesign build OK.
- Açık: iPhone'da geçiş akıcılığı ve 'ışık patlaması' cihazda doğrulanmadı (kök neden ayrıca bulunmadı, fade-through muhtemelen giderir); bağlanma süresi ölçülmedi; Android Kotlin derlenmedi; P5 iptal.
- Sıradaki: sabah iPhone'a kur (yalnız iPhone), geçişi/ışık patlamasını dene, sonra tek commit.
- Yedekler: build/backup_before_ui_revert, build/backup_before_shared_bg.

## Bağlam içi hata geri bildirimi (2026-10-30, commit YOK, kurulum YOK)
- Geri dönüş: git tag `restore/before-inline-errors`, build/restore_before_inline_errors/; kodda tek anahtar `kInlineFeedback` (app_feedback.dart) false => eski banner.
- Yapıldı (inline, yerleşim kaymaz): ana ekran CONNECT butonu (hint alanında hata, tek titreme, fade), giriş (alan altı InlineErrorSlot), kayıt (footer'da InlineErrorSlot, _fail yardımcısı). Yeni: lib/core/widgets/inline_feedback.dart.
- Kalan çağrı yerleri (ayarlar, hesap, sunucu seçimi, LAN, DPI, tray, startup, client logs, android routing, main.dart) hâlâ banner ama yeni kurallarla: süre mesaja göre 4.5-8 sn, 380 ms yumuşak çıkış, tekrar süreyi uzatmaz.
- Sıradaki (isteğe bağlı): ayar satırlarında satır içi hata, 'Kopyalandı ✓' buton dönüşümü.
- Doğrulama: analyze temiz, flutter test 519/19 atlandı. Cihazda görülmedi.

## Güncelleme: kalan hata ekranları + haptik (commit YOK, kurulum YOK)
- Satır içi hata (InlineErrorOf, dinleyen, kInlineFeedback=false iken banner'a düşer): ana ekran butonu, giriş, kayıt, LAN paylaşımı, tray, android uygulama yönlendirme, client logs, sunucu seçimi. '✓ Kopyalandı' rozeti: LAN.
- Hâlâ banner (yumuşatılmış): Connection Settings (DNS/DPI/başlangıç), hesap ekranı, genel hata sayfası. Builder'ın bunlar için denemesi testleri bozdu (hesapta 26px taşma, DPI satır yüksekliği, hata satırı sayfa sonunda); build/builder_settings_attempt/ altında saklı, geri alındı.
- Haptik: lib/core/haptics/app_haptics.dart (tap/selection/success/warning/error). Bağlı: connect butonu (basış, bağlandı, hata), banner, InlineErrorController/Tooltip, giriş/kayıt hatası, SettingsCycleRow. Switch'lerde YOK.
- Doğrulama: analyze temiz, flutter test 515/19 atlandı. Cihazda görülmedi.

## Banner kaldırıldı (2026-10-30, commit YOK, kurulum YOK)
- Hiçbir hata/uyarı banner olarak çıkmıyor (kInlineFeedback=true). Kalan AppFeedback.showError çağrıları yalnız !kInlineFeedback geri dönüş yolunda.
- Yerler: ana ekran butonu, giriş/kayıt (alan altı), LAN/tray/android routing/client logs/sunucu seçimi (InlineErrorOf), Connection Settings (grup başlığı DNS/CONNECTION/DPI BYPASS/DIAGNOSTICS başlığı hataya dönüşür; restore butonunun altı; split tunneling'de alan altı), hesap ekranı (AppPage header başlığı mesaja dönüşür: AppPage.feedback).
- Masaüstü başlangıç bağlantı hatası vpnErrorProvider'a yazılır (CONNECT butonu gösterir).
- Bilinen sınır: hesap ekranında diyalog açıkken kopyalama mesajı diyalogun arkasındaki başlıkta kalır. Switch'lerde haptik yok.
- Doğrulama: analyze temiz, flutter test geçti. Cihazda görülmedi.

## Çok IP'li sunucuda yedekleme (iOS, commit YOK, kurulum YOK)
- Tasarım: architect. Uzantı tarafında: sunucu adını tüm IPv4'lere çöz, yarışmalı TCP probuyla (250ms aralık, tavan 3sn, en çok 4 eşzamanlı) ilk erişilebileni sabitle; en çok 16 adayın hepsi /32 rota dışlamasında (sunucular kullanıcının kendi IP’leri, paylaşılan CDN değil) (rota yeniden kurulmaz, kill switch penceresi açılmaz); sağlık kontrolü >=2 kez başarısız + sabitlenmiş IP bağlantıyı reddediyor + başka IP cevap veriyor ise sıradakine geç (30sn bekleme, genel kesintide dönmez).
- Yeni: vendor/flutter_vless/ios/.../TunnelEndpointCandidates.swift (+15 test, iOS tünel testi toplam 89). Bağlama: ios/XrayTunnel/PacketTunnelProvider.swift (selectEndpoint, withFailoverExclusions, rotateEndpointIfNeeded).
- YAPILMADI: macOS (çözümleyici tek cevap döndürüyor; çoklu adres toplama gerekir), Android (Xray'in IP seçimi izlenmedi), Dart'tan en hızlı IP ipucu (native hazırlayıcı dns.hosts'u ezdiği için doğrudan yazılamaz), sunucu değiştirme (protected switch) yolunda aday listesi.
- Cihazda doğrulanmadı: yarış süresi, rota dışlama sayısı, çalışma anı rotasyonu, DPI etkileşimi (DPI'da sunucu adresi IP, etkilenmez).

## Hızlı sunucu düşme tespiti (iOS, commit YOK, kurulum YOK)
- Sorun: sunucu düşünce periyodik sağlık kontrolü 60 sn'de bir olduğu için 30-60 sn internet yok gibi kalıyordu. Geçiş kesintisiz olamaz (çıkış IP'si değişir, açık oturumlar kopar); hedef kayıp süreyi kısaltmak.
- Yeni: TunnelStallDetector (gönderiyor ama 6 sn hiçbir şey gelmiyorsa hemen sağlık kontrolü, 10 sn bekleme), EndpointLiveness + 10 sn'de bir seçili IP'ye TCP (yalnız çok IP'li sunucuda, art arda 2 başarısızlık), seçili IP bağlantıyı reddediyorsa ilk başarısız sağlık kontrolünde geç (30 sn bekleme). Dosyalar: vendor/.../TunnelStallDetector.swift (+9 test, toplam 99), ios/XrayTunnel/PacketTunnelProvider.swift.
- Bağlıyken gerçek gecikme: lib/core/vpn/connected_latency.dart (kart ve listede bağlı sunucu).
- Cihazda doğrulanmadı: gerçek düşme senaryosu süresi, pil etkisi (10 sn TCP + 2 sn sayaç okuma), takılma tespitinin yanlış alarmı (QUIC/yüklemede).
