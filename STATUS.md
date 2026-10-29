# Oculve durum (2026-10-29, plan uygulaması sonrası)
Hiçbir değişiklik commit/push edilmedi (çalışma ağacında). Kanıt: B = host build/test, S = statik okuma, D = imzalı cihaz, L = sızıntı yakalama, P = production. D, L ve P YOK.

## Platform matrisi (B, son doğrulama)
- Android debug APK: derleniyor. iOS `--no-codesign`: derleniyor. macOS imzasız xcodebuild: derleniyor (Adım 1 sonrası doğrulandı; son turda yeniden koşulmadı, o turdan beri yalnız Dart taşıması ve CI/docs değişti).
- Linux, Windows: bu Mac'te doğrulanamadı; yalnızca CI. Duraklatıldı, dokunulmadı.

## Analyze / test (B)
- `flutter analyze`: No issues found (eski `_vpnOnlyDomains` uyarısı giderildi).
- `flutter test`: 462 geçti, 19 atlandı (Xray binary yok), 0 kaldı (baz 446 + 16 yeni karakterizasyon).
- Python unittest: 39/39 (baz 28 + 11 yeni). iOS tünel SwiftPM: 67; macOS: 89 yürütüldü/1 atlandı (eski "93" notu güncel değil).

## Yapılanlar (plan adımı -> sonuç)
- 1: iOS çift `getSecurityCapabilities` düzeltildi (`protectedServerSwitch` artık dönüyor), macOS yanıtı `androidProxyDns`'le tamamlandı. Yeni dispatch sözleşme testi düzeltme öncesi kırmızıydı. Cihazda doğrulanmadı: iOS `oculve_replace` yolu ilk kez açıldı.
- 2/3: statik iz `docs/device-static-trace.md`, cihaz checklist'i `docs/device-verification-checklist.md` (+ sonuç şablonu).
- 4: CI'ya macOS `apple` job'ı + Android Gradle unit test adımı. `actionlint` yok, CI hiç koşmadı; Xcode_16.4 yolu doğrulanmadı.
- 6: `_vpnOnlyDomains` yazma-only ölü alan kaldırıldı.
- 7a: `docs/apple-tunnel-drift-report.md` + `test/apple_tunnel_drift_test.py` (9 byte-özdeş + 2 import-normalize çift kilitli).
- 8 (yarım): `test/vpn_connection_flow_test.dart` 16 karakterizasyon testi. Sealed-state refactor YAPILMADI.
- 9: `xray_preferences.dart` 3559 -> 1283 satır (3 `part` dosyası), mantık değişmedi (reviewer satır satır doğruladı).

## Yapılmayanlar ve nedeni
- 5: cihaz kapısı (sizde). 7b birleştirme: architect önermedi. 8 sealed state: kapı geçilmeden başlamaz. Windows `v2ray_manager.cpp` stub'ına dokunulmadı.

## Açık riskler (S, düzeltilmedi; tünel davranışı, cihaz doğrulaması gerekir)
- iOS DoH IP'si tünel dışı route'a giriyor (TunnelDNSPolicy :108): olası sızıntı. iOS `api` bölümü korunuyor (XrayPrivacyConfig).
- Protected switch durdurma hatasında watchdog yeniden başlamıyor, sleep/wake de kurtarmıyor (iOS+macOS). Reddedilen replace'te eski Keychain referansı geri yüklenmiyor.
- macOS `beginStartup` sırası: DPI beklemesi sırasında gelen Stop kaybolabilir.
- Android: uygulama içi lockdown yok (kill switch Always-on ayarına bağlı), servis süreç ölümünde sızıntı penceresi olabilir, IPv6 engeli yalnız yorumla belgeli.
- Üretim tuhaflıkları (testlerle sabitlendi): iptal edilen replace'te çift `stopVless`; başarısız replace sonrası `connect()` replace modunda kalır; macOS runtime hatasında tünel durdurulmuyor.
- Linux helper gerçek ağda doğrulanmadı; nftables kill switch çökmede kalıcı olabilir.

## Karar (architect): düzelt, yeniden yazma. Kalan sıra: cihaz checklist'i -> yukarıdaki düzeltmeler -> sealed state -> (gerekirse) Apple birleştirme.
