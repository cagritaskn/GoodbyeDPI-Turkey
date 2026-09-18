Kaspersky Antivirüsü Hakkında Önemli Not (13.01.2025)

Kaspersky isimli antivirüs yazılımı Rus hükümetiyle olan anlaşmasından dolayı GoodbyeDPI'ın çalışmasına engel olmaktadır. Kaspersky isimli yazılımı kullanıyorsanız, kullandıysanız veya devre dışı halde bile olsa bilgisayarınızda bulunuyorsa lütfen tamamen kaldırın. Bunu yapmadığınız taktirde GoodbyeDPI çok yüksek ihtimalle çalışmayacaktır. Kaspersky yerine alternatif antivirüs yazılımları tercih edebilir ya da Windows Defender kullanabilirsiniz. (Windows Defender 2025 yılı itibariyle kötü amaçlı yazılım ve siteleri engellemekte son derece yeterlidir.) Kaspersky'i GoodbyeDPI ZIP dosyasının indirme işlemi sırasında devre dışı bırakmanız, indirdikten sonra dışlamalara eklemeniz veya devre dışı bırakmanız sorunu çözmeyecektir. GoodbyeDPI'ı doğru şekilde kullanabilmek için Kaspersky isimli antivirüs yazılımından bir şekilde kurtulmalısınız.


GoodbyeDPI — Derin Paket İnceleme (DPI) atlatma aracı (Türkiye versiyonu)
Bu uygulama, Türkiye'de bazı internet servis sağlayıcılarının DNS değişikliğine izin vermemesi sebebiyle, bu durumu bertaraf etmek için asıl proje olan GoodbyeDPI'ın düzenlenmiş bir versiyonudur. Bu yazılım, birçok ISS'da (İnternet Servis Sağlayıcısı) bulunan ve belirli web sitelerine erişimi engelleyen "Derin Paket İnceleme" (DPI) sistemlerini atlatmak için tasarlanmıştır. Optik ayırıcı veya port yansıtma (Pasif DPI) kullanarak bağlanan ve herhangi bir veriyi engellemeyen, ancak istenen hedeften daha hızlı yanıt veren DPI'yi ve sıralı olarak bağlanan Aktif DPI'yi işler. Bu uygulama kesinlikle bir VPN değildir ve oyunlarda/genel internet kullanımında bir hız değişikliğine sebep olmayacaktır.


Virüs & Veri Sızıntısı & Bitcoin Mining
Program açık kaynak kodlu olduğundan tüm kodu görüp inceleyebilirsiniz. Bazı kullanıcılar VirusTotal'de false positive bildirimi yapsa da bu WinDivert.dll ve WinDivert64.sys dosyalarının fonksiyonlarından dolayı bu şekilde yanlış bir sonuç verebiliyor (bu dosyalar sistemi etkiler). Bu .dll ve .sys dosyaları da açık kaynak kodludur ve incelenebilir, yani tamamen temizdir. İstemeyen ve güvenmeyen kullanıcılar kullanmak zorunda değildir, herkesin kendi seçimidir. Dilerseniz tüm klasörü ya da .zip dosyasını VirusTotal gibi bir sitede taratıp sonuçları inceleyebilirsiniz.


GoodbyeDPI'ı Kullanmak
GoodbyeDPI'ın Türkiye fork'unu kullanmak için iki yöntem bulunmaktadır.

Hizmet kurarak kullanma: Yalnızca bir kez hizmeti kurup ardından elle herhangi bir şey çalıştırmaya gerek kalmaksızın bilgisayarınız her yeniden başlatıldığında otomatik olarak çalışır.
Batch dosyası ile kullanma: batch dosyası ile kullanmada her defasında elle batch dosyasını başlatarak kullanmanız gerekir (batch penceresi kapatıldığında GoodbyeDPI kullanımına son verilir).
Note

İndirdiğiniz ZIP dosyasını çıkarttığınız konumdan taşımayın. Kurulacak hizmet .cmd dosyasını çalıştırdığınız dosya yolunu kullanacağından eğer dosyaları taşırsanız hizmet çalışmayacaktır. (Tavsiyem sizi rahatsız etmeyecek bir konuma ZIP dosyasını çıkarmanız ve dosyaları orada saklamanız. Örneğin, C:\GoodbyeDPI\.)

Hizmet Kurarak Kullanma (Windows başlatılırken otomatik olarak çalıştırılır)
GoodbyeDPI Türkiye versiyonunu hizmet kurarak kullanmak için:

