### Neden ?​

Hem forumlarda hem de diğer platformlarda sıkça sorulduğu için ve bununla birlikte Discord yasağının kaldırılması gündemde olduğu için **[GoodbyeDPI-Turkey](https://github.com/cagritaskn/GoodbyeDPI-Turkey)**'i sisteminizden nasıl kaldıracağınızı anlatıyorum.  
  

### GoodbyeDPI-Turkey Ayarlarımı Değiştirir Mi ?​

GoodbyeDPI ya da GoodbyeDPI-Turkey sisteminizde **hiçbir kalıcı değişiklik yapmaz**. Bu, eğer batch şeklinde kullanıyorsanız pencereyi kapattığınızda, eğer hizmet olarak kullanıyorsanız hizmeti kaldırdığınızda GoodbyeDPI ile sisteminiz arasında hiçbir ilişki kalmayacağı anlamına gelir. Eğer hizmeti doğru şekilde kaldırdıysanız ve dosyaları tamamen sildiyseniz sisteminizde meydana gelecek herhangi bir sorun ya da karşılaştığınız herhangi bir hata GoodbyeDPI-Turkey ile alakasız olup başka sebeplerden kaynaklanıyor demektir.  
  

### GoodbyeDPI-Turkey'i ve Dosyaları Tamamen Silmek​

*   Eğer **batch olarak kullanım** sağlıyorsanız (İsimleri **turkey\_\*\*\*** ile başlayan komut dosyaları ile tek seferlik kullanıyorsanız) batch penceresini (Siyah arka planlı içinde yazılar bulunan pencere) kapattıktan sonra .zip dosyasını ayıkladığınız klasörü tamamen silebilirsiniz.
*   Eğer **hizmet kurarak kullanım** sağlıyorsanız ya da daha önce hizmet kurduysanız (İsimleri **service\_\*\*\*** ile başlayan komut dosyaları ile ilgili hizmetin kurulumunu sağladıysanız) öncelikle .zip dosyasının içeriğini ayıkladığınız klasörde bulunan **service\_remove.cmd** dosyasını sağ tıklayıp yönetici olarak çalıştırdıktan sonra açılan pencerede herhangi bir tuşa basarak hizmeti bilgisayarınızdan kaldırmış olursunuz. Bu işlemden sonra .zip dosyasını ayıkladığınız klasördeki dosyaların tamamını silebilirsiniz.

### ​

### DNS Atamasını Geri Almak​

Bu işlemleri gerçekleştirdikten sonra eğer daha önce Windows ayarlarından DNS ataması yaptıysanız bu DNS ayarlarınızı eski haline getirmek için:  

#### Windows 10 İçin:​

*   Windows arama kısmına **Ağ bağlatılarını görüntüle** yazın ve **Ağ bağlantılarını görüntüle** seçeneğine tıklayın. (**Windows+R** tuş kombinasyonu ile ya da **Başlat** menüsünden **Çalıştır** penceresini açıp, kutucuğa **ncpa.cpl** yazıp **Çalıştır** veya **Tamam** butonuna tıklayarak da aynı pencereye erişebilirsiniz)
*   Açılan pencerede bulunan adaptörlerde eğer Wi-Fi için DNS ataması yaptıysanız Wi-Fi adaptörünüzü, eğer Ethernet için DNS ataması yaptıysanız Ethernet adaptörünüzü seçip sağ tıklayarak Özellikler seçeneğini seçin.
*   Açılan pencerede **İnternet Protokolü Sürüm 4 (TCP/IPv4)** isimli seçeneğe tıklayıp aktifleşen Özellikler butonuna tıklayın. (IPv6 için atama yaptıysanız aynı işlemleri **İnternet Protokolü Sürüm 6** için de uygulayın)
*   Ardından alt kısımda bulunan **DNS sunucu adresini otomatik olarak al** seçeneğini seçip **Tamam** butonuna tıklayın.
*   Bilgisayarınızı yeniden başlatın.

  

#### Windows 11 İçin:​

*   Windows arama kısmına **Ayarlar** yazın ve **Ayarlar** penceresini açın. (**Windows+I** tuş kombinasyonu ile de ayarları açabilirsiniz)
*   Sol tarafta bulunan listeden **Ağ ve internet** isimli menüyü açın.
*   Ardından DNS atamasını Wi-Fi için yaptıysanız Wi-Fi seçeneğine, Ethernet için yaptıysanız Ethernet seçeneğine tıklayın.
*   Daha sonra açılan pencerede **_Ağ İsmi_ özellikleri** isimli seçeneğe tıklayın.
*   Açılan pencerede **DNS sunucusu ataması** isimli satırın sağ tarafında bulunan **Düzenle** butonuna basın ve en üstte bulunan **El ile girilen** seçeneğine tıklayıp listeden **Otomatik (DHCP)**'yi seçin.
*   Tekrar Windows arama kısmına **Ayarlar** yazın ve **Ayarlar** penceresini açın. (**Windows+I** tuş kombinasyonu ile de ayarları açabilirsiniz)
*   Sol tarafta bulunan listeden **Ağ ve internet** isimli menüyü açın.
*   Açılan pencerede listenin en altında bulunan **Gelişmiş ağ ayarları** seçeneğine tıklayın.
*   **Ağ bağdaştırıcıları** başlığı altında bulunan adaptörlerde eğer Wi-Fi için DNS ataması yaptıysanız Wi-Fi adaptörünüzü, eğer Ethernet için DNS ataması yaptıysanız Ethernet adaptörünüzü seçerek genişleyen liste görünümünde alt tarafta bulunan **Diğer bağdaştırıcı seçenekleri** başlığının sağında bulunan **Düzenle** butonuna tıklayın.
*   Açılan pencerede **İnternet Protokolü Sürüm 4 (TCP/IPv4)** isimli seçeneğe tıklayıp aktifleşen Özellikler butonuna tıklayın. (IPv6 için atama yaptıysanız aynı işlemleri **İnternet Protokolü Sürüm 6** için de uygulayın)
*   Ardından alt kısımda bulunan **DNS sunucu adresini otomatik olarak al** seçeneğini seçip **Tamam** butonuna tıklayın.
*   Bilgisayarınızı yeniden başlatın.

### ​

### macOS'ta Kaldırma​

macOS sürümünü kullanıyorsanız bu adımları izleyin:

- **Tek seferlik kullanım** (`turkey_dnsredir*.sh` ile çalıştırdıysanız):
  Çalışan terminal penceresinde **Ctrl-C** yapın. Script çıkışta SOCKS proxy
  ve DNS ayarlarını **otomatik olarak eski haline döndürür**. Ardından depo
  klasörünü silebilirsiniz.

- **Hizmet olarak kullanım** (`service_install_*.sh` çalıştırdıysanız):
  ```bash
  sudo ./macos/scripts/service_remove.sh
  ```
  Bu komut LaunchDaemon'ı (`/Library/LaunchDaemons/com.cagritaskn.goodbyedpi-turkey.plist`)
  kaldırır, durdurur ve SOCKS proxy + DNS ayarlarını kurulumdan önceki haline
  döndürür. Sonrasında depo klasörünü silebilirsiniz.

- **Elle kontrol etmek isterseniz**:
  ```bash
  # Hizmetin gerçekten kaldırıldığını doğrulayın
  sudo launchctl print system/com.cagritaskn.goodbyedpi-turkey   # "Could not find ..." dönerse kaldırılmıştır
  ls /Library/LaunchDaemons/com.cagritaskn.goodbyedpi-turkey.plist   # var olmamalı

  # Aktif servisteki SOCKS proxy + DNS'in beklediğiniz halde olduğunu doğrulayın
  networksetup -getsocksfirewallproxy "Wi-Fi"
  networksetup -getdnsservers          "Wi-Fi"

  # Eğer hâlâ açık görünüyorsa elle kapatın
  sudo networksetup -setsocksfirewallproxystate "Wi-Fi" off
  sudo networksetup -setdnsservers              "Wi-Fi" Empty
  ```

macOS'ta WinDivert benzeri bir kernel sürücüsü kurulmaz; geride yalnızca
sistem ağ ayarlarındaki SOCKS proxy ve (varsa) DNS atamaları kalır. Yukarıdaki
komutlar bu izleri tamamen temizler.

### WinDivert SYS Dosyaları Kullanımda Hatası​

Eğer ilgili dosyaları silmeye çalışırken **Dosya Kullanılıyor** hatası alırsanız bu, hizmeti doğru şekilde kaldırmadığınız anlamına gelmektedir.  
  
Dosyaları silmek için yukarıda bulunan _GoodbyeDPI-Turkey'i ve Dosyaları Tamamen Silmek_ isimli başlığı takip etmelisiniz. Bu hatayı aldığınızda gelen hata penceresinde bir BTC adresi bulunabilir. Bunun sebebi daha önce de açıklandığı ve güncel repository açıklamalarında da bulunduğu gibi şu şekildedir:  

> WinDivert açık kaynaklı bir Windows Paket İnceleme-Değiştirme aracı kütüphanesidir. Bu kütüphanenin sahibi [basil00](https://github.com/basil00) isminde bir geliştiricidir. Bu geliştirici tamamen ücretsiz ve açık kaynak kodlu şekilde bu kütüphaneyi [Github - Windivert](https://github.com/basil00/WinDivert) isimli Github repository'sinde paylaşmaktadır. Bu geliştirici tamamen ücretsiz şekilde yayınladığı bu kütüphaneden hiçbir gelir elde etmemekte ancak kendisine gelecek bağışları da kabul etmektedir. Bağış yapılacak adres ise .dll ve .sys dosyalarının açıklamalarında bulunuyor. Yani gördüğünüz Bitcoin yazısı ve yanındaki karmaşık sayılar ve harflerden oluşan adres WinDivert kütüphanesinin geliştiricisi olan basil00'a ait bağış yapabileceğiniz Bitcoin cüzdan adresidir. Bu adresi resmi sitesinde de paylaşıyor, [bu da bağış sayfasının linki](https://reqrypt.org/donate.html).

  
  
İnternet özgürlüğünden yana olduğumuzdan; zararlı olduğuna kesin bir şekilde ve somut deliller ile desteklenerek kanaat getirilmeden, insanın kişisel tehlike potansiyelini genele yayarak yapılan platform, site veya uygulama engellerini doğru bulmuyoruz.  
Gündemdeki yasağın kalkması haberinin ne kadar doğru olduğunu bilemesek de ihtiyacı olanlar için bu rehberi yayınlama gereği duydum. Eğer yasak kalkarsa bu süre zarfında yardımcımız olan GoodbyeDPI'a ve orijinal projenin geliştiricisi olan [ValdikSS](https://github.com/ValdikSS)'e teşekkürlerimi sunuyorum.  
\-Umarız ki- Güle güle GoodbyeDPI ![👋🏻](https://cdn.jsdelivr.net/joypixels/assets/8.0/png/unicode/64/1f44b-1f3fb.png "Waving hand: light skin tone    :wave_tone1:").  
  

![goodbyedpi-turkey.gif](https://www.technopat.net/sosyal/eklenti/goodbyedpi-turkey-gif.2423392/ "goodbyedpi-turkey.gif")
