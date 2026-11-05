// stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Bu dosya GNU Affero General Public License v3 (ya da sonraki bir surum)
// kosullariyla dagitilir; HICBIR GARANTI VERILMEZ. Ayrintilar: LICENSE
// EK SART (AGPL 7(b)): yazar atiflari ve telif bildirimleri korunmalidir.
// Bkz. NOTICE ve LICENSE-ADDITIONAL-TERMS.md
//
// Gomulebilir CBAM hesaplayicisi. Kullanim (herhangi bir sayfada):
//
//   <div data-cbam-hesaplayici></div>            Turkce
//   <div data-cbam-hesaplayici lang="en"></div>  Ingilizce
//   <script type="module" src="hesaplayici.js"></script>
//
// Disaridan hicbir sey yuklenmez: hesap cbam-motor.js ile tarayicida yapilir,
// veri bu betigin yanindaki data/web/ klasorunden okunur (tools/web_veri.R).
// Girilen bilgiler tarayicida kalir, hicbir yere gonderilmez.
//
// Gorunum dayatilmaz: tum parcalar cbam- onekli sinif tasir ve asagidaki
// yerlesim kurallari :where() ile sifir oncelikli eklenir; sayfanin kendi
// CSS'i her zaman ustun gelir. Renkler --cbam-* degiskenleriyle verilebilir.

import { motorOlustur, CbamHata } from "./cbam-motor.js";

const TABAN = new URL(".", import.meta.url);
const VERI = new URL("data/web/", TABAN);
const KUNYE = {
  ad: "stochastic-cbam-engine", yazar: "Selahattin İlhan", orcid: "0009-0007-4824-752X",
  lisans: "AGPL-3.0-or-later", kaynak: "https://github.com/ilhanselahattin/stochastic-cbam-engine",
};

