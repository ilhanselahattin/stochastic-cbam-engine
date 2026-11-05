# Mevzuat Doğrulama Kontrol Listesi

Kodun mevzuata dair **12 iddiası** ve her birinin doğrulama durumu.

**Son doğrulama: 2026-10-21** · Kaynak: bu klasördeki Rehber No. 1, 3 ve 4
(Avrupa Komisyonu, 14 Ağustos 2026 — kesin dönem için ilk yayın).

> **2026-10-21 notu.** D1–D8 listesi kodun *yaptığı* hesaplardan türetilmişti;
> bu yüzden kodun *hiç yapmadığı* bir kural (D9, mark-up) görünmedi. Liste
> bu tarihte rehberlerden yeniden türetildi; resmî Excel dosyaları motordan
> bağımsız bir okuyucuyla karşılaştırıldı. D9 ve D10 eklendi, D4 ve D5'te
> sınır hataları bulundu.

| # | İddia | Durum |
|---|---|---|
| D1 | Phase-in takvimi | ✅ **DOĞRULANDI — hata bulundu ve düzeltildi** |
| D2 | Sertifika hesabı formülü | ✅ **DOĞRULANDI — eksik terim eklendi** |
| D3 | Menşede ödenen karbon düşümü | ✅ **DOĞRULANDI — hata bulundu ve düzeltildi** (2026-10-21: simülasyona da uygulandı) |
| D4 | De minimis eşiği | ✅ **DOĞRULANDI — hata bulundu ve düzeltildi** (2026-10-21: tam 50 ton muaf) |
| D5 | 2026 öncesi mali yükümlülük yok | ✅ **2026-10-21: hata bulundu ve düzeltildi** |
| D6 | Dolaylı emisyon kapsamı | ✅ **DOĞRULANDI** |
| D7 | Benchmark değerleri | ✅ **DOĞRULANDI — 570 CN kodu, 1.804 değer resmî tablodan** |
| D8 | CN kodları | ✅ **DOĞRULANDI — resmî tablodan geldi** |
| **D9** | **Varsayılan değer mark-up'ı** | ✅ **2026-10-21: kodda YOKTU, eklendi** |
| **D10** | **Rota ve yıla bağlı benchmark seçimi** | ✅ **2026-10-21: kodda YOKTU, eklendi** |
| **D11** | **Ülke değeri yoksa "Other countries and territories"** | ✅ **2026-10-21: kodda YOKTU, eklendi** |
| **D12** | **AB ETS'ye bağlı ülkeler ve Ek III bölgeleri muaf** | ✅ **2026-10-21: eklendi** |

---

## ✅ D1 — Phase-in takvimi — **HATA BULUNDU, DÜZELTİLDİ**

**Kaynak:** Rehber No. 4, Tablo 2-1; Free Allocation Adjustment Act
(CIR (EU) 2025/2620); EU ETS Direktifi Madde 10a(1a).

**Bulgu — isim karışıklığı:** Mevzuatın *"CBAM factor"* dediği değer, ücretsiz
tahsisatın **hâlâ geçerli olan payıdır** — yükümlülük payı değil. Kodumuz
yükümlülük payıyla çalışıyordu, yani resmî değerin tümleyeniyle.

Resmî tablo (Tablo 2-1):

| Yıl | Resmî CBAM factor | Yükümlülük payı |
|---|---|---|
| 2025 | 100,0% | 0% |
| 2026 | 97,5% | 2,5% |
| 2027 | 95,0% | 5,0% |
| 2028 | 90,0% | 10,0% |
| 2029 | 77,5% | 22,5% |
| 2030 | 51,5% | 48,5% |
| **2031** | **39,0%** | **61,0%** |
| **2032** | **26,5%** | **73,5%** |
| **2033** | **14,0%** | **86,0%** |
| 2034 | 0,0% | 100% |

**Hata:** 2031, 2032 ve 2033 için kodda sırasıyla 61,5% / 74,5% / 86,5%
vardı. Doğrusu 61,0% / 73,5% / 86,0%. 2032'de 1 puanlık sapma, 250.000 tonluk
bir BF-BOF ihracatçısı için yılda yaklaşık 250.000 EUR'luk fark demekti.

**Düzeltme:** `cbam_factor_official()` resmî tabloyu aynen tutuyor;
`cbam_phase_in_factor()` artık `1 - cbam_factor_official()` olarak
türetiliyor. Tek doğruluk kaynağı var, iki tablonun birbirinden kayması
imkânsız. Test altında.

---

## ✅ D2 — Sertifika hesabı formülü — **DOĞRULANDI, EKSİK TERİM EKLENDİ**

