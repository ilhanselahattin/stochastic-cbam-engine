# Değişiklik Günlüğü

Bu projede [semantik sürümleme](https://semver.org/lang/tr/) kullanılır.

---

## [1.1.0] — yayımlanmadı

**Önemli düzeltme: v1.0.0, varsayılan değerle yapılan hesaplarda CBAM
maliyetini düşük gösteriyordu.** Mevzuatın zorunlu kıldığı mark-up
uygulanmıyordu; Türkiye için sapma medyan %16 (2026) ile %35 (2028)
arasındaydı. Örnek: CN 72081000, 250.000 t, 2030 — **34.449.000 EUR değil,
49.017.000 EUR.** Kendi ölçtüğü yoğunlukla (`--yogunluk`) hesap yapan
kullanıcılar bu hatadan etkilenmedi.

Bulgular, resmî Excel dosyalarının motordan bağımsız bir okuyucuyla
karşılaştırıldığı ve beklenen değerlerin rehberlerden yeniden türetildiği bir
doğrulamadan (2026-10-21) geldi.

### Düzeltildi

| # | Hata | Düzeltme |
|---|---|---|
| **D9** | Varsayılan değere mark-up eklenmiyordu | %10 (2026), %20 (2027), %30 (2028+), gübre %1 — Rehber No. 3 s.113 |
| **D10** | Rota ve yıla bağlı benchmark'larda hep ilk değer kullanılıyordu (2028+ 176 CN) | 1.804 resmî değerin tamamı; ülke rotası ve yıla göre seçim; `--rota` |
| D5 | 2026 öncesi yıl için sahte maliyet gösteriliyordu | Açık hata mesajı |
| D3 | Menşede ödenen karbon belirsizlik simülasyonunda düşülmüyordu | Simülasyona aktarıldı |
| D4 | Tam 50 ton de minimis'ten muaf sayılmıyordu | `<= 50` |
| — | `--urun` yolu dolaylı emisyonu atlıyordu (sinter: `--cn` ile farklı sonuç) | İki yol tek fonksiyondan besleniyor (`cbam_default_see()`) |
| — | HTML raporda `--cn` yolunun resmî değerleri "kullanıcı girdisi" görünüyordu | Kaynak ve mark-up raporda gösteriliyor |
| **D11** | Ülke sayfasında değeri "-" olan ya da hiç olmayan mal için hesap duruyordu ("değer yok") | Kural gereği "Other countries and territories" tablosu kullanılıyor (Rehber No. 3 s.114). Örnek: Türkiye'de çimento |
| — | 8 haneli kod 10 haneli TARIC kodlarına ayrıldığında (beyaz/gri klinker) eşleşme yoktu | 10 haneli kod destekleniyor; 8 haneli kod birden fazla TARIC'e ayrılıyorsa seçenekler listeleniyor |
| — | Çıktılar yükümlülük payını "CBAM faktörü" diye yazıyordu (2030: %48,5) | Resmî CBAM faktörü (ücretsiz tahsisatın kalan payı, 2030: %51,5) ve yükümlülük payı ayrı ayrı yazılıyor (Rehber No. 4 Tablo 2-1) |
| — | HTML rapor de minimis muafiyetini açıklamıyordu; resmî tablolarla yapılan hesabı "DOĞRULANMADI" gösteriyordu; kur girilmeyince "1,00 TRY/EUR" yazıyordu | Muafiyet nedeni ve eşik aşılırsa yük gösteriliyor; doğrulama durumu ve kur doğru |
| — | `run_cbam_mc()` doğrudan çağrıldığında 2026 öncesi yılı kabul ediyordu; karbon fiyatı 0 ve ödenen karbonla simülasyon NaN üretiyordu | İkisi de giderildi |

### Eklendi

- **Tarayıcı hesaplayıcısı** (`hesaplayici.js`, `index.html`, `R/web.R`): sunucusuz, motorun kendi kodunu
  WebR ile çalıştırır; `<div data-cbam-hesaplayici>` ile başka sitelere gömülebilir. Yalnızca varsayılan değerler; kendi ölçüm değeri ve rota
  seçimi ileride eklenecek
- Komut satırında kendi değer girilip `--rota` verilmezse rota varsayımı uyarısı
- `cbam_default_markup()`, `cbam_default_see()`
- `cbam_benchmark_by_cn()` için `yil` ve `rota` parametreleri
- `--rota` komut satırı seçeneği
- **Tüm menşe ülkeler:** varsayılan değer tablosu Türkiye'den 121 ülke +
  "Other countries and territories"a genişledi (11.670 satır, aynı resmî
  dosyadan). `--ulke <ad>`, `--ulke diger`, `--ulkeler`
- AB ETS'ye bağlı ülkeler (İzlanda, Norveç, Lihtenştayn, İsviçre) ve Ek III
  bölgeleri için "CBAM uygulanmaz" mesajı
- `cimento-klinker` ürünü gri klinkerin TARIC koduna (2523100090) bağlandı
- Veri paketi etiketi `params-2026.10`
- **Rapor:** yıllara göre maliyet grafiği (2026–2034, her yıl o yılın mark-up'ı ve
  benchmark'ı), kendi ölçümüyle maliyet (başabaş) grafiği, her grafiğin altında
  tablo görünümü, "Varsayımlar" kutusu (girilmeyen her parametre listelenir),
  `--not` seçeneği. Rapor çevrimdışı kalır (betik ya da dış kaynak yok).
- `cbam_yillik_yol()`; varsayılan değer tablosu önbellekte (arama ~25 ms → 2 ms)
- 57 yeni test (toplam 234); Rehber No. 4'te basılı örnekler (Tablo 2-3, 2-4)
  test altında

---

## [1.0.0] — 2026-08-25

İlk kararlı sürüm. Çekirdek hesap resmî Avrupa Komisyonu kaynaklarından
doğrulandı ve her referans değer kaynağını taşıyor.

### Doğrulanan mevzuat iddiaları

Kaynak: Avrupa Komisyonu Rehber No. 3 ve No. 4 (14 Ağustos 2026),
CBAM Benchmarks tablosu (6 Şubat 2026). Belgeler `data-raw/mevzuat/` altında,
SHA256'larıyla birlikte.

| # | İddia | Sonuç |
|---|---|---|
| D1 | Phase-in takvimi | ✅ **Hata bulundu ve düzeltildi** — 2031/2032/2033 yanlıştı |
| D2 | Sertifika hesabı formülü | ✅ Doğrulandı; eksik CSCF terimi eklendi |
| D5 | 2026 öncesi mali yükümlülük yok | ✅ |
| D6 | Dolaylı emisyon kapsamı | ✅ Yalnızca çimento, gübre, sinter |
| D7 | Benchmark değerleri | ✅ 570 CN kodu, resmî tablodan |
| D8 | CN kodları | ✅ |
| D3 | Menşede ödenen karbonun birimi | ✅ **Hata bulundu ve düzeltildi** |
| D4 | De minimis eşiği | ✅ **Hata bulundu ve düzeltildi** |

**Sekiz iddianın sekizi de doğrulandı; dördünde hata bulundu ve düzeltildi.**

| Madde | Hata | Düzeltme |
|---|---|---|
| D1 | 2031/2032/2033 phase-in faktörleri yanlıştı | Resmî tablodan türetiliyor |
| D2 | CSCF terimi eksikti | Formüle eklendi |
| **D3** | Menşede ödenen karbon **tCO2e** olarak düşülüyordu | **Bir fiyattır** (EUR/ton mal); sertifika referans fiyatına bölünür |
| **D4** | De minimis **50 tCO2e emisyon** sanılıyordu | **50 ton net kütle**; elektrik ve hidrojene uygulanmaz |

Ayrıntı: `data-raw/mevzuat/MEVZUAT_DOGRULAMA.md`

### Referans veri — tamamı resmî

| Tablo | Kayıt | Kaynak |
|---|---|---|
| `data/benchmarks.csv` | 570 CN kodu | CBAM Benchmarks tablosu (06.02.2026) |
| `data/varsayilan_yogunluk.csv` | 283 CN kodu, Türkiye | Default Values Act — **CIR (EU) 2026/1740**, Sürüm 2 (06.08.2026); CIR (EU) 2025/2621'i revize eder |

`--cn` ve `--miktar` vermeniz yeterli: benchmark ve varsayılan emisyon
yoğunluğu resmî tablolardan otomatik gelir ve çıktıda kaynağıyla gösterilir.
**Hiçbir varsayılan değer projenin kendi tahmini değildir.**

> Varsayılan yoğunluklar mevzuatın öngördüğü değerlerdir ve bilerek yüksek
> seçilmişlerdir. Kendi ölçtüğünüz değeri `--yogunluk` ile verirseniz
> maliyetiniz büyük ihtimalle düşer.

### Özellikler

- **Hesap makinesi ve CLI** (`hesapla.R`) — CN kodunuzla hesap; benchmark resmî
  tablodan otomatik gelir
- **Şeffaf aritmetik** — her ara adım görünür, sonuç kâğıt üzerinde doğrulanabilir
- **Column A / B ayrımı** — tek üretim süreci vs tüm üretim zinciri
- **Belirsizlik dağılımı** — karbon fiyatı, döviz kuru ve tesis verimliliği
  birlikte oynatılır; tek tahmin yerine yüzdelikler ve VaR
- **Paylaşılabilir HTML rapor** (`--rapor`) — tek dosya, dışarıdan hiçbir kaynak
  yüklemez, künye gömülü
- **Değer başına provenans** — her sayının kaynağı çıktıda gösterilir
- **Doğrulama uyarısı** — doğrulanmamış değerler açıkça işaretlenir
- **Fonksiyonel birim uyarısı** — çimento ve gübrede birim ton ürün değildir
- **Reel/nominal ayrımı** — kur sürüklemesi enflasyon farkından türetilir,
  TRY üç ayrı sütunda raporlanır

### Kalite

- 177 test, 4 ortamda geçiyor (Linux, Windows, macOS, R 4.2)
- Sürekli entegrasyon: GitHub Actions
- **Sıfır çalışma zamanı bağımlılığı** — yalnızca R `base` ve `stats`; bu bir
  iddia değil, test edilen bir kural
- Canlı veri çekilmez, kullanıcı verisi hiçbir yere gönderilmez

### ⚠️ Bilinen sınırlar

- **Öncüller (precursors) modellenmiyor.** Araç ürünü tek üretim süreci sayar.
  Girdi satın alıyorsanız satın aldığınız malın gömülü emisyonu hesaba girmez.
  Cevherden kendi üreten entegre tesisler için geçerlidir.
- **Menşede ödenen karbon fiyatı elle verilmelidir.** `--odenen-karbon-fiyati`
  ve `--sertifika-referans-fiyati` birlikte kullanılır; araç Türkiye ETS
  fiyatını kendiliğinden bilmez.
- **Elektrik kapsam dışı** — ayrı hesap yolu gerektirir.
- **Varsayılan yoğunluklar tesisinizi temsil etmez.** Resmî tablodan gelirler
  ve mevzuat gereği yüksek seçilmişlerdir; kendi ölçtüğünüz değeri verin.
- **Uzak yıl belirsizlik kuyruğu güvenilmez** — karbon fiyatında ortalamaya
  dönüş modellenmiyor.
- **Bu bir beyan aracı değildir.** Çelişki halinde resmî mevzuat metni geçerlidir.

### Yol haritası

1. EUA vadeli fiyat eğrisi çapası
2. **Öncül zinciri** (2.0.0 hedefi)
3. Ortalamaya dönen karbon fiyatı süreci
4. Türkiye ETS düşümünün incelikleri
5. Tarayıcıda çalışan sürüm (WebR)

### Lisans

AGPL-3.0-or-later, AGPL §7(b) atıf ek şartıyla. Bkz. `LICENSE`,
`LICENSE-ADDITIONAL-TERMS.md`, `NOTICE`.