// ------------------------------------------------------------------- metinler
const METIN = {
  tr: {
    sayi: "tr-TR", yz: (x) => "%" + x, birim: "Birim",
    cn: "CN kodu", cnIpucu: "8 ya da 10 hane. Yazmaya başlayınca öneriler çıkar.",
    miktar: "Miktar (ton / yıl)", miktarIpucu: "AB'ye yıllık ihracat, ton ürün.",
    yil: "Yıl", ulke: "Menşe ülke", fiyat: "Karbon fiyatı (EUR / tCO2e)",
    fiyatIpucu: "Varsayımdır, tahmin değildir.", kur: "Kur (TRY / EUR)",
    kurIpucu: "İsteğe bağlı. Boş bırakılırsa yalnızca EUR gösterilir.",
    hesapla: "Hesapla", baslat: "Hesaplayıcıyı başlat", yukleniyor: "Veriler yükleniyor…",
    hesaplaniyor: "Hesaplanıyor…", hazir: "Hesap tamamlandı. Sonuç aşağıda.",
    turkiye: "Türkiye", diger: "Bilinmiyor / listede yok",
    hCn: "CN kodu 4 ile 10 hane arasında olmalı (yalnızca rakam).",
    hMiktar: "Miktar sıfırdan büyük olmalı.", hFiyat: "Karbon fiyatı girin (0 ya da daha büyük).",
    hKur: "Kur sıfırdan büyük olmalı ya da boş bırakılmalı.",
    hForm: "Formda düzeltilmesi gereken alanlar var.",
    deMinimisBilgi: "De minimis eşiği 50 tondur. Eşik ithalatçı başına, yıllık ve tüm CN kodlarının toplamında uygulanır.",
    hYukleme: "Hesaplayıcı verileri yüklenemedi. Sayfayı yenileyin; sorun sürerse bize bildirin.",
    hTaric: "Bu 8 haneli kod birden fazla TARIC koduna ayrılıyor. 10 haneli kodu girin:",
    sonuc: "Sonuç", indir: "Raporu indir (HTML)", yazdir: "Yazdır / PDF",
    baslikRapor: "CBAM maliyet raporu", uretildi: "tarihinde üretildi", menseK: "menşe",
    kEur: "EUR / yıl", kTon: "EUR / ton", kSert: "tCO2e sertifika", kOran: "emisyonun vergilenen oranı",
    hesap: "Hesap", kalem: "Kalem", formul: "Formül", deger: "Değer",
    gomulu: "Gömülü emisyon", ucretsiz: "Ücretsiz tahsisat", deMinimis: "De minimis muafiyeti",
    sertifika: "Sertifika yükümlülüğü", maliyet: "CBAM maliyeti", bugunkuKur: "bugünkü kur",
    hesapNot: "Her ara adım görünür; sonuç kâğıt üzerinde doğrulanabilir. 2034'te CBAM faktörü %0'a indiğinde (yükümlülük payı %100) ücretsiz tahsisat sıfırlanır ve benchmark hesaptan tamamen düşer.",
    yillik: "Yıllara göre CBAM maliyeti, 2026–2034",
    yillikAciklama: (f) => `Aynı miktar, aynı karbon fiyatı (${f} EUR/tCO2e). Yalnızca mevzuat takvimi değişiyor: ücretsiz tahsisatın azalması, varsayılan değerin mark-up'ı (2026 %10, 2027 %20, 2028+ %30) ve yıla bağlı benchmark. Fiyat ve kur belirsizliği aşağıdaki bölümdedir.`,
    yillikNot: "Her yıl aynı karbon fiyatı varsayılmıştır; gerçek maliyet o yılın sertifika fiyatına bağlıdır.",
    sYil: "Yıl", sFaktor: "CBAM faktörü", sYogunluk: "Yoğunluk", sBenchmark: "Benchmark", sSertifika: "Sertifika (tCO2e)", sEur: "EUR",
    sirala: (s) => `${s} sütununa göre sırala`,
    belirsizlik: "Belirsizlik",
    ufuk0: "Yükümlülük yılı baz yılla aynı; fiyat ve kur belirsizliği yok. Aşağıdaki aralık yalnızca tesis verimliliği saçılımından gelir.",
    ufuk: (h, n) => `Karbon fiyatı ve döviz kuru ${h} yıllık ufukta Geometrik Brown Hareketi ile, tesis verimliliği lognormal dağılımla oynatıldı. ${n} bağımsız senaryo koşuldu.`,
    senaryo: "Senaryo", yuzdelikler: ["%5 (iyimser)", "%25", "Medyan", "%75", "%95 (VaR)"],
    butce: "Bütçelenmesi gereken rakam %95 senaryosudur.",
    butce2: "Medyan zamanın yarısında aşılır; tek bir sayıya göre bütçe yapan taraf, ihtimallerin yarısında yanılır.",
    kirpma: "Grafikte üst %2'lik kuyruk okunabilirlik için kırpılmıştır; yüzdelik tablosu tam dağılımdan hesaplanmıştır.",
    try: "TRY karşılığı: iki ayrı soru, iki ayrı rakam", tryBugun: (k) => `Bugünkü kurla (${k} TRY/EUR)`,
    tryNominal: (y) => `${y} nominal kuruyla`, medyan: "medyan",
    tryNot: "Nominal rakam kur sürüklemesi varsayımına bağlıdır. Planlamada bugünkü kurla satırını kullanın.",
    varsayimlar: "Varsayımlar",
    nYogunluk: "Emisyon yoğunluğu: AB varsayılan değeri ve mark-up. Kendi ölçüm değeri girişi henüz yok.",
    nRota: (r) => `Üretim rotası seçimi henüz yok: menşe için AB tablosundaki rota ${r} kullanıldı.`,
    nYedek: (m) => `${m} sayfasında bu mal için değer yok; "Other countries and territories" tablosu kullanıldı.`,
    nRotaBelirsiz: (i, d) => `Üretim rotası belirlenemedi; tablodaki ilk rota ${i} kullanıldı. Bu kod için diğer rotalar: ${d}.`,
    nYil2031: "2031 ve sonrası için resmî benchmark yayımlanmadı; 2028–30 değeri kullanıldı.",
    nOncul: "Öncül (ara ürün) zinciri hesaba katılmaz.",
    nFiyat: (f) => `Karbon fiyatı ${f} EUR/tCO2e kullanıcı girdisidir, tahmin değildir.`,
    nBelirsizlik: "Belirsizlik parametreleri aracın varsayılanlarıdır; kaynağı doğrulanmadı.",
    birimNot: (b) => `Bu sektörde emisyon ${b} başına izlenir ve raporlanır; yükümlülük hesabı ise ton ürün üzerinden yapılır. Bu araca miktarı ton ürün olarak girin.`,
    dmBaslik: "De minimis muafiyeti: bu miktar için CBAM yükümlülüğü doğmuyor.",
    dm1: (q) => `${q} ton, 50 ton net kütle eşiğini aşmıyor (CBAM Tüzüğü Md. 2a, Ek VII nokta 1; Rehber No. 1 s.23).`,
    dm2: "Eşik ithalatçı başına, takvim yılı boyunca kümülatif ve tüm CN kodlarının toplamında geçerlidir.",
    dm3: (y, q, s, e, f) => `İthalatçının ${y} yılındaki toplamı 50 tonu aşarsa o yılın tüm ithalatı yükümlü olur. O durumda bu ${q} ton için yük: ${s} tCO2e, ${e} EUR (${f} EUR/tCO2e ile).`,
    kaynaklar: "Girdiler ve kaynaklar", parametre: "Parametre", kaynak: "Kaynak",
    pMiktar: "İhracat miktarı", pYogunluk: "Emisyon yoğunluğu", pBenchmark: "AB ETS benchmark",
    pFaktor: (y) => `CBAM faktörü (${y})`, pFaktorK: (y) => `ücretsiz tahsisatın kalan payı; yükümlülük payı ${y}. Rehber No. 4 Tablo 2-1 (CIR (EU) 2025/2620)`,
    pFiyat: "Karbon fiyatı", pKur: "Döviz kuru", kullanici: "kullanıcı girdisi", girilmedi: "girilmedi", yalnizEur: "yalnızca EUR raporlandı",
    pUfuk: "Zaman ufku", bazYil: (y) => `baz yıl ${y}`, yil1: "yıl", pTohum: "Rastgele tohum", tekrar: "tekrarlanabilirlik",
    pVeri: "Referans veri paketi", resmi: "resmî tablolar, doğrulandı",
    markupEk: (m) => `, varsayılan + %${m} mark-up`, dogrudan: "doğrudan", dolayli: "doğrudan + dolaylı",
    kunye: "Bu rapor açık kaynaklı bir hesap motoruyla üretilmiştir; yöntemin tamamı denetlenebilir. Beyan, yatırım veya fiyatlama kararı için tek başına yeterli değildir. Çelişki halinde resmî mevzuat metni geçerlidir.",
    kaynakKod: "Kaynak kod", acikKaynak: "Açık kaynak",
    grafikYillik: "Yıllara göre CBAM maliyeti, 2026–2034", grafikDagilim: "CBAM maliyeti olasılık dağılımı",
    senaryolar: "senaryoların", tabloGoster: "Tablo olarak göster",
    bin: " bin", milyon: " M",
  },
  en: {
    sayi: "en-GB", yz: (x) => x + "%", birim: "Unit",
    cn: "CN code", cnIpucu: "8 or 10 digits. Suggestions appear as you type.",
    miktar: "Quantity (tonnes / year)", miktarIpucu: "Annual exports to the EU, tonnes of goods.",
    yil: "Year", ulke: "Country of origin", fiyat: "Carbon price (EUR / tCO2e)",
    fiyatIpucu: "An assumption, not a forecast.", kur: "Exchange rate (TRY / EUR)",
    kurIpucu: "Optional. Leave empty to report in EUR only.",
    hesapla: "Calculate", baslat: "Start the calculator", yukleniyor: "Loading data…",
    hesaplaniyor: "Calculating…", hazir: "Calculation complete. Results below.",
    turkiye: "Türkiye", diger: "Unknown / not listed",
    hCn: "The CN code must have 4 to 10 digits (numbers only).",
    hMiktar: "Quantity must be greater than zero.", hFiyat: "Enter a carbon price (0 or more).",
    hKur: "The exchange rate must be greater than zero, or left empty.",
    hForm: "Some fields need correcting.",
    deMinimisBilgi: "The de minimis threshold is 50 tonnes, applied per importer, per year, across all CN codes.",
    hYukleme: "The calculator data could not be loaded. Reload the page; if the problem persists, let us know.",
    hTaric: "This 8-digit code splits into several TARIC codes. Enter the 10-digit code:",
    sonuc: "Result", indir: "Download report (HTML)", yazdir: "Print / PDF",
    baslikRapor: "CBAM cost report", uretildi: "generated on", menseK: "origin",
    kEur: "EUR / year", kTon: "EUR / tonne", kSert: "tCO2e certificates", kOran: "share of emissions taxed",
    hesap: "Calculation", kalem: "Item", formul: "Formula", deger: "Value",
    gomulu: "Embedded emissions", ucretsiz: "Free allocation", deMinimis: "De minimis exemption",
    sertifika: "Certificate obligation", maliyet: "CBAM cost", bugunkuKur: "today's rate",
    hesapNot: "Every intermediate step is shown, so the result can be checked on paper. When the CBAM factor reaches 0% in 2034 (obligation share 100%), free allocation ends and the benchmark drops out of the calculation.",
    yillik: "CBAM cost by year, 2026–2034",
    yillikAciklama: (f) => `Same quantity, same carbon price (${f} EUR/tCO2e). Only the regulatory schedule changes: shrinking free allocation, the default-value mark-up (2026 10%, 2027 20%, 2028+ 30%) and the year-specific benchmark. Price and exchange-rate uncertainty is covered below.`,
    yillikNot: "The same carbon price is assumed every year; the actual cost depends on that year's certificate price.",
    sYil: "Year", sFaktor: "CBAM factor", sYogunluk: "Intensity", sBenchmark: "Benchmark", sSertifika: "Certificates (tCO2e)", sEur: "EUR",
    sirala: (s) => `Sort by ${s}`,
    belirsizlik: "Uncertainty",
    ufuk0: "The obligation year equals the base year, so there is no price or exchange-rate uncertainty. The range below comes from plant-efficiency variation only.",
    ufuk: (h, n) => `Carbon price and exchange rate were simulated over a ${h}-year horizon with geometric Brownian motion, plant efficiency with a lognormal distribution. ${n} independent scenarios were run.`,
    senaryo: "Scenario", yuzdelikler: ["5% (optimistic)", "25%", "Median", "75%", "95% (VaR)"],
    butce: "Budget for the 95% scenario.",
    butce2: "The median is exceeded half of the time; a budget built on a single number is wrong in half of the outcomes.",
    kirpma: "The top 2% tail is trimmed in the chart for readability; the percentile table uses the full distribution.",
    try: "TRY equivalent: two different questions, two figures", tryBugun: (k) => `At today's rate (${k} TRY/EUR)`,
    tryNominal: (y) => `At the ${y} nominal rate`, medyan: "median",
    tryNot: "The nominal figure depends on the exchange-rate drift assumption. Use the today's-rate line for planning.",
    varsayimlar: "Assumptions",
    nYogunluk: "Emission intensity: EU default value plus mark-up. Entering your own measured value is not yet supported.",
    nRota: (r) => `Production-route selection is not yet available: the route in the EU table for this origin, ${r}, was used.`,
    nYedek: (m) => `The ${m} sheet has no value for this good; the "Other countries and territories" table was used.`,
    nRotaBelirsiz: (i, d) => `The production route could not be determined; the first route in the table, ${i}, was used. Other routes for this code: ${d}.`,
    nYil2031: "No official benchmark has been published for 2031 and later; the 2028–30 value was used.",
    nOncul: "Precursor (intermediate product) chains are not included.",
    nFiyat: (f) => `The carbon price of ${f} EUR/tCO2e is a user input, not a forecast.`,
    nBelirsizlik: "Uncertainty parameters are the tool's defaults; their source has not been verified.",
    birimNot: (b) => `In this sector emissions are monitored and reported per ${b}, but the obligation is calculated per tonne of goods. Enter the quantity in tonnes of goods.`,
    dmBaslik: "De minimis exemption: no CBAM obligation arises for this quantity.",
    dm1: (q) => `${q} tonnes does not exceed the 50-tonne net mass threshold (CBAM Regulation Art. 2a, Annex VII point 1; Guidance No. 1 p.23).`,
    dm2: "The threshold applies per importer, cumulatively over the calendar year and across all CN codes.",
    dm3: (y, q, s, e, f) => `If the importer's total for ${y} exceeds 50 tonnes, all imports that year become liable. In that case the charge for these ${q} tonnes is ${s} tCO2e, ${e} EUR (at ${f} EUR/tCO2e).`,
    kaynaklar: "Inputs and sources", parametre: "Parameter", kaynak: "Source",
    pMiktar: "Export quantity", pYogunluk: "Emission intensity", pBenchmark: "EU ETS benchmark",
    pFaktor: (y) => `CBAM factor (${y})`, pFaktorK: (y) => `remaining share of free allocation; obligation share ${y}. Guidance No. 4 Table 2-1 (CIR (EU) 2025/2620)`,
    pFiyat: "Carbon price", pKur: "Exchange rate", kullanici: "user input", girilmedi: "not entered", yalnizEur: "reported in EUR only",
    pUfuk: "Time horizon", bazYil: (y) => `base year ${y}`, yil1: "years", pTohum: "Random seed", tekrar: "reproducibility",
    pVeri: "Reference data package", resmi: "official tables, verified",
    markupEk: (m) => `, default + ${m}% mark-up`, dogrudan: "direct", dolayli: "direct + indirect",
    kunye: "This report was produced by an open-source calculation engine; the whole method can be audited. It is not sufficient on its own for declarations, investment or pricing decisions. In case of conflict, the official legal text prevails.",
    kaynakKod: "Source code", acikKaynak: "Open source",
    grafikYillik: "CBAM cost by year, 2026–2034", grafikDagilim: "Probability distribution of CBAM cost",
    senaryolar: "of scenarios", tabloGoster: "Show as table",
    bin: "k", milyon: " M",
  },
};

