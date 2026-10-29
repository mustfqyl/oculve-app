# Oculve (Flutter VPN istemcisi)

## Klasör yapısı
- `lib/core/`: providers, vpn, auth, network, desktop, localization, theme
- `lib/features/`: auth, home, settings, splash
- `android/ ios/ macos/ windows/ linux/`: platform runner'ları ve tünel kodu
- `ios/XrayTunnel/`, `macos/XrayTunnel/`: Packet Tunnel extension'ları
- `native/linux/`: root yetkili TUN yardımcısı (`oculve-tunnel`)
- `vendor/`: yerel değiştirilmiş `flutter_vless`, `passkeys_darwin`, `byedpi`
- `tool/`: hazırlık/paketleme scriptleri; `test/`: Dart ve Python testleri; `docs/`: tasarım notları

## Giriş noktaları
- Dart: `lib/main.dart` (`main`, `UncontrolledProviderScope`; masaüstünde tray/pencere de burada)
- Android: `MainActivity.kt`, `OculveApplication.kt`
- iOS/macOS: `Runner/AppDelegate.swift`, tünel `XrayTunnel/PacketTunnelProvider.swift`
- Windows: `windows/runner/main.cpp`; Linux: `linux/runner/main.cc`

## Komutlar
- `flutter pub get` (çalışıyor) / `flutter analyze` (şu an 1 `unused_field` uyarısı: `xray_core_settings_screen.dart` `_vpnOnlyDomains`, exit 1)
- `flutter test` çalışır (446 geçti); `XRAY_TEST_BINARY=/yol/xray` yalnızca 19 Xray entegrasyon testini açar, yoksa atlanır
- `python3 -m unittest discover -s test -p '*_test.py'` (28/28 geçti)
- `./tool/prepare_ios_vpn.sh`, `./tool/prepare_macos_vpn.sh`: Apple build öncesi ZORUNLU; Package.swift ve `project.pbxproj` yazar (çalıştırılmazsa xcodebuild "requires minimum platform version 13.0" ile düşer)
- `python3 tool/prepare_desktop.py {linux|windows}`, sonra `flutter build linux --release`, `sh tool/package_linux.sh`
- `flutter build apk --debug` (son denemede `packageDebug` `libflutter.so` NoSuchFileException ile düştü; SDK var, doğrulanmadı)
- macOS: önce `prepare_macos_vpn.sh`, sonra `xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner ... CODE_SIGNING_ALLOWED=NO build` (script'siz exit 65; script'li hali doğrulanmadı)
- CI: `.github/workflows/platform-verification.yml` (Flutter 3.44.9); Makefile yok

## Mimari ve kurallar
- State: Riverpod 2 (`StateNotifierProvider` ağırlıklı); servislerde ara sıra `ChangeNotifierProvider`
- Platform kanalları `MethodChannel`, ad öneki `com.oculve/...` (veya `oculve/startup`)
- Lint: `flutter_lints`, ek kural yok; Dart SDK `^3.10.8`
- Yerelleştirme elle: `lib/core/localization/app_strings.dart` (doğrulandı: gen-l10n yok; `generate: true`, `l10n.yaml`, `app_localizations*.dart` yok)
- API origin: `--dart-define=OCULVE_API_ORIGIN=...` (varsayılan `https://www.oculve.com`)
- Kod üretimi yok (build_runner/freezed yok); `*.g.dart` dosyalarını elle düzenleme
- Mevcut dosya ve kullanıcı değişikliklerini koru; kapsam dışı değişiklik yapma

## Tuzaklar
- `vendor/flutter_vless` pub cache'ten farklı; değişiklikleri pub cache'e değil `vendor/` altına yap
- Yeni Network Extension hedefi ekleme; App Group `group.com.oculve.app`, extension `com.oculve.app.XrayTunnel`
- Keychain grubu iOS ve macOS entitlement'larında aynı olmalı; simülatör imzalı VPN'i doğrulamaz
- Passkey için `OCULVE_APPLE_APP_IDS` ve `OCULVE_ANDROID_CERTIFICATE_SHA256` gerekir, yoksa native passkey kapanır
- Windows/Linux desteği duraklatıldı; Linux helper gerçek ağda doğrulanmadı; çökmede nftables kill switch kalıcı olabilir
- Sırlar (`key.properties`, `*.jks`, `.env*`) repo dışında; commit etme. Runtime sürümleri `tool/runtime-lock.json` ile sabit
- Native istekler Cloudflare bot challenge'a takılmamalı
- "CONNECTED" yalnızca iletim hazırlığıdır, sansür aşıldığı anlamına gelmez
- Build/test kanıtını imzalı cihaz, canlı VPN, sızıntı ve production doğrulamasından ayrı raporla
