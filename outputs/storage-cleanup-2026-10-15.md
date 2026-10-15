# Yerel depolama temizliği — 15 Ekim 2026

## Sonuç

- Ölçülen geçici/yeniden üretilebilir hedeflerden yaklaşık **18,7 GiB** kaldırıldı.
- Son `df -h /` çıktısı yaklaşık **27 GiB kullanılabilir alan** gösterdi. APFS snapshot/purgeable muhasebesi yüzünden bu değer silinen dosyaların toplamına bire bir eşit değildir.
- `~/.android`: yaklaşık **3,6 MiB** kaldı. `Documents/Codex`: yaklaşık **1,0 GiB**, içeriği değiştirilmedi.
- Android AVD kalmadı; `adb devices -l` boş, `flutter emulators` “No emulators available” döndü. AVD açılmadı.

## Kaldırılanlar

- `~/.android/avd/Oculve_Android_35.avd` ve AVD tanım dosyası: 3,9 GiB, yeniden üretilebilir sanal cihaz.
- `~/.android/cache`: 9,2 MiB, geçici SDK önbelleği.
- `Android/sdk/system-images/android-35/google_apis/arm64-v8a`: 3,8 GiB, SDK Manager ile kaldırılabilen yeniden indirilebilir sistem imajı.
- Proje `build/app/intermediates`: 3,0 GiB, derleme ara çıktıları.
- Proje `build/flutter_vless_android`: 783 MiB, üretilmiş eklenti/test çıktıları.
- İçinde README/rapor referansı bulunmayan eski yinelenen macOS Release klasörleri: `build/macos-default-release`, `macos-default-release-repro`, `macos-final-unsigned`, `macos-no-sign-release`, `macos-no-sign-release-13` (toplam yaklaşık 7,5 GiB).

## Korunanlar

- Proje kaynakları ve vendor kaynakları (`vendor/flutter_vless`), güncel Android APK/profile APK çıktıları, mevcut iOS/macOS build'leri, ekran görüntüleri ve raporlar.
- Android SDK araçları ve platform/build-tools kurulumları.
- Kişisel dosyalar ve `Documents/Codex` içeriği.

Android sistem imajı gerekirse SDK Manager'dan yeniden indirilebilir; AVD'nin kendisi silindiği için yeniden yaratılması gerekir. Windows/Linux masaüstü hedefleri bu Mac'te mevcut olmadığından gerçek uygulama pencerelerinde doğrulanmadı.