// ------------------------------------------------------------------- yardimcilar
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const bicimci = (yer) => {
  const onb = new Map();
  return (x, d = 0) => {
    if (!onb.has(d)) onb.set(d, new Intl.NumberFormat(yer, { minimumFractionDigits: d, maximumFractionDigits: d }));
    return onb.get(d).format(x);
  };
};
// R: pretty() benzeri "guzel" eksen adimlari
function guzelTikler(ust, n = 4) {
  if (!(ust > 0)) return [0];
  const kaba = ust / n, us = 10 ** Math.floor(Math.log10(kaba)), o = kaba / us;
  const adim = (o <= 1 ? 1 : o <= 2 ? 2 : o <= 5 ? 5 : 10) * us;
  const t = [];
  for (let v = 0; v < ust + adim * 0.999; v += adim) t.push(Math.round(v / adim) * adim);
  return t;
}
let sayac = 0;

// ------------------------------------------------------------------- rapor parcalari
function raporParcalari(s, T, f, { etkilesimli }) {
  const i = s.inputs, d = s.deterministic, see = s.see, bm = s.bm, g = s.girdi;
  const kalan = 1 - i.cbam_factor;
  const fton = (v) => f(v, Math.abs(v) < 1000 ? 1 : 0);
  const kisa = (v) => (Math.abs(v) >= 1e6 ? f(v / 1e6, 1) + T.milyon : Math.abs(v) >= 1e4 ? f(v / 1e3, 0) + T.bin : f(v));
  const kurVar = g.kur !== 1;
  const etiket = (see.dolayli_var ? T.dolayli : T.dogrudan) + (see.markup > 0 ? T.markupEk(f(100 * see.markup, 0)) : "");
  const ulkeAdi = (u) => (u === "Turkiye" ? T.turkiye : u.startsWith("Other") ? T.diger : u.replaceAll(";", ","));

  // uyari ve bilgi kutulari
  const kutular = [];
  if (!bm.birim.standart) kutular.push(`<div class="cbam-bilgi">${esc(T.birimNot(bm.birim.birim))}</div>`);
  const odenmeyen = Math.max(0, d.embedded - d.free_allocation);
  if (d.de_minimis) {
    kutular.push(`<div class="cbam-uyari" role="note"><strong>${esc(T.dmBaslik)}</strong><ul>
      <li>${esc(T.dm1(f(i.quantity)))}</li><li>${esc(T.dm2)}</li>
      <li>${esc(T.dm3(i.year, f(i.quantity), f(odenmeyen, 1), f(odenmeyen * i.carbon_price, 2), f(i.carbon_price, 2)))}</li></ul></div>`);
  }

  const kart = (v, e) => `<div class="cbam-kart"><div class="cbam-kart-deger">${v}</div><div class="cbam-kart-etiket">${esc(e)}</div></div>`;
  const kartlar = `<div class="cbam-kartlar">${kart(f(d.cost_eur), T.kEur)}${kart(f(d.cost_per_tonne, 2), T.kTon)}${kart(f(d.certificates), T.kSert)}${kart(T.yz(f(100 * d.taxed_share, 1)), T.kOran)}</div>`;

  const satir = (e, fo, v, b, sinif = "") => `<tr${sinif ? ` class="${sinif}"` : ""}><th scope="row">${esc(e)}</th><td class="cbam-formul">${esc(fo)}</td><td class="cbam-sayi">${esc(v)}</td><td class="cbam-birim">${esc(b)}</td></tr>`;
  const satirlar = [
    satir(T.gomulu, `${f(i.quantity)} t × ${f(i.ei_total, 3)}`, fton(d.embedded), "tCO2e"),
    satir(T.ucretsiz, `${f(i.benchmark, 3)} × ${f(i.quantity)} × ${f(kalan, 3)}`, "−" + fton(d.free_allocation), "tCO2e"),
  ];
  if (d.de_minimis) satirlar.push(satir(T.deMinimis, `${f(i.quantity)} t ≤ 50 t`, "−" + fton(odenmeyen), "tCO2e"));
  satirlar.push(satir(T.sertifika, "", fton(d.certificates), "tCO2e", "cbam-toplam"));
  satirlar.push(satir(T.maliyet, `${fton(d.certificates)} × ${f(i.carbon_price, 2)} EUR`, f(d.cost_eur), "EUR", "cbam-toplam"));
  if (kurVar) satirlar.push(satir("", `× ${f(i.fx_rate, 2)} TRY/EUR (${T.bugunkuKur})`, f(d.cost_local), "TRY"));
  const hesap = `<section class="cbam-bolum"><h3>${esc(T.hesap)}</h3><div class="cbam-tablo-kap" tabindex="0" role="region" aria-label="${esc(T.hesap)}">
    <table class="cbam-tablo"><thead><tr><th scope="col">${esc(T.kalem)}</th><th scope="col">${esc(T.formul)}</th><th scope="col" class="cbam-sayi">${esc(T.deger)}</th><th scope="col"><span class="cbam-gizli">${esc(T.birim)}</span></th></tr></thead>
    <tbody>${satirlar.join("")}</tbody></table></div><p class="cbam-not">${esc(T.hesapNot)}</p></section>`;

  // yillik yol: grafik + siralanabilir tablo
  let yillik = "";
  if (!d.de_minimis && s.yillik.length && Math.max(...s.yillik.map((r) => r.cost_eur)) > 0) {
    const bas = [T.sYil, T.sFaktor, T.sYogunluk, T.sBenchmark, T.sSertifika, T.sEur];
    const thBas = bas.map((b, k) => {
      const sinif = k === 0 ? "" : ' class="cbam-sayi"';
      return etkilesimli
        ? `<th scope="col"${sinif} aria-sort="${k === 0 ? "ascending" : "none"}"><button type="button" class="cbam-sirala" data-sutun="${k}" aria-label="${esc(T.sirala(b))}">${esc(b)}<span aria-hidden="true" class="cbam-ok"></span></button></th>`
        : `<th scope="col"${sinif}>${esc(b)}</th>`;
    }).join("");
    const tr = s.yillik.map((r) => `<tr${r.yil === i.year ? ' class="cbam-secili"' : ""}>
      <td data-deger="${r.yil}">${r.yil}</td><td class="cbam-sayi" data-deger="${r.faktor}">${T.yz(f(100 * r.faktor, 1))}</td>
      <td class="cbam-sayi" data-deger="${r.yogunluk}">${f(r.yogunluk, 3)}</td><td class="cbam-sayi" data-deger="${r.benchmark}">${f(r.benchmark, 3)}</td>
      <td class="cbam-sayi" data-deger="${r.sertifika}">${f(r.sertifika)}</td><td class="cbam-sayi" data-deger="${r.cost_eur}">${f(r.cost_eur)}</td></tr>`).join("");
    yillik = `<section class="cbam-bolum"><h3>${esc(T.yillik)}</h3><p>${esc(T.yillikAciklama(f(i.carbon_price, 2)))}</p>
      ${svgYillik(s.yillik, i.year, T, f, kisa)}<p class="cbam-not">${esc(T.yillikNot)}</p>
      <div class="cbam-tablo-kap" tabindex="0" role="region" aria-label="${esc(T.yillik)}"><table class="cbam-tablo cbam-cizgili cbam-yapiskan" data-siralanabilir>
      <thead><tr>${thBas}</tr></thead><tbody>${tr}</tbody></table></div></section>`;
  }

  // belirsizlik
  let belirsizlik = "";
  if (s.simulation) {
    const m = s.simulation;
    const p = [0.05, 0.25, 0.5, 0.75, 0.95].map((x) => m.q("cost_eur", x));
    const yuz = p.map((v, k) => `<tr><th scope="row">${esc(T.yuzdelikler[k])}</th><td class="cbam-sayi">${f(v)}</td></tr>`).join("");
    let tryBlok = "";
    if (kurVar) {
      const bt = (x) => f(m.q("cost_local_today", x)), nm = (x) => f(m.q("cost_local", x));
      tryBlok = `<h4>${esc(T.try)}</h4><div class="cbam-tablo-kap"><table class="cbam-tablo cbam-cizgili"><tbody>
        <tr><th scope="row">${esc(T.tryBugun(f(i.fx_rate, 2)))}</th><td>${esc(T.medyan)}</td><td class="cbam-sayi">${bt(0.5)} TRY</td></tr>
        <tr><th scope="row"></th><td>${T.yz(95)}</td><td class="cbam-sayi">${bt(0.95)} TRY</td></tr>
        <tr><th scope="row">${esc(T.tryNominal(i.year))}</th><td>${esc(T.medyan)}</td><td class="cbam-sayi">${nm(0.5)} TRY</td></tr>
        <tr><th scope="row"></th><td>${T.yz(95)}</td><td class="cbam-sayi">${nm(0.95)} TRY</td></tr></tbody></table></div>
        ${m.horizon > 0 ? `<p class="cbam-not">${esc(T.tryNot)}</p>` : ""}`;
    }
    belirsizlik = `<section class="cbam-bolum"><h3>${esc(T.belirsizlik)}</h3>
      <p>${esc(m.horizon === 0 ? T.ufuk0 : T.ufuk(m.horizon, f(m.n_sims)))}</p>
      ${svgDagilim(m.cekim.cost_eur, p[2], p[4], T, f)}
      <div class="cbam-iki-sutun"><div class="cbam-tablo-kap"><table class="cbam-tablo cbam-cizgili">
      <thead><tr><th scope="col">${esc(T.senaryo)}</th><th scope="col" class="cbam-sayi">${esc(T.kEur)}</th></tr></thead><tbody>${yuz}</tbody></table></div>
      <div><p><strong>${esc(T.butce)}</strong> ${esc(T.butce2)}</p><p class="cbam-not">${esc(T.kirpma)}</p></div></div>${tryBlok}</section>`;
  }

  // varsayimlar (R/web.R notlari)
  const notlar = [T.nYogunluk];
  if (bm.rota) notlar.push(T.nRota(bm.rota));
  if (see.dv.yedek) notlar.push(T.nYedek(ulkeAdi(see.dv.mense)));
  for (const n of bm.notlar) notlar.push(n.tur === "yil-2031" ? T.nYil2031 : T.nRotaBelirsiz(n.ilk, n.digerleri.join(" ")));
  notlar.push(T.nOncul, T.nFiyat(f(i.carbon_price, 2)));
  if (s.simulation) notlar.push(T.nBelirsizlik);
  const varsayim = `<div class="cbam-bilgi"><strong>${esc(T.varsayimlar)}</strong><ul>${notlar.map((n) => `<li>${esc(n)}</li>`).join("")}</ul></div>`;

  // girdiler ve kaynaklar
  const kaynakYogunluk = `${see.dv.kaynak}, CN ${see.dv.cn_kodu} | ${f(see.temel, 3)}${see.markup > 0 ? ` + ${T.yz(f(100 * see.markup, 0))} mark-up (Guidance No. 3 p.113)` : ""}`;
  const kaynakBm = `${bm.kaynak}, CN ${bm.cn_kodu}, Column B${bm.rota ? " " + bm.rota : ""}`;
  const pr = (a, b, c) => `<tr><th scope="row">${esc(a)}</th><td>${esc(b)}</td><td>${esc(c)}</td></tr>`;
  const kaynak = `<section class="cbam-bolum"><h3>${esc(T.kaynaklar)}</h3><div class="cbam-tablo-kap" tabindex="0" role="region" aria-label="${esc(T.kaynaklar)}"><table class="cbam-tablo cbam-cizgili">
    <thead><tr><th scope="col">${esc(T.parametre)}</th><th scope="col">${esc(T.deger)}</th><th scope="col">${esc(T.kaynak)}</th></tr></thead><tbody>
    ${pr(T.pMiktar, `${f(i.quantity)} t`, "")}
    ${pr(T.pYogunluk, `${f(i.ei_total, 3)} tCO2e/t (${etiket})`, kaynakYogunluk)}
    ${pr(T.pBenchmark, `${f(i.benchmark, 3)} tCO2e/t`, kaynakBm)}
    ${pr(T.pFaktor(i.year), T.yz(f(100 * kalan, 1)), T.pFaktorK(T.yz(f(100 * i.cbam_factor, 1))))}
    ${pr(T.pFiyat, `${f(i.carbon_price, 2)} EUR/tCO2e`, T.kullanici)}
    ${kurVar ? pr(T.pKur, `${f(i.fx_rate, 2)} TRY/EUR`, T.kullanici) : pr(T.pKur, T.girilmedi, T.yalnizEur)}
    ${pr(T.pUfuk, `${i.horizon} ${T.yil1}`, T.bazYil(i.base_year))}
    ${s.simulation ? pr(T.pTohum, String(s.simulation.seed), T.tekrar) : ""}
    ${pr(T.pVeri, s.veri_surumu, T.resmi)}
    </tbody></table></div></section>`;

  const kunye = `<footer class="cbam-kunye"><p><a href="${KUNYE.kaynak}">${esc(T.kaynakKod)}</a></p><p>${esc(T.kunye)}</p></footer>`;

  const urun = `CN ${see.dv.cn_kodu} – ${see.dv.aciklama} – ${T.menseK} ${ulkeAdi(see.dv.mense)}`;
  return { urun, govde: kutular.join("") + varsayim + kartlar + hesap + yillik + belirsizlik + kaynak + kunye };
}

