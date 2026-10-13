# Linux tünel yardımcısı

Sunucu değişimi, aynı yetkili yardımcı süreç üzerinden yapılır. Yardımcı yeni sunucunun adresini eski tünel açıkken çözer; çalışan motorları veya rotaları kaldırmadan önce kendi `inet oculve_switch` nftables tablosunu atomik olarak kurar. Başka uygulamaların filtreleri değiştirilmez.

Geçiş için cgroup v2 ve nftables gerekir. Fiziksel ağ çıkışı yalnızca Oculve tarafından başlatılan, ayrı cgroup içindeki Xray/ByeDPI süreçlerine açılır. IPv6 ve fiziksel DNS çıkışı engellenir; uygulamalar yalnızca tünelden çıkabilir. Önceden açılmış fiziksel bağlantılar için genel bir izin kuralı yoktur.

Varsayılan HTTPS DNS korunur. Sistem DNS'i sanal tünel DNS adresine yönlendirilir; HTTPS sorguları seçili VPN/DPI çıkışından geçer. Açıkça tanımlanmış Xray doğrudan yönlendirme kuralları motor üzerinden uygulanmaya devam eder.

Geçiş başarısız olduğunda filtre korunur. Uygulamanın açık Disconnect isteği filtreyi kaldırır. Yardımcı çökerse filtre işletim sisteminde kalır; sonraki oturum filtreyi devralır. Aktif yardımcı yokken açık Disconnect isteğinin yetkili `--disarm` çağrısı yalnızca Oculve tablosunu kaldırır. Tek yardımcı kilidi çalışan bir oturumun yanlışlıkla korunmasız bırakılmasını engeller.

Mevcut kurulumlara güncellenmiş yardımcı `native/linux/install.sh` ile kurulmalıdır. Bu değişikliğin gerçek Linux ağı üzerinde paket yakalama ile doğrulaması henüz yapılmadı; yapılandırma ve hata yolları yerel testlerle kontrol edildi.