**Kaynak:** Rehber No. 4, bölüm 2.2.1, Denklem (1) ve (2); Free Allocation
Adjustment Act Ek, nokta 2 ve 5.

Resmî formül:

```
Denklem (2):  SFA_Proc(g,y) = CBAM_y × CSCF_y × BM*_g
Denklem (1):  FAA_g        = SEFA_(g,y) × M_g

CBAM yükümlülüğü = gömülü emisyon − FAA − menşede ödenen karbon
```

| Değişken | Anlamı |
|---|---|
| `CBAM_y` | Resmî CBAM faktörü (ücretsiz tahsisat payı) — D1 tablosu |
| `CSCF_y` | Cross-sectoral correction factor, EU ETS Md. 10a(5) |
| `BM*_g` | CBAM benchmark'ı — Ek nokta 5, **Column A** |
| `M_g` | İthal edilen malın kütlesi |

**Doğrulanan:** Ücretsiz tahsisat gerçekten **benchmark üzerinden** hesaplanıp
gömülü emisyondan **düşülüyor**. Projenin ana bulgusu — *"benchmark üstü firma
2026'da bile ciddi yükümlülük altına girer"* — **geçerli.**

> Rehber No. 4, s.6: *"the free allocation adjustment which authorised CBAM
> declarants can **deduct from the embedded emissions** to determine the
> 'CBAM obligation'"*

**Eksik olan:** `CSCF_y` terimi kodda yoktu. 2026–2030 için değeri 1,0
(Commission Implementing Decision (EU) 2026/1862), dolayısıyla bugün sayısal
etkisi yok — ama 2031'den itibaren değişebilir ve o zaman motor sessizce
yanlış hesap yapardı. `certificates_due(cscf = )` olarak eklendi, `cbam_cscf()`
ile sağlanıyor.

**Column A / Column B ayrımı (not):** Column A tek üretim süreçleri, Column B
tüm üretim zincirleri için. Hesap makinesi tek süreç varsayıyor → **Column A**.

---

## ✅ D3 — Menşede ödenen karbon — **HATA BULUNDU, DÜZELTİLDİ**

**Kaynak:** Rehber No. 1, s.13–15; CBAM Tüzüğü Md. 6(2)(c), 7, 9 ve 31.

Resmî formülün tamamı:

```
CBAM Obligation_g = max[ 0 ; ( SEE_g − SEFA_g − SECPP_g / RP_CBAM ) ] × M_g
```

| Değişken | Anlamı |
|---|---|
| `SEE_g` | Gömülü emisyon yoğunluğu (Md. 7) |
| `SEFA_g` | Ücretsiz tahsisat yoğunluğu (Md. 31) |
| **`SECPP_g`** | **Menşede ödenen karbon FİYATI — mal tonu başına EUR** (Md. 9) |
| **`RP_CBAM`** | **CBAM sertifikası referans fiyatı, EUR/tCO2e** (Md. 21) |
| `M_g` | İthal edilen malın kütlesi |

**Hata:** Kod `carbon_paid_origin`'i doğrudan **tCO2e** olarak düşüyordu.
Doğrusu bir **fiyat** (EUR/ton mal) ve sertifika referans fiyatına bölünerek
tCO2e'ye çevriliyor. Birim tamamen yanlıştı.

**Düzeltme:** `certificates_due()` artık `carbon_price_paid` (EUR/ton mal) ve
`cbam_reference_price` (EUR/tCO2e) alıyor; ikincisi verilmezse hata veriyor.
CLI'de `--odenen-karbon-fiyati` ve `--sertifika-referans-fiyati`.

> **Türkiye ETS'i için önemli:** Ödenen tutar iade ve tazminatlar düşülmüş
> *etkin* fiyat olmalı ve Md. 9(2) uyarınca bağımsız bir kişi tarafından
> belgelenmeli. Bunun için ayrı bir rehber belge var.

---

## ✅ D4 — De minimis eşiği — **HATA BULUNDU, DÜZELTİLDİ**

**Kaynak:** CBAM Tüzüğü Md. 2a ve **Ek VII nokta 1**; Rehber No. 1, s.23.

> *"exempt from CBAM obligations if the **net mass of imported goods** in a
> given calendar year does not cumulatively exceed the single mass-based
> threshold... The current threshold is set at **50 tonnes of net mass**."*

**Hata:** Kod **50 tCO2e emisyon** karşılaştırıyordu. Doğrusu **50 ton net
kütle**. Birim yanlıştı.

Eşiğin üç kritik özelliği — ikisi kodda hiç yoktu:

| Özellik | Durum |
|---|---|
| Birim **net kütle** (ton), emisyon değil | ✅ düzeltildi |
| İthalatçı başına, **takvim yılı boyunca kümülatif** | ⚠️ araç tek miktar görür, çıktıda uyarıyor |
| **Tüm CN kodları toplamında** geçerli | ⚠️ aynı |
| Yıl içinde aşılırsa o yılın **tamamı** yükümlü hale gelir | ⚠️ çıktıda uyarılıyor |
| **Elektrik ve hidrojene uygulanmaz** | ✅ eklendi |

Araç tek bir miktar için hesap yaptığından ithalatçının yıllık toplamını
bilemez; çıktı bunu açıkça söylüyor.

**2026-10-21 — sınır hatası:** "does not exceed" → tam 50 ton **muaftır**.
Kod `< 50` kullanıyordu; `<= 50` olarak düzeltildi.

---

## ✅ D5 — 2026 öncesi mali yükümlülük yok

**Kaynak:** Rehber No. 3, s.8: geçiş dönemi (1 Ekim 2023 – 31 Aralık 2025)
"learning and data-collection phase"; kesin dönem 1 Ocak 2026'da başlıyor ve
mali yükümlülük o zaman doğuyor. Tablo 2-1'de 2025 için CBAM factor %100
(tahsisat tam) → yükümlülük payı 0.

**2026-10-21 — hata bulundu:** yükümlülük payı 0 olsa da formül, benchmark'ı
aşan emisyonu yine sertifikaya çeviriyordu; `--yil 2025` ile 100.000 t,
2 tCO2e/t için **5,04 milyon EUR** sahte maliyet çıkıyordu. Artık 2026 öncesi
yıl açık bir hata mesajıyla reddediliyor.

---

## ✅ D6 — Dolaylı emisyon kapsamı — **DOĞRULANDI**

**Kaynak:** Rehber No. 3, s.19–20; Methodology Act Madde 3(2).

> *"The indirect emissions are relevant for all goods that are listed in
> **Annex I but not in Annex II** to the CBAM Regulation. That means that
> indirect emissions are relevant for: Goods from the **cement sector**;
> Goods from the **fertiliser sector**; **Agglomerated iron ores and
> concentrates** ('sintered ore')."*