function svgYillik(yol, secili, T, f, kisa, G = 720, Y = 250) {
  const sol = 58, sag = 10, ust = 24, alt = 28, taban = Y - alt, icG = G - sol - sag;
  const tik = guzelTikler(Math.max(...yol.map((r) => r.cost_eur)));
  const ymax = tik[tik.length - 1];
  const yk = (v) => taban - (v / ymax) * (taban - ust);
  const slot = icG / yol.length, g = Math.min(24, slot * 0.55);
  const izgara = tik.map((t) => `<line x1="${sol}" y1="${yk(t).toFixed(1)}" x2="${G - sag}" y2="${yk(t).toFixed(1)}" class="${t === 0 ? "cbam-eksen" : "cbam-izgara"}"/><text x="${sol - 6}" y="${(yk(t) + 4).toFixed(1)}" class="cbam-eksen-etiket" text-anchor="end">${esc(kisa(t))}</text>`).join("");
  const cubuk = yol.map((r, k) => {
    const x = sol + k * slot + (slot - g) / 2, y = yk(r.cost_eur), h = taban - y;
    const etiket = r.yil === secili || k === yol.length - 1 ? `<text x="${(x + g / 2).toFixed(1)}" y="${(y - 6).toFixed(1)}" class="cbam-deger-etiket" text-anchor="middle">${esc(kisa(r.cost_eur))}</text>` : "";
    return `<g><rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${g.toFixed(1)}" height="${Math.max(h, 0).toFixed(1)}" rx="3" class="cbam-seri${r.yil === secili ? " cbam-seri-secili" : ""}"><title>${r.yil}: ${f(r.cost_eur)} EUR</title></rect>${etiket}<text x="${(x + g / 2).toFixed(1)}" y="${Y - 8}" class="cbam-eksen-etiket${r.yil === secili ? " cbam-secili-etiket" : ""}" text-anchor="middle">${r.yil}</text></g>`;
  }).join("");
  return `<svg viewBox="0 0 ${G} ${Y}" class="cbam-grafik" role="img" aria-label="${esc(T.grafikYillik)}">${izgara}${cubuk}</svg>`;
}

