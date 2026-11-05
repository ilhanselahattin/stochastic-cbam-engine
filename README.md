# Stochastic CBAM Engine

[![testler](https://github.com/ilhanselahattin/stochastic-cbam-engine/actions/workflows/test.yml/badge.svg)](https://github.com/ilhanselahattin/stochastic-cbam-engine/actions/workflows/test.yml)
[![lisans: AGPL v3](https://img.shields.io/badge/lisans-AGPL--3.0--or--later-blue.svg)](LICENSE)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.22116999.svg)](https://doi.org/10.5281/zenodo.22116999)

> Türk ihracatçılar için açık kaynaklı CBAM maliyet hesaplayıcısı.
> Her sayı kaynağını gösterir; tek tahmin yerine olasılık dağılımı verir.

**Proje iki parçadan oluşur:**

| Parça | Kimin için | Ne gerektirir |
|---|---|---|
| **Hesap makinesi** (`hesapla.R`, `R/`) | İhracatçı, üretici | Çarpma ve çıkarma |
| **Araştırma eki** (`research/`) | Akademisyen | Girdi-çıktı iktisadı |

Araştırma eki **isteğe bağlıdır** — hesap makinesi ona hiç dokunmaz, silinse
aynen çalışır. Çoğu kullanıcının ihtiyacı yalnızca ilk satırdır.

Araç, AB Sınırda Karbon Düzenleme Mekanizması'nın (SKDM) bir ihracatçıya
maliyetini hesaplar. Sektörel ortalamaya sıkışmak yerine firmanın kendi
emisyon yoğunluğuyla çalışır ve tek bir tahmin yerine karbon fiyatı ile kur
belirsizliğini de içeren bir dağılım verir.

## Proje Vizyonu ve Kapsamı

Piyasadaki kapalı kutu (black-box) danışmanlık araçlarının aksine, bu altyapı **açık bilim (open-science)** ve **tekrarlanabilirlik (reproducibility)** ilkeleriyle inşa edilmiştir.

* **Menşe:** AB varsayılan değer tablosundaki 121 ülkenin tamamı + menşei bilinmeyen/listede olmayan ülkeler için "Other countries and territories" (`--ulke`, liste için `--ulkeler`). Varsayılan: Türkiye.
* **Kapsam:** CBAM'in yürürlükteki tüm sektörleri — demir-çelik, alüminyum,
  çimento, gübre, hidrojen (570 CN kodu). Elektrik ayrı hesap yolu gerektirdiği
  için henüz kapsam dışı.
* **Referans veri:** Avrupa Komisyonu resmî tabloları — benchmark (Şubat 2026)
  ve varsayılan emisyon değerleri (Ağustos 2026)

## Hızlı Başlangıç

Kurulum istemeyen sade sürüm tarayıcıda çalışır:
<https://ilhanselahattin.github.io/stochastic-cbam-engine/>. Yalnızca AB'nin
varsayılan değerlerini kullanır; kendi ölçüm değeri ve üretim rotası seçimi
ileride eklenecek.

Komut satırı için gereksinim: **R ≥ 4.0**. Harici paket bağımlılığı yoktur — yalnızca `base` ve `stats` kullanılır.

### Hesap makinesi

Kendi rakamlarınızı girin, yıllık CBAM maliyetinizi hesaplayın:

CN kodunuz gümrük beyanınızda yazar; benchmark resmî AB tablosundan gelir:

```bash
Rscript hesapla.R --cn 72081000 --miktar 250000 \
                  --yil 2030 --karbon-fiyati 80 --kur 48
```

```
CN 72081000 | Flat-rolled products of iron or non-alloy steel...
Benchmark Column B (C) = 1,370 tCO2e/ton | Kaynak: CBAM-BENCHMARKS-2026-02-06
Varsayilan yogunluk = 2,428 tCO2e/ton (Turkiye, dogrudan)
  + 2030 mark-up'i %30  ->  3,156 tCO2e/ton hesapta kullanilir
  Kaynak: CBAM-DEFAULT-VALUES-2026-08-06, Turkiye sayfasi | CN 7208
  !! Bu mevzuatin VARSAYILAN degeridir, tesisinizin degeri degildir.

HESAP
  Gomulu emisyon        250.000 x 3,156          =       789.100 tCO2e
  Ucretsiz tahsisat     1,370 x 250.000 x 0,515  =      -176.388 tCO2e
                        (0,515 = resmi CBAM faktoru; yukumluluk payi 0,485)
  --------------------------------------------------------------------
  SERTIFIKA YUKUMLULUGU                          =       612.713 tCO2e
                                                   (emisyonun %77,6'i)

  CBAM MALIYETI         612.713 x 80,00 EUR      =    49.017.000 EUR
                        x 48,00 TRY/EUR          = 2.352.816.000 TRY
  Ton basina yuk                                 =        196,07 EUR/ton
```

**Hiçbir sayı bizim tahminimiz değil.** Benchmark Komisyon'un benchmark
tablosundan, emisyon yoğunluğu Default Values Act'ten, phase-in faktörü
Rehber No. 4'ten geliyor — hepsi çıktıda kaynağıyla gösteriliyor.

**Varsayılan değerler mevzuat gereği artırılır (mark-up):** 2026'da %10,
2027'de %20, 2028'den itibaren %30; gübrede %1 (Rehber No. 3, s.113). Araç
bunu otomatik uygular ve çıktıda ayrı satırda gösterir. Kendi ölçtüğünüz
değere mark-up uygulanmaz.

**Benchmark rota ve yıla göre seçilir.** 570 CN kodunun 525'inde resmî tabloda
birden fazla değer var (yüksek fırın / DRI / hurda-EAF, düşük alaşımlı çelik,
birincil / ikincil alüminyum, gri / beyaz klinker; 2026–27 ve 2028–30). Araç
ülkenin varsayılan rotasını kullanır; `--rota C|D|E|...` ile değiştirilebilir.

**Ülke sayfasında değer yoksa "Other countries and territories" kullanılır.**
Mal menşe ülkenin tablosunda hiç yoksa ya da değeri "-" ise mevzuat bu tabloyu
şart koşar (Rehber No. 3, s.114) — araç bunu otomatik yapar ve çıktıda söyler.
Örnek: Türkiye sayfasında çimento değerleri "-"dir; gri klinker için
`--cn 2523100090` "Other" değeri 1,410'u kullanır. AB ETS'ye bağlı ülkeler
(İzlanda, Norveç, Lihtenştayn, İsviçre) CBAM dışındadır; araç bunu da söyler.

`--sutun` benchmark sütununu seçer ve **fark büyüktür**:

| Sütun | Kime | CN 72081000 örneği |
|---|---|---|
| **B** (varsayılan) | Cevherden üreten entegre tesis | 1,370 tCO2e/ton |
| **A** | Yalnızca son işlemi yapan tesis | 0,044 tCO2e/ton |

Her ara adım görünür — sonucu kâğıt üzerinde doğrulayabilirsiniz. Kapalı kutu
araçlardan ayrışan nokta budur.

Kendi tesis verinizle:

```bash
Rscript hesapla.R --cn 72081000 --yogunluk 1.72 --miktar 120000 \
                  --yil 2030 --karbon-fiyati 85 --kur 48

Rscript hesapla.R --urunler       # hazır ürün tanımları ve CN kodları
Rscript hesapla.R --yardim        # tüm seçenekler
```

### Paylaşılabilir rapor

```bash
Rscript hesapla.R --cn 72081000 --yogunluk 1.95 --miktar 250000 --yil 2030 \
                  --firma "Örnek Çelik A.Ş." --rapor cikti/rapor.html
```

Tek bir HTML dosyası üretir (~10 KB): yönetici özeti, şeffaf hesap tablosu,
dağılım grafiği, yüzdelikler ve tam provenans bloğu. Tarayıcıda açılır,
PDF olarak yazdırılır, e-postayla gönderilir.

**Dışarıdan hiçbir şey yüklemez** — internet olmadan açılır, hiçbir sunucuya
istek gitmez. Bu test altındadır: alıcının verisi hiçbir yere ulaşmaz.

`--urun` ile referans değerler otomatik gelir; üstüne `--yogunluk` verirseniz
kendi tesis veriniz referans değerin yerine geçer.

## Bilinen Sınırlar

Bu araç neyi bilmediğini söyler. Bir sonuca güvenmeden önce şunlara bakın:

| Sınır | Etkisi |
|---|---|
| **Öncüller (precursors) modellenmiyor** | Araç ürünü **tek üretim süreci** sayar. Girdi (slab, kütük, öncül) satın alıyorsanız, satın aldığınız malın gömülü emisyonu hesaba **girmez** ve sonuç eksik çıkar. Cevherden kendi üreten entegre tesisler için geçerlidir. |

| **De minimis kümülatif eşiktir** | 50 tonu aşmayan net kütle muaftır; eşik ithalatçı başına ve **tüm CN kodları toplamında** yıllıktır. Araç tek bir miktar görür; yıllık toplamınızı siz takip etmelisiniz. |
| **2031 sonrası benchmark** | Resmî tabloda yıla bağlı benchmark'lar yalnızca 2030'a kadar yayımlandı. 2031+ için 2028–30 değeri kullanılır ve çıktıda not düşülür. |
| **Elektrik kapsam dışı** | Ücretsiz tahsisatı sıfır, birimi MWh; ayrı bir hesap yolu gerektirir. |
| **Varsayılan yoğunluklar tesisinize ait değildir** | Default Values Act'ten gelen resmî değerlerdir, bilerek **yüksek** seçilmişlerdir ve üstüne yıla göre %10–30 mark-up eklenir. **Kendi ölçtüğünüz değeri `--yogunluk` ile verin** — mark-up uygulanmaz, maliyetiniz büyük ihtimalle düşer. |
| **Uzak yıl belirsizlik kuyruğu** | Karbon fiyatı Geometrik Brown Hareketi ile modellenir; ortalamaya dönüş ve AB Piyasa İstikrar Rezervi yoktur. Uzak yıllarda %95 üst sınırı gerçekçi olmayan fiyatlara uzanır. Bütçe için medyanı ve yakın yılları kullanın. |
| **Çimento ve gübrede birim farklı** | Ton ürün değil: çimento *ton klinker*, gübre *kg azot*. Araç uyarı basar ama dönüşümü sizin yapmanız gerekir. |

**Bu bir beyan aracı değildir.** CBAM raporu/beyanı üretmez; maruziyet hesabı ve
karar desteği için tasarlanmıştır. Çelişki halinde resmî mevzuat metni geçerlidir.

Doğrulama durumunun tamamı: [`data-raw/mevzuat/MEVZUAT_DOGRULAMA.md`](data-raw/mevzuat/MEVZUAT_DOGRULAMA.md)

## Kaynak Şeffaflığı

Hesabın kullandığı her referans değer **kaynağını taşır** ve çıktıda gösterilir:

```
CN 72081000 | Flat-rolled products of iron or non-alloy steel...
Benchmark Column B (C) = 1,370 tCO2e/ton
Kaynak: CBAM-BENCHMARKS-2026-02-06, CN 72081000, Column B (C)
```

İki referans tablosu da resmî ve doğrulanmış durumda:

| Tablo | Kayıt | Kaynak |
|---|---|---|
| `data/benchmarks.csv` | 570 CN kodu, 1.804 değer (rota ve yıl ayrımıyla) | CBAM Benchmarks tablosu (06.02.2026) |
| `data/varsayilan_yogunluk.csv` | 121 ülke + Other, 11.670 satır | Default Values Act — **CIR (EU) 2026/1740** (Sürüm 2, 06.08.2026) |

> **Sürüm önemlidir.** Varsayılan emisyon değerleri CIR (EU) 2025/2621 ile
> yayımlandı, **CIR (EU) 2026/1740** ile revize edildi. Araç Sürüm 2'yi
> kullanır ve her çıktıda hangi belgeden geldiğini yazar. Kaynak dosya
> SHA256'sıyla birlikte `data-raw/mevzuat/` altındadır.

Resmî AB belgeleri `data-raw/mevzuat/` altında **değiştirilmemiş halde** depoda
durur, SHA256'larıyla birlikte. `data/` altındaki CSV tabloları bunlardan
aktarılmıştır ve her satır `kaynak_belge` + `kaynak_yeri` sütunlarıyla belgeye
geri bağlanır.

Bir değerin kaynağı yoksa araç bunu **çıktıda açıkça söyler** ve hesabı
sessizce sürdürmez:

```
!! DIKKAT: Bu hesapta DOGRULANMAMIS deger kullanildi.
```

> Bu kural test altındadır: `durum=dogrulandi` diyen her satırın
> `kaynak_belge` alanı dolu olmak **zorundadır**.

> Referans veri paketi sürümlenir (`data/VERSION`) ve her çıktıda basılır.
> Araç canlı veri çekmez — bu bir kısıt değil, tekrarlanabilirlik koşuludur:
> canlı API'den beslenen bir analiz tekrarlanamaz.

Belgelerin telif durumu koddan ayrıdır: kod AGPLv3, AB belgeleri Komisyon'un
yeniden kullanım koşullarına tabidir. Ayrıntı: `data-raw/mevzuat/KAYNAKLAR.md`.

### R içinden

```r
# Proje kökünden
source("load_all.R")

hesap <- cbam_estimate(
  quantity     = 250000,   # ton/yıl AB'ye ihracat
  ei_direct    = 1.95,     # tCO2e/ton (doğrudan emisyon)
  benchmark    = 1.370,    # CN 72081000, Column B (resmî tablodan)
  year         = 2030,
  carbon_price = 80,       # EUR/tCO2e
  fx_rate      = 48        # TRY/EUR
)
print(hesap)
```

Simülasyon motoruna doğrudan erişim:

```r
sim <- run_cbam_mc(
  n_sims         = 50000,
  quantity       = 250000,   # ton/yıl AB'ye ihracat
  ei_sector      = 1.95,     # tCO2e/ton (doğrudan emisyon)
  theta_sdlog    = 0.20,     # firma teknoloji heterojenliği
  benchmark      = 1.370,    # CN 72081000, Column B (resmî tablodan)
  year           = 2030,
  carbon_price_0 = 80,       # EUR/tCO2e
  fx_0           = 48,       # TRY/EUR
  seed           = 2026
)

print(sim)
risk_summary(sim)
cbam_var(sim, level = 0.95)
```

Test ve demo:

```bash
Rscript tests/test_engine.R                   # 234 test
Rscript analysis/01_demo_turkiye_celik.R      # EAF vs BF-BOF senaryo demosu
```

## Metodolojik Çerçeve

Proje, yasal olarak vergilendirilen emisyonlar ($E_{CBAM}$) ile tedarik zincirindeki toplam emisyonları ($E_{MRIO}$) birbirinden ayırır. Sektörel makro Girdi-Çıktı matrisleri, firma düzeyindeki heterojen teknoloji katsayıları ile esnetilir:

$$ EI_f = EI_s \times \theta_f $$

*(Burada $EI_f$ firmanın spesifik emisyon yoğunluğunu, $EI_s$ sektör ortalamasını ve $\theta_f$ teknoloji ayarlama katsayısını temsil eder.)*

`theta_f` firma düzeyi veri yokluğunda lognormal dağılımdan örneklenir — emisyon yoğunluğu pozitif tanımlı ve sağa çarpıktır (az sayıda çok kirli tesis, çok sayıda ortalamaya yakın tesis).

### Yükümlülük hesabı

İthalatçı, AB üreticisinin hâlâ aldığı ücretsiz tahsisat kadar muaftır; bu muafiyet CBAM faktörü arttıkça erir:

```
sertifika = gömülü_emisyon − benchmark × miktar × CBAM_faktörü × CSCF − menşede_ödenen
```

Kaynak: Free Allocation Adjustment Act (CIR (EU) 2025/2620), Ek nokta 2 ve 5;
Rehber No. 4, Denklem (1)–(2).

> **İsim karışıklığına dikkat.** Mevzuatın *"CBAM factor"* dediği değer,
> ücretsiz tahsisatın **hâlâ geçerli olan payıdır** — 2026'da %97,5, 2034'te %0.
> Kodda `cbam_phase_in_factor()` bunun tümleyenini, yani **yükümlülük payını**
> döndürür (2026'da %2,5, 2034'te %100). Tek doğruluk kaynağı
> `cbam_factor_official()`; diğeri ondan türetilir.
>
> `CSCF` (cross-sectoral correction factor, AB ETS Md. 10a(5)) 2026–2030 için
> 1,0'dır; formülde yer alması, değer değiştiğinde motorun sessizce yanlış
> hesap yapmaması içindir.

> **Metodolojik not.** Ücretsiz tahsisat *benchmark üzerinden* düşüldüğü için, benchmark'ın belirgin şekilde üstünde emisyon yoğunluğuna sahip bir firma 2026'da bile ciddi yükümlülük altına girer. "2026'da yalnızca %2,5 ödenir" ifadesi yalnızca benchmark'taki ortalama üretici için geçerlidir. Bu, modelin en politika-ilgili çıktılarından biridir.

### Belirsizlik ve Risk Modellemesi

Sistem deterministik tek bir sonuç vermek yerine, Monte Carlo simülasyonları kullanarak;

* EU ETS karbon fiyatı volatilitesini,
* Döviz kuru dalgalanmalarını

Geometrik Brown Hareketi ile modeller. İki süreç Cholesky ayrışımıyla korele edilir (`rho`) — enerji fiyatı şokları her ikisini de aynı yönde etkileyebilir. Çıktı, **%90 güven aralığında** risk olasılık dağılımı ve VaR'dır.

## Proje Yapısı

```
R/
  emissions.R     EI_f = EI_s × theta_f, gömülü emisyon, theta örnekleme
  cbam.R          Phase-in takvimi, sertifika yükümlülüğü, maliyet, de minimis
  stochastic.R    GBM, korele şoklar, piyasa simülasyonu
  monte_carlo.R   Simülasyon motoru, risk özeti, VaR
  reference.R     Referans veri okuyucu, kaynak izleme, doğrulama uyarısı
  calculator.R    Kullanıcı girdisi → okunabilir tek cevap (hesap makinesi)
  report.R        Paylaşılabilir HTML rapor (bağımlılıksız, tek dosya)
  web.R           Tarayıcı hesaplayıcısının (hesaplayici.js) R girişi
  utils.R         Sayı/aralık formatlama
hesapla.R         Komut satırı hesap makinesi (--yardim, --urunler, --rapor)
research/         ARAŞTIRMA EKİ — hesap makinesi buraya hiç dokunmaz
  mrio.R          Leontief tersi, E_CBAM/E_MRIO kapsam farkı
data/             İşlenmiş referans veri (CSV, her satır kaynağıyla)
  urunler.csv     Ürün kataloğu → CN kodu eşlemesi
  varsayilan_yogunluk.csv  Default Values Act, 121 ülke + Other countries
  benchmarks.csv  AB ETS ürün benchmark'ları
  VERSION         Veri paketi sürümü
data-raw/
  mevzuat/        Resmî AB belgeleri — değiştirilmemiş, versiyonlanır
  exiobase/       Büyük MRIO matrisleri (versiyonlanmaz)
  firma/          Firma düzeyi veri (versiyonlanmaz)
tests/
  test_engine.R   234 test (base R, harici test paketi gerektirmez)
LICENSE                        AGPL-3.0 tam metni
LICENSE-ADDITIONAL-TERMS.md    Atıf ek şartı (AGPL §7(b)) + marka notu
NOTICE                         Telif, atıf ve veri kaynağı bildirimleri
CONTRIBUTING.md                Katkı rehberi + DCO
CITATION.cff                   Akademik atıf künyesi
analysis/
  01_demo_turkiye_celik.R   EAF vs BF-BOF, 2026/2030/2034 senaryoları
load_all.R        Bağımlılıksız modül yükleyici
```

Katmanlar ayrıdır: `R/` altındaki motor saf hesap yapar ve hiçbir yere yazmaz;
`calculator.R` ve `hesapla.R` yalnızca sunum katmanıdır.

## Yol Haritası

- [x] Çekirdek emisyon ve CBAM yükümlülük motoru
- [x] Monte Carlo belirsizlik katmanı (karbon fiyatı + kur, korele)
- [x] MRIO temel fonksiyonları (Leontief tersi, toplam yoğunluk)
- [x] Test altyapısı ve çalıştırılabilir demo
- [x] Hesap makinesi ve komut satırı arayüzü (`hesapla.R`)
- [x] Referans veri katmanı, kaynak izleme ve doğrulama uyarısı
- [x] Paylaşılabilir HTML rapor (`--rapor`)

- [x] Sürekli entegrasyon (GitHub Actions) — 3 işletim sistemi, R 4.2 ve güncel
- [x] Reel/nominal ayrımı — kur sürüklemesi enflasyon farkından türetiliyor
- [x] Resmî AB belgelerinden doğrulama — 12 mevzuat iddiası ([`MEVZUAT_DOGRULAMA.md`](data-raw/mevzuat/MEVZUAT_DOGRULAMA.md))
- [x] Resmî benchmark tablosunun tamamı — 570 CN kodu, 1.804 değer, rota ve yıl ayrımıyla
- [x] Resmî varsayılan değerler — 121 ülke + "Other countries and territories", mark-up dahil
- [x] Beş sektör: demir-çelik, alüminyum, çimento, gübre, hidrojen
- [x] Grafikli rapor: yıllara göre maliyet, başabaş (kendi ölçümüyle maliyet), belirsizlik

### Aşama 1 — AB hesaplama kurallarına tam uyum (proje tanımı)

Proje, AB'nin hesaplama kurallarının **tamamını**, resmî kaynakla doğrulanmış
olarak uyguladığında tamamlanmış sayılır. Kalanlar:

- [ ] **Öncül zinciri (karmaşık mallar)** — gömülü emisyon SEE = (AttrEm + Σ Mᵢ·SEEᵢ) / AL
      (Rehber No. 3 §4.2.2.3), ücretsiz tahsisat SEFA = SFA + Σ mᵢ·SEFAᵢ (Rehber No. 4
      Denklem 4); AB menşeli öncülün SEFA'sı sıfır; tedarikçi ağırlıklı ortalaması;
      menşei bilinmeyen öncül için Ek IV; gerçek veride Column A
- [ ] **Fonksiyonel birim dönüşümü** — gübrede kg N, çimentoda ton klinker
      (Rehber No. 3 §4.9.1.1)
- [ ] **Karışık çimento (2523 90)** — beyaz/gri bileşime göre ağırlıklı benchmark (Rehber No. 4 s.14)
- [ ] **Sertifika fiyatı kuralı** — CIR (EU) 2025/2548 *(yasal metin bekleniyor)*
- [ ] **Şebeke elektriği emisyon faktörü** — Default Values Act Ek II *(yasal metin bekleniyor)*
- [ ] **Elektrik** — ayrı hesap yolu (MWh, ücretsiz tahsisat yok; Rehber No. 5f, DV Act Ek III)
- [ ] **Bağlayıcı yasal metinlerle son doğrulama** — Tüzük 2023/956 (konsolide), CIR 2025/2547,
      2025/2620, 2025/2621 + 2026/1740, 2025/2548. Bugüne kadarki doğrulama Komisyon
      rehberlerine dayanır; rehberler bağlayıcı değildir.

### Aşama 2 — araştırma katmanları (Aşama 1'den sonra)

AB uyumunun parçası değildir; aracı akademik ve karar destek amaçlı genişletir.

- [ ] **MRIO entegrasyonu ve EXIOBASE/WIOD veri katmanı** — firma düzeyinden ekonomi
      düzeyine: CBAM yükünün tedarik zincirine yayılımı (temel fonksiyonlar `research/mrio.R`)
- [ ] **Sobol duyarlılık indeksleri** — belirsizliğin hangi girdiden geldiği
- [ ] **Dekarbonizasyon yatırım modülü** — azaltım yatırımı vs. kümülatif CBAM maliyeti (NPV)

## Atıf

Araç [Zenodo'da arşivlenmiştir](https://doi.org/10.5281/zenodo.22116999).
Arşiv kalıcıdır: depo taşınsa ya da silinse bile DOI çözülmeye devam eder.

```
İlhan, S. (2026). stochastic-cbam-engine: A Stochastic Framework for Carbon
Border Adjustment Mechanism Exposure Analysis (Sürüm 1.0.0) [Yazılım].
Zenodo. https://doi.org/10.5281/zenodo.22117000
```

```bibtex
@software{ilhan_stochastic_cbam_2026,
  author    = {İlhan, Selahattin},
  title     = {stochastic-cbam-engine: A Stochastic Framework for Carbon
               Border Adjustment Mechanism Exposure Analysis},
  version   = {1.0.0},
  year      = {2026},
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.22117000},
  url       = {https://doi.org/10.5281/zenodo.22117000},
  orcid     = {0009-0007-4824-752X}
}
```

**Hangi DOI'yi kullanmalı:**

| DOI | Ne zaman |
|---|---|
| `10.5281/zenodo.22117000` | Tam olarak **1.0.0**'ı kullandıysanız — yeniden üretilebilirlik için doğru olan budur |
| `10.5281/zenodo.22116999` | Sürümden bağımsız olarak **projeye** atıf veriyorsanız; her zaman en son sürüme çözülür |

Künye [`CITATION.cff`](CITATION.cff) dosyasında da makine tarafından
okunabilir biçimde durur — GitHub'daki **"Cite this repository"** düğmesi
bunu kullanır.

## Lisans ve Katkı

**AGPL-3.0-or-later** ([`LICENSE`](LICENSE)) + atıf ek şartı
([`LICENSE-ADDITIONAL-TERMS.md`](LICENSE-ADDITIONAL-TERMS.md)).

Copyright © 2026 Selahattin İlhan · ORCID
[0009-0007-4824-752X](https://orcid.org/0009-0007-4824-752X)

| | |
|---|---|
| Yerel kullanım (kendi bilgisayarında) | Serbest, hiçbir yükümlülük yok |
| Akademik araştırma | Serbest — [`CITATION.cff`](CITATION.cff) ile atıf verin |
| Değiştirip dağıtma | Değişiklikleriniz de AGPL ile açık olmalı |
| Web sitesinde/serviste sunma | Kullanıcılarınıza kaynak kodu sunmalısınız (AGPL §13) |

**Atıf ek şartı (AGPL §7(b)):** Yeniden dağıtırsanız kaynak dosyalardaki telif
başlıklarını, [`NOTICE`](NOTICE) dosyasını ve **araç çıktısındaki künyeyi**
korumak zorundasınız. Kendi adınızı ekleyebilirsiniz; mevcut olanı
kaldıramazsınız. Lisans projenin **adını** kullanma hakkı vermez.

**Katkı:** [`CONTRIBUTING.md`](CONTRIBUTING.md). CLA yok — sadece
`git commit -s` ile DCO imzası. Telif hakkınız sizde kalır.

**Ticari lisans:** AGPL koşulları senaryonuza uymuyorsa farklı koşullarla
lisanslama için iletişime geçebilirsiniz.

## Uyarı

`analysis/` altındaki parametreler gösterim amaçlı varsayımlardır, gerçek firma verisi değildir. Üretim analizi için kendi verinizi `data-raw/` altına yerleştirin.