goodbyedpi-0.2.3rc3-turkey.zip dosyasını bilgisayarınıza indirin.
ZIP dosyasını herhangi bir dizine çıkarın.
Çıkartılan dosyalardan service_install_dnsredir_turkey.cmd dosyasına sağ tıklayarak Yönetici Olarak Çalıştır seçeneğini seçin.
Açılan konsol penceresinde herhangi bir tuşuna basın.
Pencere, hizmet kurulduğunda otomatik olarak kapanacak ve hizmet de otomatik olarak başlayacaktır.
Note

Bu işlem bilgisayarınıza GoodbyeDPI hizmetini kuracaktır. GoodbyeDPI hizmetini bilgisayarınızdan kaldırmak için çıkarttığınız dosyalar içerisindeki service_remove.cmd dosyasını yönetici olarak çalıştırmanız gerekmektedir.

Batch Dosyası İle Kullanma (Tek seferlik, pencere kapatıldığında sona erecek şekilde)
GoodbyeDPI Türkiye fork'unu batch dosyasını çalıştırarak kullanmak için (Bir komut penceresi açılır ve uygulama çalışmaya başlar, bu pencere kapatıldığında çalışmaya son verilir) :

goodbyedpi-0.2.3rc3-turkey.zip dosyasını bilgisayarınıza indirin.
ZIP dosyasını herhangi bir dizine çıkarın.
Çıkartılan dosyalardan turkey_dnsredir.cmd dosyasına sağ tıklayarak Yönetici Olarak Çalıştır seçeneğini seçin.
Note

turkey_dnsredir.cmd dosyasını yönetici olarak çalıştırdığınızda GoodbyeDPI aktif olacaktır. Ancak bu yöntemle çalıştırıldığında hem bilgisayarınız yeniden başlatıldığında GoodbyeDPI'ı elle açmanız gerekecek, hem de turkey_dnsredir.cmd ile açılan pencere kapatıldığında GoodbyeDPI deaktive olacaktır.

Sık Karşılaşılan Sorunlar
WinDivert dosyaları bulunamadı hatası (Yalancı virüs algılaması): WinDivert dosyaları bulunamadı hatası alıyorsanız antivirüs programınıza ayıkladığınız klasörü dışlama/istisna olarak ekleyin. Windows Defender kullanıyorsanız buradaki rehberi (Kaspersky antivirüs programı için buradaki rehberi) takip ederek "goodbyedpi-0.2.3rc3-turkey" klasörünü dışlamalara ekleyebilirsiniz. Ancak dışlamalara eklemek sorununuzu çözmeyebilir. Bu durumda Kaspersky isimli programı sisteminizden tamamen kaldırıp ardından GoodbyeDPI-Turkey'in kurulumunu tekrar gerçekleştirmeniz gerekebilir.

Hizmetin başlatmaya çalışıldığında "Dosya yolu bulunamadı" hatası: Bu hata indirdiğiniz .zip klasörünü çıkardığınız konumdan farklı bir konuma taşımanız halinde ya da bazı dosyaları silmeniz halinde ortaya çıkar. Bu durumda goodbyedpi-0.2.3rc3-turkey.zip dosyasını tekrar bilgisayarınızda bir konuma çıkararak öncelikle service_remove.cmd dosyasını yönetici olarak çalıştırdıktan sonra seçeceğiniz diğer .cmd dosyasını tekrar çalıştırarak bu sorunu çözebilirsiniz.

Bazı sitelerin yavaş açılması/açılmaması sorunu: Bu sorunu komut dosyalarında TTL ayarı bulunan yöntemlerde yaşayabilirsiniz. Eğer belirli siteler yavaş açılıyor ya da hiç açılmıyorsa TTL ayarı içermeyen 2 ve 4 numaralı alternatif metodları kullanarak bu sorunu çözebilirsiniz. Eğer hali hazırda başka bir komut dosyası ile kurulum yaptıysanız öncelikle service_remove.cmd komut dosyasını yönetici olarak çalıştırıp ardından 2 veya 4 numaralı alternatif yöntemleri service_install_dnsredir_turkey_alternative2_superonline ya da service_install_dnsredir_turkey_alternative4_superonline isimli komut dosyalarını yönetici olarak çalıştırıp talimatları takip ederek kurmalısınız.

Discord'a web üzerinden giriş yapabilmeye rağmen uygulamanın açılmaması sorunu: Bu sorun genellikle fiber tarife kullanıcılarının karşılaştığı bir sorun ve maalesef kesin bir çözüm yolu yok. Ancak yine de bu çözüm yolunu deneyebilirsiniz: WinDivertTool.exe isimli WinDivert tanı aracını indirip çalıştırdıktan sonra konsol penceresinin en altında yer alan listede hangi uygulamaların WinDivert kullanarak çalıştığını görebilirsiniz. Bu listede birden fazla uygulama var ise ilgili satırlarda bulunan konuma giderek söz konusu uygulamayı veya uygulamaları siliniz. Yalnızca en son kurduğunuz konumdaki WinDivert kütüphanesini kullanan uygulamayı silmeyiniz. Ardından bilgisayarınızı yeniden başlatarak doğru şekilde çalışıp çalışmadığını deneyebilirsiniz.