function svgDagilim(sirali, medyan, q95, T, f, G = 720, Y = 220) {
  const n = sirali.length;
  const ust = sirali[Math.floor(0.98 * (n - 1))], alt0 = sirali[0];
  if (!(ust > alt0)) return "";
  const kutu = 40, gen = (ust - alt0) / kutu, say = new Array(kutu).fill(0);
  for (let k = 0; k < n && sirali[k] <= ust; k++) say[Math.min(kutu - 1, Math.floor((sirali[k] - alt0) / gen))]++;
  const sol = 8, sag = 8, alt = 26, icG = G - sol - sag, icY = Y - alt, bg = icG / kutu, olcek = icY / Math.max(...say);
  const x = (v) => sol + ((v - alt0) / (ust - alt0)) * icG;
  const cub = say.map((c, k) => `<rect x="${(sol + k * bg).toFixed(2)}" y="${(icY - c * olcek).toFixed(2)}" width="${Math.max(bg - 1, 0.5).toFixed(2)}" height="${(c * olcek).toFixed(2)}" class="cbam-seri"><title>${f(alt0 + k * gen)} – ${f(alt0 + (k + 1) * gen)} EUR: ${T.senaryolar} %${f((100 * c) / n, 1)}</title></rect>`).join("");
  const cizgi = [[medyan, T.medyan], [q95, T.yz(95)]].filter(([v]) => v >= alt0 && v <= ust)
    .map(([v, e]) => `<line x1="${x(v).toFixed(1)}" y1="0" x2="${x(v).toFixed(1)}" y2="${icY}" class="cbam-isaret"/><text x="${(x(v) + 4).toFixed(1)}" y="12" class="cbam-isaret-etiket">${esc(e)}</text>`).join("");
  return `<svg viewBox="0 0 ${G} ${Y}" class="cbam-grafik" role="img" aria-label="${esc(T.grafikDagilim)}">${cub}${cizgi}<line x1="${sol}" y1="${icY}" x2="${G - sag}" y2="${icY}" class="cbam-eksen"/><text x="${sol}" y="${Y - 6}" class="cbam-eksen-etiket">${esc(f(alt0))}</text><text x="${G - sag}" y="${Y - 6}" class="cbam-eksen-etiket" text-anchor="end">${esc(f(ust))}</text></svg>`;
}