| Sektör | Dolaylı emisyon kapsamda mı? |
|---|---|
| Çimento | ✅ **Evet** |
| Gübre | ✅ **Evet** |
| Aglomere demir cevheri (sinter) | ✅ **Evet** |
| Demir-çelik (diğer) | ❌ Hayır (Ek II'de) |
| Alüminyum | ❌ Hayır (Ek II'de) |
| Hidrojen / kimyasallar | ❌ Hayır (Ek II'de) |

**Sonuç:** Alüminyum senaryosundaki **136 EUR/ton** rakamı geçerli, 608 değil.
Kodun `dolayli_kapsamda = hayir` varsayımı çelik ve alüminyum için doğruydu.
Çimento, gübre ve sinter satırları `evet` olarak düzeltildi.

**İnce nokta:** Sinterin dolaylı emisyonu, öncül (precursor) olarak
kullanıldığı için **demir-çelik ürünlerinde de** kalıntı olarak görünür —
karmaşık ürünün kendisi Ek II'de olsa bile. Modelde henüz yok.

### Yan bulgu — birim sorunu ⚠️

Rehber No. 3, s.20: çimento ve gübrede fonksiyonel birim **ton ürün değil**:
- **Çimento → ton klinker**
- **Gübre → kg azot**

Motorun `miktar (ton) × yoğunluk` modeli bu iki sektörde **yapısal olarak
yanlış** olurdu. `urunler.csv`'ye not düşüldü; değer girilmeden önce birim
alanı eklenmeli.

### Yan bulgu — gazlar

Rehber No. 3, s.21: CO₂ tüm sektörlerde; ayrıca **gübre için N₂O**,
**alüminyum için PFC**. Model şu an yalnızca CO₂e toplamıyla çalışıyor.

---

## ✅ D7 + D8 — Benchmark değerleri ve CN kodları — **DOĞRULANDI**

**Kaynak:** `CBAM-Benchmarks-20260206.xlsx` (bu klasörde), Free Allocation
Adjustment Act (CIR (EU) 2025/2620) Ek nokta 5'in Komisyon tarafından
yayımlanmış hâli.

**570 CN kodu** `data/benchmarks.csv`'ye aktarıldı; hepsi `dogrulandi`:

| Sektör | CN kodu sayısı |
|---|---|
| Demir & Çelik | 478 |
| Alüminyum | 58 |
| Gübre | 27 |
| Çimento | 6 |
| Hidrojen | 1 |

### Yer tutucu değerlerimiz yanlıştı

| Ne | Bizimki | Resmî |
|---|---|---|
| Birincil alüminyum (CN 76011090) | 1,484 | **1,423** |
| Sıcak haddelenmiş rulo (CN 72081000) | 1,288 | **1,370** (Column B) |
| İkincil alüminyum | 0,279 | **Böyle bir benchmark yok** |

### Yapısal bulgu — Column A / Column B

Benchmark **CN kodu başına** tanımlı, üretim rotası başına değil. İki sütun var:

| Sütun | Anlamı | Örnek (CN 72081000) |
|---|---|---|
| **A** | Tek üretim süreci | **0,044** — yalnızca haddeleme yapan tesis |
| **B** | Tüm üretim zinciri | **1,370** — cevherden üreten entegre tesis |

**Yanlış sütun 31 kat hata demektir.** Kaynak: Rehber No. 4 s.9, dipnot 7-8.

Bu, projenin uydurduğu "üretim rotası" taksonomisinin (EAF/BF-BOF) mevzuatın
modeliyle örtüşmediğini gösterdi. Model CN koduna geçirildi; kullanıcı
`--cn` ile gümrük beyanındaki kodu veriyor, benchmark resmî tablodan geliyor.

### Emisyon yoğunlukları ✅ çözüldü

**Önceki durum:** `urunler.csv`'de `varsayilan_yogunluk` diye bir sütun vardı
ve içindeki değerler **projenin kendi sektör tahminiydi** — mevzuattan
gelmiyordu. Çıktı bunu *"Yoğunluk: sektör tahmini"* diye işaretliyordu.

**Çözüm:** Sütun kaldırıldı, tahminler silindi. Yoğunluklar artık
`data/varsayilan_yogunluk.csv`'den geliyor: **283 CN kodu, Türkiye,
Default Values Act — CIR (EU) 2026/1740 (Sürüm 2, 06.08.2026).**

`urunler.csv` bugün yalnızca ürün kodu → CN kodu eşlemesi tutuyor.
**Projenin uydurduğu hiçbir sayı kalmadı.**

Kullanıcının kendi ölçtüğü değeri `--yogunluk` ile vermesi hâlâ önerilen
yoldur: resmî varsayılanlar mevzuat gereği ihtiyatlı (yüksek) seçilmiştir,
dolayısıyla gerçek tesis değeri genellikle daha düşük maliyet verir.

---

## ✅ D9 — Varsayılan değer mark-up'ı — **KODDA YOKTU, EKLENDİ (2026-10-21)**

**Kaynak:** Rehber No. 3, s.113–114 (Default Values Act, CIR (EU) 2025/2621);
Rehber No. 4, Tablo 2-4.

> *"The default values for CBAM goods shall be increased by a proportionately
> designed percentage 'mark-up' ... 10% in 2026, 20% in 2027, and 30% from
> 2028 onwards. A lower mark-up applies to the fertiliser sector. This
> mark-up is 1% from 2026 onwards."*

Komisyon'un XLSX dosyası **temel** değeri verir (sütunlar: direct / indirect /
total). Resmî Ek I'de mark-up'lı değerler ayrı sütunlardadır — Tablo 2-4
örneği: temel 3,000 → 3,300 / 3,600 / 3,900.

**Etki (Türkiye, 559 CN, 80 EUR/tCO2e):** v1.0.0 maliyeti medyan olarak
%16 (2026) – %35 (2028) düşük gösteriyordu. CN 72081000, 250.000 t, 2030:
34.449.000 → **49.017.000 EUR**.

**Bağımsız teyitler:** CarbonEmit'in CN 7208 için kullandığı 2,67 =
2,428 × 1,10; piyasada görülen amonyak değeri 2,293 = 2,270 × 1,01.
İkisi de daha önce "girdi farkı" ya da "tabloda yok" diye not edilmişti.

**Uygulama:** `cbam_default_markup()`, `cbam_default_see()`. Mark-up yalnızca
varsayılan değere uygulanır; kullanıcının ölçtüğü değere asla. Çıktıda ayrı
satırda gösterilir.

---

## ✅ D10 — Rota ve yıla bağlı benchmark — **KODDA YOKTU, EKLENDİ (2026-10-21)**

**Kaynak:** Rehber No. 4, Tablo 2-2, Tablo 2-3, Şekil 2-4 (s.13–21).

Resmî benchmark sayfası 1.810 satırdır; 570 CN kodunun **525'inde** birden
fazla değer vardır. Gösterge kodları:

| Kod | Anlam |
|---|---|
| (1) / (2) | Üretim yılı 2026–27 / 2028–30 |
| (A) / (B) | Gri / beyaz klinker-çimento |
| (C)(D)(E) | Karbon çeliği: BF/BOF, DRI/EAF, hurda/EAF |
| (F)(G)(H) | Düşük alaşımlı çelik: BF/BOF, DRI/EAF, hurda/EAF |
| (J) | Yüksek alaşımlı çelik (EAF) |
| (K) / (L) | Birincil / ikincil alüminyum |

Varsayılan değerle çalışılırken rota, Default Values Act Ek I'de ülke
sayfasının son sütunundan okunur (Türkiye: (C), (F), (C)/(F), (K)).

**v1.0.0'ın durumu:** her CN için tablonun yalnızca ilk satırı tutuluyordu.
Türkiye rotası ilk satırla örtüştüğünden 2026–27 tamamen doğruydu; 2028'den
itibaren **176 CN'de** 2026–27 değeri kullanılıyordu (etki medyan %0,3).

**Uygulama:** `data/benchmarks.csv` artık 1.804 değerin tamamını taşır;
`cbam_benchmark_by_cn(cn, sutun, yil, rota)` seçer. Rota belirlenemezse ilk
satır kullanılır ve çıktı alternatifleri listeler (`--rota` ile seçilir).
2031+ için resmî değer yoktur; 2028–30 değeri kullanılır ve not düşülür.

---

## ✅ D11 — Ülke değeri yoksa "Other countries and territories" — **KODDA YOKTU, EKLENDİ (2026-10-21)**

**Kaynak:** Rehber No. 3, s.113–114.

> *"Where the CBAM good is not explicitly listed for the country of production
> in Annex I or where it is listed but the relevant field shows a '-', CBAM
> declarants have to use the default values from the table 'Other countries
> and territories' in Annex I."*

Varsayılan değer XLSX'i 121 ülke sayfası, "Other Countries and Territories"
ve "Annex IV" (menşei bilinmeyen **öncüller** için en yüksek değerler) taşır.
v1.0.0 yalnızca Türkiye sayfasını kullanıyordu ve "-" görünce "değer yok"
diye duruyordu. Türkiye'de çimento satırlarının tamamı "-"dir.

**Uygulama:** `data/varsayilan_yogunluk.csv` 122 tablonun tamamını taşır
(11.670 satır; 760 "-" satırı **boş değerle** tutulur ki arama orada durup
"Other"a geçsin — daha genel bir önek satırına değil). Türkiye'nin değerli
250 satırı v1.0.0'daki elle aktarımla metin olarak birebir aynıdır. Annex IV
öncül modeline kadar kullanılmaz.

**Bağımsız teyit:** Rehber No. 4'te basılı Tablo 2-4 (Cezayir, CN 7318 15:
3,000 / N/A / 3,000 / (C)) ve Tablo 2-3 benchmark'ları motorla birebir aynı.

**Gözlem (hata değil):** 10.910 değerli satırın 710'unda yayımlanan toplam,
doğrudan + dolaylı toplamından ±0,01 farklıdır (Komisyon bileşenleri ayrı
yuvarlamış; çoğu gübre). Motor yayımlanan **toplam** değeri kullanır.

---

## ✅ D12 — Muaf menşeler — **EKLENDİ (2026-10-21)**

**Kaynak:** Rehber No. 1 dn.3; Rehber No. 4 dn.11 (Tüzük Ek III nokta 1).

AB ETS'yi uygulayan (İzlanda, Norveç, Lihtenştayn) ya da ona tam bağlı
(İsviçre) ülkeler ile Büsingen, Heligoland, Livigno, Ceuta, Melilla menşeli
mallar CBAM dışındadır. `--ulke` bunlardan biri olursa araç hesap yapmaz ve
nedenini söyler. Tüzük metni elde edilince Ek III listesi yeniden kontrol edilecek.

---

## Yapısal Not — Elektrik ✅ ayrı tutma kararı doğrulandı

**Kaynak:** Rehber No. 4, bölüm 2.2.1:

> *"No calculation is needed for determining the free allocation adjustment
> (FAA) for electrical energy (CN code 2716 00 00), as it is **zero** according
> to Article 1 of the Free Allocation Adjustment Act (electricity producers do
> not get free allocation in the EU ETS)."*

Elektrik için ücretsiz tahsisat **sıfır** — yani benchmark düşümü hiç yok ve
birim MWh. Motorun kalıbına oturmuyor. **Ayrı tutma kararı doğru çıktı.**