Ethernet bağlantısı sorunu: İnternet bağlantınızı ethernet adaptörü aracılığı ile sağlıyorsanız ve GoodbyeDPI tüm çözümleri denemenize rağmen GoodbyeDPI'ı çalıştaramadıysanız harmanprecious isimli kullanıcıya ait çözüm rehberine bu adresten adresinden ulaşabilirsiniz.

DNS ve Port'u Düzenleme
Bu forktaki komut dosyalarında varsayılan olarak Yandex DNS kullanılmaktadır. Farklı bir DNS kullanmak için turkey_dnsredir.cmd ve service_install_dnsredir_turkey.cmd dosyalarını herhangi bir metin düzenleyici ile düzenleyerek DNS ve port bilgilerini değiştirebilirsiniz. Eğer alternatif metod 1, 2 veya 6'yı kullanacaksanız, Windows 10 için buradan, Windows 11 için buradan bakarak Windows ayarlarında DNS'inizi tercih ettiğiniz bir DNS adresine çevirin (Tavsiye edilen: Yandex DNS - 77.88.8.8/77.88.8.1 , Cloudflare DNS - 1.1.1.1/1.0.0.1). Eğer alternatif metod 3, 4 veya 5'i kullanacaksanız ayrıca DNS ayarlamanıza gerek yok, çünkü alternatif metod 3, 4 ve 5'te önayarlı olarak Yandex DNS kullanılmaktayken; 1, 2 ve 6 numaralı alternatif metodlarda önayarlı DNS bulunmamaktadır.

WinDivert.dll ve WinDivert64.sys Dosyalarını Silmek​
Eğer bu dosyaları silmeye çalıştığınızda dosya kullanımda hatası alırsanız, indirdiğiniz dosyalardaki service_remove.cmd dosyasını yönetici olarak çalıştırdıktan sonra silebilirsiniz.


SuperOnline Alternatif Yöntemler
Eğer SuperOnline Fiber kullanıyorsanız ve "Discord update failed - retrying in ** seconds" hatası alıyorsanız:

1- Alternatif CMD Dosyaları
Note

Daha önceden diğer bir servisi kurduysanız service_remove.cmd dosyası ile kurulmuş olan servisi kaldırıp ardından alternatif aşağıdaki işlemleri yapın.

Yukarıda anlatılan işlemleri turkey_dnsredir_alternative(1/2/3/4/5/6)_superonline.cmd komut dosyalarından biri ile veya service_install_dnsredir_turkey_alternative(1/2/3/4/5/6)_superonline.cmd komut dosyaları ile yapmayı deneyin (Sağ tık > Yönetici Olarak Çalıştır, daha sonra pencere açıldığında herhangi bir tuşa basın).
Bu işlemleri tamamladıktan sonra Windows 10 için buradan, Windows 11 için buradan bakarak Windows ayarlarında DNS'inizi tercih ettiğiniz bir DNS adresine çevirin. (Tavsiye edilen: Yandex DNS - 77.88.8.8/77.88.8.1 , Cloudflare DNS - 1.1.1.1/1.0.0.1)
Ardından bilgisayarınızı yeniden başlatın.
Bu şekilde de Discord update failed - retrying in ** seconds hatası alıyorsanız:

2- VPN ile Kaba Kuvvet
Yukarıda anlatılan işlemleri yaptıktan (Hizmeti kurduktan veya cmd dosyasını çalışır hale getirdikten) sonra, herhangi bir Windows VPN'i açıp discordu başlatın ve discordun açılmasını bekleyin. Discord açıldıktan sonra VPN'i kapatın ve Discordu kullanmaya devam edin.

Bunlara rağmen Superonline ile Discorda giriş yapamıyorsanız

3- GoodbyeDPI ile Benzer Programlar
SecureDNSClient veya Zapret isimli programları da deneyebilirsiniz. (Ben denemedim ve rehberlerini de bulamadım ufak bir araştırma ile bulabilirsiniz.)



Yasal Uyarı

Bu uygulamanın kullanımından doğan her türlü yasal sorumluluk kullanan kişiye aittir. Uygulama yalnızca eğitim ve araştırma amaçları ile yazılmış ve düzenlenmiş olup; bu uygulamayı bu şartlar altında kullanmak ya da kullanmamak kullanıcının kendi seçimidir. Açık kaynak kodlarının paylaşıldığı bu platformdaki düzenlenmiş bu proje, bilgi paylaşımı ve kodlama eğitimi amaçları ile yazılmış ve düzenlenmiştir.