// Indirilen rapor: tek dosya, kendi kendine yeter (R/report.R ile ayni ilke)
const RAPOR_STIL = `:root{--ink:#1a1a1a;--soft:#5f5e5a;--line:#d9d8d2;--bg:#fff;--vurgu:#1f4e5f;--seri:#2a78d6;--izgara:#e6e5df;--uyari-bg:#fff4e5;--uyari-ink:#7a4100;--bilgi-bg:#f3f6f8}
*{box-sizing:border-box}body{margin:0;padding:2rem 1.25rem;background:var(--bg);color:var(--ink);font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
.sayfa{max-width:820px;margin:0 auto}header{border-bottom:3px solid var(--vurgu);padding-bottom:1rem;margin-bottom:1.5rem}h1{margin:0 0 .25rem;font-size:1.6rem}
.alt{color:var(--soft);font-size:.9rem}h3{font-size:1.15rem;margin:2rem 0 .75rem;color:var(--vurgu);border-bottom:1px solid var(--line);padding-bottom:.35rem}h4{font-size:1rem;margin:1.25rem 0 .5rem}
.cbam-kartlar{display:flex;flex-wrap:wrap;gap:.75rem;margin:1.5rem 0}.cbam-kart{flex:1 1 160px;border:1px solid var(--line);border-radius:6px;padding:.9rem 1rem}
.cbam-kart-deger{font-size:1.5rem;font-weight:600;font-variant-numeric:tabular-nums}.cbam-kart-etiket{color:var(--soft);font-size:.8rem}
table{width:100%;border-collapse:collapse;font-size:.95rem}th,td{padding:.45rem .6rem;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}
thead th{font-size:.8rem;color:var(--soft)}.cbam-sayi{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}
.cbam-formul{color:var(--soft);font-size:.85rem;font-family:ui-monospace,SFMono-Regular,Consolas,monospace}.cbam-birim{color:var(--soft);font-size:.85rem}
tr.cbam-toplam th,tr.cbam-toplam td{font-weight:600;border-top:2px solid var(--ink)}.cbam-cizgili tbody tr:nth-child(even){background:#f7f7f4}tr.cbam-secili td{font-weight:600}
.cbam-uyari{background:var(--uyari-bg);color:var(--uyari-ink);border-left:4px solid currentColor;padding:.9rem 1rem;margin:1.25rem 0;font-size:.92rem}
.cbam-bilgi{background:var(--bilgi-bg);border-left:4px solid var(--vurgu);padding:.9rem 1rem;margin:1.25rem 0;font-size:.92rem}ul{margin:.5rem 0 0;padding-left:1.1rem}
.cbam-grafik{width:100%;height:auto;margin:1rem 0 .5rem}.cbam-seri{fill:var(--seri)}.cbam-seri-secili{fill:var(--vurgu)}.cbam-eksen{stroke:#c3c2b7}.cbam-izgara{stroke:var(--izgara)}
.cbam-isaret{stroke:#52514e}.cbam-isaret-etiket,.cbam-eksen-etiket{fill:var(--soft);font-size:11px}.cbam-deger-etiket{fill:var(--ink);font-size:12px;font-weight:600}.cbam-secili-etiket{fill:var(--ink);font-weight:700}
.cbam-iki-sutun{display:flex;flex-wrap:wrap;gap:1.5rem}.cbam-iki-sutun>*{flex:1 1 280px}.cbam-not{color:var(--soft);font-size:.85rem}.cbam-gizli{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}
.cbam-kunye{margin-top:2.5rem;padding-top:1rem;border-top:1px solid var(--line);color:var(--soft);font-size:.82rem}a{color:var(--vurgu)}
@media print{body{padding:0;font-size:11pt}section{break-inside:avoid}}`;

function raporBelgesi(s, T, f, dil) {
  const { urun, govde } = raporParcalari(s, T, f, { etkilesimli: false });
  const tarih = new Intl.DateTimeFormat(T.sayi, { dateStyle: "long" }).format(new Date());
  return `<!doctype html><html lang="${dil}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(T.baslikRapor)}</title><style>${RAPOR_STIL}</style></head><body><div class="sayfa">
<header><h1>${esc(T.baslikRapor)}</h1><div class="alt">${esc(urun)} · ${esc(tarih)} ${esc(T.uretildi)}</div></header>
${govde}</div></body></html>`;
}

// ------------------------------------------------------------------- tablo siralama
function siralamayiBagla(kok) {
  for (const tablo of kok.querySelectorAll("table[data-siralanabilir]")) {
    tablo.addEventListener("click", (olay) => {
      const dugme = olay.target.closest(".cbam-sirala");
      if (!dugme) return;
      const th = dugme.closest("th"), k = Number(dugme.dataset.sutun);
      const yeni = th.getAttribute("aria-sort") === "ascending" ? "descending" : "ascending";
      for (const t of tablo.querySelectorAll("thead th")) t.setAttribute("aria-sort", "none");
      th.setAttribute("aria-sort", yeni);
      const govde = tablo.tBodies[0], yon = yeni === "ascending" ? 1 : -1;
      [...govde.rows].sort((a, b) => yon * (Number(a.cells[k].dataset.deger) - Number(b.cells[k].dataset.deger)))
        .forEach((r) => govde.appendChild(r));
    });
  }
}

