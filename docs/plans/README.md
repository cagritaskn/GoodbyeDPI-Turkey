# Planlar (docs/plans)

Bu klasör, GoodbyeDPI-Turkey üzerinde yürütülen çok adımlı işlerin **plan + sonuç**
kayıtlarını tutar. Amaç: bir iş bittikten sonra "ne yapıldı, ne doğrulandı, ne
doğrulanamadı" sorusunun cevabını kod geçmişine bakmadan bulabilmek.

Dil: Türkçe (bkz. `AGENTS.md` → "Language split"). Dosya adları, komutlar ve
kod tanımlayıcıları İngilizce kalır.

## Dosyalar

| Dosya | Durum | Kapsam |
|---|---|---|
| [`2026-10-26-linux-sertlestirme.md`](2026-10-26-linux-sertlestirme.md) | **Tamamlandı** | Linux portu (byedpi/ciadpi) + güvenlik sertleştirmesi + gsettings/DNS/203-EXEC düzeltmeleri |
| [`2026-10-27-windows-guvenlik.md`](2026-10-27-windows-guvenlik.md) | **Onay bekliyor** | Windows tarafı güvenlik denetimi bulguları (W1–W13) ve CI-öncelikli düzeltme planı |

## Plan şablonu

Her görev (task) yedi alanı **zorunlu** taşır; spec bir kez oluşturulduktan sonra
değişmez (Orca `worker-start` her zaman saklanan spec'i enjekte eder):

```
Target:        dosya / bileşen / ortam
Change:        üretilecek somut sonuç
Constraints:   değişmezler, dokunulmayacak sınırlar, yasaklar
Ownership:     bu worker'ın düzenleyebileceği TAM dosya listesi
Acceptance:    tamamlanmayı kanıtlayan komut/çıktı
Reporting:     worker_done mesajının taşıması gereken kanıt
Stop:          ısrar etmek yerine sorup durma koşulu
```

Ek olarak her `pi` worker spec'inde şu üç kısıt bulunur:

```
- Alt ajan (subagent) açma, iç içe Orca run/task oluşturma, workflow tool'u çağırma.
- Her checkpoint'te heartbeat gönder (orca orchestration send --type heartbeat).
- Bloklayan sorularda `orca orchestration ask` kullan. `worker_done` mesajını tam bir kez gönder;
  payload'da taskId, dispatchId, outcome, filesModified ZORUNLU (taskId yoksa Orca reddeder).
```

## Doğrulama kapıları

Üç kapı vardır; bir sonraki kapıya ancak önceki yeşilse geçilir.

| Kapı | Nerede | Ne kanıtlar |
|---|---|---|
| **A — yerel statik** | Bu geliştirme makinesi (Linux) | `bash -n`, `make check`/`make test` (stub), CRLF kontrolü (`file`), `grep` tabanlı kural kontrolleri, `git diff --name-only` kapsam denetimi, YAML parse, `sha256sum` |
| **B — CI derleme** | GitHub Actions (`build.yml`; ubuntu + mingw-w64) | C/`.cmd` değişiklikleri sonrası `goodbyedpi.exe` (x86_64 + i686) derlemesi ve artifact üretimi. Buradan `gh workflow run build.yml` ile tetiklenir, `gh run watch`, `gh run download` ile izlenir |
| **C — gerçek donanım** | Kullanıcının Windows makinesi | `sc create`, `icacls`, WinDivert sürücüsünün yüklenmesi, gerçek DPI atlatma. Yalnız kullanıcı çalıştırır |

Kapı B kırmızıysa Kapı C'ye gidilmez. Kapı C'de çıkan sorun yeni bir plan turu açar.

## Yürütme biçimi

- Tek fan-out mekanizması **Orca orchestration**'dır; `workflow` tool'u ve iç içe
  subagent kullanılmaz.
- Eşzamanlı worker sınırı: 3 (projede ayrıca tanımlı değilse).
- Aynı dosyaya iki worker aynı anda dokunmaz: dalgalar dosya sahipliğine göre
  ayrılır; aynı dosyayı gerektiren görevler sıralı dalgalara konur.
- Paylaşılan worktree kuralı: `git add -A` / `git add .` yasak; yalnız açık yol
  eklenir ve commit pathspec ile atılır.
- Geri dönüşsüz iş (push, migration, deploy, silme) kullanıcı onayı olmadan
  dağıtılmaz.
