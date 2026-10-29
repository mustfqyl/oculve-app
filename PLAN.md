# Oculve stabilizasyon yol haritası (nihai, architect onaylı)

## Durum
- Kullanıcı onayladı; uygulama yapıldı, commit/push YOK (çalışma ağacında). Ayrıntı: STATUS.md.
- Bitenler: 0,1,2,3,4,6,7a,8(yalnız karakterizasyon testleri),9. Yapılmadı: 5 (cihaz kapısı, kullanıcıda), 7b (architect önermedi), 8 sealed state (kapıya bağlı), 10 (STATUS güncellendi).
- Sıradaki: kullanıcı docs/device-verification-checklist.md'yi cihazda koşar; sonra drift raporundaki 7 düzeltme adayı, sonra sealed state.
- Açık kararlar: commit'ler, CI'da apple job'ı (push), iOS replace yolunun cihazda doğrulanması, tünel düzeltmeleri.
- Son doğrulama: analyze temiz; flutter test 462/19 atlandı/0; Python 39/39; Android/iOS build B.

## Steps
- [x] 0. Başlangıç: git status, kullanıcı değişiklikleri korunur, test baz çizgisi kaydedilir
- [x] 1. iOS `getSecurityCapabilities` çift case düzeltmesi + native kaynak sözleşme testi
- [x] 2. Android/macOS kill switch ve yeniden bağlanma akışının statik izi (kod değişmez)
- [x] 3. İmzalı cihaz checklist'i ve sonuç şablonu (`docs/`)
- [x] 4. CI: macOS job (iOS/macOS build, SwiftPM testleri) + Android Gradle unit testleri
- [ ] 5. Kullanıcı checklist'i Android/iOS/macOS'ta koşar (iOS switch dahil); sonuç kapısı
- [x] 6. Küçük temizlik: `_vpnOnlyDomains` (Windows stub'a dokunulmaz)
- [x] 7a. Apple tünel kodu: iki ağacın diff raporu + drift-check testi
- [ ] 7b. (Yalnızca onayla) Apple tünel kodunu tek pakette birleştir
- [ ] 8. `vpn_provider`: önce karakterizasyon testleri, sonra sealed state
- [x] 9. `xray_preferences.dart` bölünmesi (saf taşıma, düşük öncelik)
- [x] 10. STATUS.md güncellemesi, kanıt türleri ayrı (B build/test, S statik, D cihaz, L sızıntı, P production)

## Ayrıntı

**Adım 0 (tester).** analyze, flutter test, Python unittest, iOS/macOS SwiftPM tünel testleri koşulur; sayılar dosyaya yazılır. Kabul: baz çizgi kayıtlı; sonraki adımlarda sayılar gerekçesiz düşmez.

**Adım 1 (builder → tester → reviewer).** `vendor/flutter_vless/ios/flutter_vless/Sources/flutter_vless/FlutterVlessPlugin.swift:466-473` tek case: `protectedServerSwitch: true, iosKeychainReference: true, androidProxyDns: false`. macOS plugin (~:825) aynı üç anahtara tamamlanır. Python kaynak sözleşme testi: (a) hiçbir dispatcher'da (Android/iOS/macOS/Windows) aynı metot adı iki kez geçmez; (b) platform başına açık allowlist: beklenen metot kümesi ve capability anahtarları (`getTrafficProtection`, `getLocalProxyEndpoint` yalnızca macOS). Dart mock assert'i eklenmez (native hatayı yakalamaz). Kabul: yeni test düzeltme öncesi KIRMIZI (çıktı rapora eklenir), sonra yeşil; flutter test, Python ve iOS no-codesign build yeşil. Bu düzeltme üretimde hiç koşmamış iOS `oculve_replace` yolunu (`FlutterVlessPlugin.swift:1030-1050` → `ios/XrayTunnel/PacketTunnelProvider.swift:457`) açar; adım 5'te iOS switch geçene kadar "build doğrulandı, cihazda doğrulanmadı". Commit öncesi kullanıcıya bildirilir.

**Adım 2 (explorer/architect, salt okunur).** Android VpnService ve macOS provider: kill switch, yeniden bağlanma/uyku, ağ değişimi, replace sırasında capture'ın açık kalması. Her şüphe dosya:satır; adım 3 checklist'ine girer.

**Adım 3 (builder, yalnızca docs).** Her madde geçti/kaldı kriteri + kanıt + platform sütunu: bağlan, kes, yanlış kimlik, ağ yok; switch penceresinde fiziksel arayüzde sunucu IP'si dışında 0 paket (macOS `tcpdump -i en0`, iOS `rvictl`); DNS/IPv6/WebRTC; kill switch (Android "VPN olmadan engelle", Apple `includeAllNetworks`); uyku/uyanma, Wi-Fi↔hücresel; iOS extension bellek tepesi (7b tabanı). Şablon: cihaz modeli, OS, build SHA, "CONNECTED ≠ sansür aşıldı".

**Adım 4 (builder → tester → reviewer; 3 ile paralel).** `platform-verification.yml` macos-15 job: prepare scriptleri, `flutter build ios --no-codesign`, macOS xcodebuild `CODE_SIGNING_ALLOWED=NO`, `vendor/flutter_vless/tool/test_{ios,macos}_tunnel_support.sh`, sonda `git diff --exit-code`. Android job: Gradle unit testleri (temiz build). Aksiyonlar SHA-pinli, `permissions: contents: read`, sır yok, Xcode sürümü açık. Kabul: `actionlint` temiz, aynı komutlar yerelde yeşil; gerçek CI koşusu "doğrulanmadı". Push ve CI koşusu kullanıcıya bırakılır.

**Adım 5 (kullanıcı, kapı).** Sızıntı varsa plan durur; yalnızca ilgili tünel katmanı için ayrı plan yazılır ve kullanıcıya sorulur. 7 ve 8 bu kapı geçilmeden başlamaz.

**Adım 6 (builder → tester).** Önce `git log -S _vpnOnlyDomains`. UI'nin kopuk parçasıysa bağla + test; gerçekten ölüyse sil (silme onayla). Kabul: `flutter analyze` exit 0.

**Adım 7a (architect analiz, builder script).** `ios/XrayTunnel/PacketTunnelProvider.swift` ↔ vendor macOS `FlutterVlessPacketTunnelProvider.swift` ve 15 çift dosya diff'lenir; her fark: kasıtlı / drift / hata. Drift-check testi CI'ya bağlanır. Kullanıcı 7b'ye karar verir.

**Adım 7b (yalnızca onayla).** Dosya dosya taşıma; her taşımadan sonra SwiftPM (macOS 93, iOS 67), iOS+macOS Runner build, prepare + `git diff --exit-code`. Hedef adları, App Group `group.com.oculve.app`, Keychain grubu, bundle id'ler değişmez; yeni NE hedefi yok. Kabul: test sayısı baz altına düşmez; checklist'in switch/kill switch/sızıntı maddeleri cihazda tekrar geçer; iOS extension bellek tepesi tabandan %10'dan fazla artmaz.

**Adım 8.** Karakterizasyon testleri (bağlan, kes, switch, iptal `cancelled()`/`_switchAwaitingNative`, native hata, `vpnTunnelMayBeActiveProvider`) mevcut koda karşı yeşil; sonra sealed state. Kabul: testler değişmeden yeşil; 9 flag/4 provider → tek state/notifier raporlanır; UI metni değişmez.

**Adım 9.** Saf taşıma; reviewer diff'in yalnızca taşıma+import olduğunu doğrular.

## Genel kurallar
- Her adımdan önce `git status`; vendor değişiklikleri `vendor/` altına, pub cache'e değil.
- Kullanıcı değişiklikleri korunur; push, deploy, silme, commit açık onay olmadan yok; adım başına bir commit önerilir.
- Kullanıcıya görünen metin değişirse `app_strings.dart` EN/ES/TR birlikte.
- Roller: kod builder, doğrulama tester, diff reviewer, statik iz/diff sınıflandırma architect/explorer.
- Onay noktaları: 1 (iOS replace yolu commit'i), 4 (push/CI), 5 (cihaz kapısı), 6 (silme), 7a→7b, 8 (başlama).