// ------------------------------------------------------------------- yerlesim (sifir oncelik)
const YERLESIM = `
:where(.cbam-form){display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,220px),1fr));gap:1.1rem 1.25rem;margin:1rem 0}
:where(.cbam-alan){display:flex;flex-direction:column;gap:.3rem;min-width:0}
:where(.cbam-alan input,.cbam-alan select){width:100%;box-sizing:border-box;font:inherit;color:inherit;background-color:var(--cbam-zemin,#fff);padding:.55rem .65rem;border:1px solid var(--cbam-cizgi,#c9c8c2);border-radius:var(--cbam-yaricap,.5rem)}
:where(.cbam-alan input[aria-invalid="true"]){border-color:var(--cbam-hata,#b42318)}
:where(.cbam-ipucu){font-size:.85em;color:var(--cbam-soluk,#5f5e5a)}
:where(.cbam-alan-hata){font-size:.85em;color:var(--cbam-hata,#b42318)}
:where(.cbam-alan-bilgi){font-size:.85em;color:var(--cbam-soluk,#5f5e5a)}
:where(.cbam-eylem){grid-column:1/-1;display:flex;gap:1rem;align-items:center;flex-wrap:wrap}
:where(.cbam-hesapla,.cbam-baslat){font:inherit;font-weight:600;cursor:pointer;padding:.6rem 1.3rem;border:0;border-radius:var(--cbam-yaricap-dugme,50rem);background:var(--cbam-vurgu,#1f4e5f);color:var(--cbam-vurgu-yazi,#fff)}
:where(.cbam-hesapla:disabled){opacity:.55;cursor:progress}
:where(.cbam-ikincil){font:inherit;cursor:pointer;padding:.5rem 1rem;border:1px solid var(--cbam-cizgi,#c9c8c2);border-radius:var(--cbam-yaricap-dugme,50rem);background:transparent;color:inherit;text-decoration:none;display:inline-block}
:where(.cbam-hata-kutu){padding:.8rem 1rem;margin:1rem 0;border-radius:var(--cbam-yaricap,.5rem);background:var(--cbam-hata-zemin,#fdecea);color:var(--cbam-hata,#b42318)}
:where(.cbam-sonuc){margin-top:2rem}
:where(.cbam-sonuc-ust){display:flex;flex-wrap:wrap;gap:.75rem 1rem;align-items:baseline;justify-content:space-between}
:where(.cbam-kartlar){display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,150px),1fr));gap:.75rem;margin:1.25rem 0}
:where(.cbam-kart){padding:.9rem 1rem;border-radius:var(--cbam-yaricap,.75rem);background:var(--cbam-yuzey,#f2f3f5)}
:where(.cbam-kart-deger){font-size:1.45rem;font-weight:650;font-variant-numeric:tabular-nums;letter-spacing:-.01em}
:where(.cbam-kart-etiket){font-size:.82rem;color:var(--cbam-soluk,#5f5e5a)}
:where(.cbam-tablo-kap){overflow-x:auto;max-width:100%;-webkit-overflow-scrolling:touch}
:where(.cbam-yapiskan .cbam-tablo-kap,.cbam-tablo-kap:has(.cbam-yapiskan)){max-height:28rem;overflow:auto}
:where(.cbam-tablo){width:100%;border-collapse:collapse;font-size:.92rem;margin:.5rem 0}
:where(.cbam-tablo th,.cbam-tablo td){padding:.5rem .65rem;text-align:left;vertical-align:top;border-bottom:1px solid var(--cbam-cizgi,#e3e2dc)}
:where(.cbam-tablo thead th){font-size:.82rem;font-weight:600;color:var(--cbam-soluk,#5f5e5a);background:var(--cbam-zemin,#fff)}
:where(.cbam-yapiskan thead th){position:sticky;top:0;z-index:1}
:where(.cbam-cizgili tbody tr:nth-child(even)){background:var(--cbam-zebra,rgba(0,0,0,.03))}
:where(.cbam-tablo tbody th){font-weight:500}
:where(.cbam-sayi){text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}
:where(.cbam-formul){font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:.85em;color:var(--cbam-soluk,#5f5e5a)}
:where(.cbam-birim){font-size:.85em;color:var(--cbam-soluk,#5f5e5a);white-space:nowrap}
:where(tr.cbam-toplam th,tr.cbam-toplam td){font-weight:650;border-top:2px solid currentColor}
:where(tr.cbam-secili td){font-weight:650}
:where(.cbam-sirala){all:unset;cursor:pointer;display:inline-flex;gap:.3rem;align-items:center}
:where(.cbam-sirala:focus-visible){outline:2px solid var(--cbam-vurgu,#1f4e5f);outline-offset:2px}
:where(th[aria-sort="ascending"] .cbam-ok)::after{content:"▲";font-size:.7em}
:where(th[aria-sort="descending"] .cbam-ok)::after{content:"▼";font-size:.7em}
:where(.cbam-uyari,.cbam-bilgi){padding:.9rem 1.1rem;margin:1.25rem 0;border-radius:var(--cbam-yaricap,.75rem);font-size:.93rem}
:where(.cbam-uyari){background:var(--cbam-uyari-zemin,#fff4e5);color:var(--cbam-uyari-yazi,#7a4100)}
:where(.cbam-bilgi){background:var(--cbam-yuzey,#f2f3f5)}
:where(.cbam-uyari ul,.cbam-bilgi ul){margin:.4rem 0 0;padding-left:1.1rem}
:where(.cbam-grafik){width:100%;height:auto;margin:1rem 0 .25rem;overflow:visible}
:where(.cbam-seri){fill:var(--cbam-seri,#2a78d6)}:where(.cbam-seri-secili){fill:var(--cbam-vurgu,#1f4e5f)}
:where(.cbam-eksen){stroke:var(--cbam-eksen,#c3c2b7)}:where(.cbam-izgara){stroke:var(--cbam-izgara,#e6e5df)}
:where(.cbam-isaret){stroke:var(--cbam-soluk,#5f5e5a)}
:where(.cbam-eksen-etiket,.cbam-isaret-etiket){fill:var(--cbam-soluk,#5f5e5a);font-size:11px}
:where(.cbam-deger-etiket,.cbam-secili-etiket){fill:currentColor;font-size:12px;font-weight:650}
:where(.cbam-iki-sutun){display:flex;flex-wrap:wrap;gap:1.5rem;align-items:flex-start}:where(.cbam-iki-sutun>*){flex:1 1 260px;min-width:0}
:where(.cbam-not){font-size:.86em;color:var(--cbam-soluk,#5f5e5a)}
:where(.cbam-gizli){position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
:where(.cbam-kunye){margin-top:2rem;padding-top:1rem;border-top:1px solid var(--cbam-cizgi,#e3e2dc);font-size:.84rem;color:var(--cbam-soluk,#5f5e5a)}`;

// ------------------------------------------------------------------- bilesen
let motorSozu; // sayfada birden fazla hesaplayici olsa da veri bir kez yuklenir
const motorAl = () => (motorSozu ??= motorOlustur(async (yol) => {
  const y = await fetch(new URL(yol, VERI));
  if (!y.ok) throw new Error(`${yol}: ${y.status}`);
  return y.json();
}));

async function kur(kok) {
  const dil = (kok.getAttribute("lang") || document.documentElement.lang || "tr").slice(0, 2) === "en" ? "en" : "tr";
  const T = METIN[dil], f = bicimci(T.sayi), id = `cbam${++sayac}`;
  const alan = (ad, etiket, girdi, ipucu = "") => `<div class="cbam-alan">
    <label for="${id}-${ad}">${esc(etiket)}</label>${girdi}
    ${ipucu ? `<span class="cbam-ipucu" id="${id}-${ad}-ipucu">${esc(ipucu)}</span>` : ""}
    <span class="cbam-alan-hata" id="${id}-${ad}-hata" hidden></span>
    ${ad === "miktar" ? `<span class="cbam-alan-bilgi" id="${id}-miktar-bilgi" hidden>${esc(T.deMinimisBilgi)}</span>` : ""}</div>`;
  const tanim = (ad, ek = "") => `id="${id}-${ad}" name="${ad}" aria-describedby="${id}-${ad}-ipucu ${id}-${ad}-hata${ad === "miktar" ? ` ${id}-miktar-bilgi` : ""}" ${ek}`;
  kok.innerHTML = `<form class="cbam-form" novalidate>
    ${alan("cn", T.cn, `<input ${tanim("cn", `inputmode="numeric" autocomplete="off" spellcheck="false" maxlength="14" list="${id}-oneri" required value="72081000"`)}><datalist id="${id}-oneri"></datalist>`, T.cnIpucu)}
    ${alan("miktar", T.miktar, `<input ${tanim("miktar", 'type="number" inputmode="decimal" min="0" step="any" required value="1000"')}>`, T.miktarIpucu)}
    ${alan("yil", T.yil, `<select ${tanim("yil")}></select>`)}
    ${alan("ulke", T.ulke, `<select ${tanim("ulke")}></select>`)}
    ${alan("fiyat", T.fiyat, `<input ${tanim("fiyat", 'type="number" inputmode="decimal" min="0" step="any" required value="80"')}>`, T.fiyatIpucu)}
    ${alan("kur", T.kur, `<input ${tanim("kur", 'type="number" inputmode="decimal" min="0" step="any" autocomplete="off"')}>`, T.kurIpucu)}
    <div class="cbam-eylem"><button class="cbam-hesapla" type="submit" disabled>${esc(T.hesapla)}</button>
    <span class="cbam-durum" role="status" aria-live="polite"></span></div></form>
    <div class="cbam-hata-kutu" role="alert" hidden></div>
    <section class="cbam-sonuc" hidden aria-labelledby="${id}-sonuc"></section>`;
  const q = (s) => kok.querySelector(s), form = q("form");
  const durum = (m) => { q(".cbam-durum").textContent = m; };
  const genelHata = (html) => { const k = q(".cbam-hata-kutu"); k.innerHTML = html; k.hidden = !html; };
  const alanHata = (ad, m) => {
    const g = form.elements[ad], h = q(`#${id}-${ad}-hata`);
    h.textContent = m || ""; h.hidden = !m;
    if (m) g.setAttribute("aria-invalid", "true"); else g.removeAttribute("aria-invalid");
  };

  durum(T.yukleniyor);
  let motor;
  try {
    motor = await motorAl();
  } catch {
    durum("");
    return genelHata(esc(T.hYukleme));
  }
  for (const y of motor.meta.yillar) form.yil.add(new Option(y, y));
  form.yil.value = "2030";
  for (const u of motor.ulkeler) {
    form.ulke.add(new Option(u.ad === "Turkiye" ? T.turkiye : u.ad === motor.meta.diger_ulke ? T.diger : u.ad.replaceAll(";", ","), u.ad));
  }
  // CN onerileri: secili ulkenin tablosundaki kodlar (yerel tarayici listesi, ag istegi yok)
  const oneriDoldur = async () => {
    try {
      const t = await (await fetch(new URL(`dv/${motor.ulkeler.find((u) => u.ad === form.ulke.value).dosya}.json`, VERI))).json();
      q(`#${id}-oneri`).innerHTML = t.satirlar.filter((s) => s[0].length >= 8 && s[3] !== null)
        .map((s) => `<option value="${esc(s[0])}">${esc(s[2])}</option>`).join("");
    } catch { /* oneri yalnizca kolaylik */ }
  };
  form.ulke.addEventListener("change", oneriDoldur);
  oneriDoldur();

  const miktarBilgi = () => { const m = Number(form.miktar.value); q(`#${id}-miktar-bilgi`).hidden = !(m > 0 && m <= motor.meta.de_minimis.esik); };
  form.miktar.addEventListener("input", miktarBilgi);
  q(".cbam-hesapla").disabled = false;
  durum("");

  form.addEventListener("submit", async (olay) => {
    olay.preventDefault();
    genelHata("");
    const cn = form.cn.value.replace(/\D/g, ""), miktar = Number(form.miktar.value), fiyat = Number(form.fiyat.value);
    const kurBos = form.kur.value.trim() === "", kur = kurBos ? 1 : Number(form.kur.value);
    const hatalar = {
      cn: cn.length < 4 || cn.length > 10 ? T.hCn : "",
      miktar: form.miktar.value === "" || !(miktar > 0) ? T.hMiktar : "",
      fiyat: form.fiyat.value === "" || !(fiyat >= 0) ? T.hFiyat : "",
      kur: !kurBos && !(kur > 0) ? T.hKur : "",
    };
    for (const [ad, m] of Object.entries(hatalar)) alanHata(ad, m);
    const ilk = Object.keys(hatalar).find((k) => hatalar[k]);
    if (ilk) { durum(T.hForm); form.elements[ilk].focus(); return; }

    const dugme = q(".cbam-hesapla");
    dugme.disabled = true; dugme.setAttribute("aria-busy", "true");
    durum(T.hesaplaniyor);
    try {
      const s = await motor.hesapla({ cn, miktar, yil: Number(form.yil.value), ulke: form.ulke.value, fiyat, kur });
      const { urun, govde } = raporParcalari(s, T, f, { etkilesimli: true });
      const bolum = q(".cbam-sonuc");
      bolum.innerHTML = `<div class="cbam-sonuc-ust"><h2 id="${id}-sonuc" tabindex="-1">${esc(T.sonuc)}</h2>
        <div class="cbam-eylem"><a class="cbam-ikincil cbam-indir" download="cbam-rapor-${esc(cn)}-${s.inputs.year}.html" href="#">${esc(T.indir)}</a>
        <button type="button" class="cbam-ikincil cbam-yazdir">${esc(T.yazdir)}</button></div></div>
        <p class="cbam-not">${esc(urun)}</p>${govde}`;
      const belge = raporBelgesi(s, T, f, dil);
      const a = bolum.querySelector(".cbam-indir");
      if (a.dataset.url) URL.revokeObjectURL(a.dataset.url);
      a.href = a.dataset.url = URL.createObjectURL(new Blob([belge], { type: "text/html;charset=utf-8" }));
      bolum.querySelector(".cbam-yazdir").addEventListener("click", () => {
        const w = window.open("", "_blank");
        if (!w) return;
        w.document.write(belge); w.document.close(); w.focus(); w.print();
      });
      siralamayiBagla(bolum);
      bolum.hidden = false;
      durum(T.hazir);
      bolum.querySelector("h2").focus();
    } catch (e) {
      q(".cbam-sonuc").hidden = true;
      durum("");
      if (e instanceof CbamHata && e.kod === "taric") {
        genelHata(`${esc(T.hTaric)}<ul>${e.secenekler.map((o) => `<li><button type="button" class="cbam-ikincil" data-cn="${esc(o.cn)}">${esc(o.cn)}</button> ${esc(o.aciklama)}</li>`).join("")}</ul>`);
        q(".cbam-hata-kutu").querySelectorAll("[data-cn]").forEach((b) => b.addEventListener("click", () => {
          form.cn.value = b.dataset.cn; genelHata(""); form.requestSubmit();
        }));
      } else if (e instanceof CbamHata) {
        if (["tabloda-yok", "benchmark-yok", "cn"].includes(e.kod)) { alanHata("cn", e.message); form.cn.focus(); }
        else genelHata(esc(e.message));
      } else {
        genelHata(esc(e.message));
      }
    } finally {
      dugme.disabled = false; dugme.removeAttribute("aria-busy");
    }
  });
}

const stil = document.createElement("style");
stil.textContent = YERLESIM;
document.head.prepend(stil); // basa: sayfanin kendi CSS'i her zaman ustun gelir

// Varsayilan: sayfa acilinca kurulur (eski data-otomatik ozniteligi artik gereksiz).
// data-elle verilirse once "Hesaplayiciyi baslat" dugmesi gosterilir.
for (const kok of document.querySelectorAll("[data-cbam-hesaplayici]")) {
  if (!kok.hasAttribute("data-elle")) { kur(kok); continue; }
  const dil = (kok.getAttribute("lang") || document.documentElement.lang || "tr").slice(0, 2) === "en" ? "en" : "tr";
  const b = document.createElement("button");
  b.type = "button"; b.className = "cbam-baslat"; b.textContent = METIN[dil].baslat;
  b.addEventListener("click", () => kur(kok), { once: true });
  kok.replaceChildren(b);
}
