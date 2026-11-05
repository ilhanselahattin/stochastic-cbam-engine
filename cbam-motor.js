// stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Bu dosya GNU Affero General Public License v3 (ya da sonraki bir surum)
// kosullariyla dagitilir; HICBIR GARANTI VERILMEZ. Ayrintilar: LICENSE
// EK SART (AGPL 7(b)): yazar atiflari ve telif bildirimleri korunmalidir.
// Bkz. NOTICE ve LICENSE-ADDITIONAL-TERMS.md
//
// Tarayici hesap motoru (DOM'a dokunmaz, bagimliligi yoktur)
//
// R motorunun web yolunun (R/web.R -> cbam_web_rapor) birebir aktarimidir:
//   cbam_default_intensity / cbam_default_see / cbam_default_markup  (R/reference.R)
//   cbam_benchmark_by_cn                                             (R/reference.R)
//   cbam_estimate / cbam_yillik_yol                                  (R/calculator.R)
//   certificates_due / cbam_cost / is_de_minimis                     (R/cbam.R)
//   run_cbam_mc / simulate_market                                    (R/monte_carlo.R, R/stochastic.R)
//
// Kural ve takvimler kodda YAZILMAZ: data/web/*.json dosyalarindan okunur;
// o dosyalar tools/web_veri.R ile R motorunun kendisinden uretilir. Kesin
// hesap R ile ayni islem sirasini izler, sonuclar bit duzeyinde aynidir.
// tests/test_web.mjs bunu data/web/ornekler.json'daki R ciktilariyla dogrular.
//
// Tek fark belirsizlik bolumundedir: R'nin rastgele sayi ureticisi
// tarayicida yeniden uretilemez. Ayni dagilimlar ayni tohumla ama baska bir
// ureteçle cekilir; yuzdelikler R'dakilerle istatistiksel tolerans icinde
// ortusur (test bunu da kontrol eder).

/** Kullaniciya gosterilecek hata; kod ile turu ayirt edilir. */
export class CbamHata extends Error {
  constructor(kod, mesaj, ek = {}) {
    super(mesaj);
    this.name = "CbamHata";
    this.kod = kod;
    Object.assign(this, ek);
  }
}

// ---------------------------------------------------------------- yardimcilar

/** R: formatC(x, format = "f", digits, big.mark = ".", decimal.mark = ",") */
export function fmtNum(x, digits = 0) {
  if (x === null || x === undefined || Number.isNaN(x)) return "NA";
  // Yuvarlama ikili degere gore yapilir (2450,85 -> 2.450,8; R ile ayni). Tam
  // ortadaki degerlerde (2,5 gibi) R'nin davranisi isletim sistemine gore
  // degisir; burada toFixed'in kurali (yukari) kullanilir.
  let s = x.toFixed(digits);
  const eksi = s.startsWith("-");
  if (eksi) s = s.slice(1);
  const [tam, kesir] = s.split(".");
  const gruplu = tam.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  return (eksi ? "-" : "") + gruplu + (kesir !== undefined ? "," + kesir : "");
}

/** R: stats::quantile(x, p) (type 7). x sirali olmali. */
export function yuzdelik(sirali, p) {
  const n = sirali.length;
  const h = (n - 1) * p;
  const alt = Math.floor(h);
  const ust = Math.min(alt + 1, n - 1);
  return sirali[alt] + (h - alt) * (sirali[ust] - sirali[alt]);
}

const sayi = (v) => (v === null || v === undefined || v === "" ? NaN : Number(v));
const NA = (v) => v === null || v === undefined || Number.isNaN(v);
const rakamlar = (cn) => String(cn ?? "").replace(/[^0-9]/g, "");

/** R: cbam_kaynak_metni() */
function kaynakMetni(belge, yer) {
  belge = (belge ?? "").trim();
  yer = (yer ?? "").trim();
  if (!belge) return "KAYNAK GIRILMEDI";
  if (!yer) return belge;
  return belge + ", " + yer;
}

/** R: cbam_ulke() icindeki sade(): ASCII'ye cevir, yalnizca harfler. */
function sade(s) {
  return String(s).normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/ı/g, "i").replace(/İ/g, "I").toLowerCase().replace(/[^a-z]/g, "");
}

const MUAF = ["iceland", "izlanda", "norway", "norvec", "liechtenstein", "lihtenstayn",
  "switzerland", "isvicre", "busingen", "heligoland", "livigno", "ceuta", "melilla"];

/** Mersenne Twister yerine hizli ve tohumlanabilir sfc32 + Box-Muller. */
function normalUretec(tohum) {
  let a = 0x9e3779b9, b = 0x243f6a88, c = 0xb7e15162, d = tohum >>> 0;
  const u32 = () => {
    a >>>= 0; b >>>= 0; c >>>= 0; d >>>= 0;
    const t = (a + b) | 0;
    a = b ^ (b >>> 9);
    b = (c + (c << 3)) | 0;
    c = (c << 21) | (c >>> 11);
    d = (d + 1) | 0;
    const s = (t + d) | 0;
    c = (c + s) | 0;
    return s >>> 0;
  };
  for (let i = 0; i < 15; i++) u32(); // tohumun ilk etkisini dagit
  const birim = () => (u32() + 0.5) / 4294967296; // (0, 1) acik aralik
  let yedek = null;
  return () => {
    if (yedek !== null) { const z = yedek; yedek = null; return z; }
    const r = Math.sqrt(-2 * Math.log(birim()));
    const t = 2 * Math.PI * birim();
    yedek = r * Math.sin(t);
    return r * Math.cos(t);
  };
}

// ---------------------------------------------------------------- motor

/**
 * Motoru kur.
 * @param {(yol: string) => Promise<any>} yukle  data/web altindaki bir JSON
 *   dosyasini dondurur (tarayicida fetch, testte dosya okuma).
 */
export async function motorOlustur(yukle) {
  const meta = await yukle("meta.json");
  const ulkeler = await yukle("ulkeler.json");
  const DIGER = meta.diger_ulke;
  const onbellek = new Map();
  const tablo = (yol) => {
    if (!onbellek.has(yol)) {
      onbellek.set(yol, yukle(yol).then((t) => t.satirlar.map((s) =>
        Object.fromEntries(t.alanlar.map((a, i) => [a, s[i]])))));
    }
    return onbellek.get(yol);
  };
  const dosyaAdi = new Map(ulkeler.map((u) => [u.ad, u.dosya]));
  const yilIndeksi = (y) => meta.yillar.indexOf(y);

  /** R: cbam_factor_official() */
  const resmiFaktor = (y) => (y < 2026 ? 1 : y >= 2034 ? 0 : meta.cbam_faktoru[yilIndeksi(y)]);
  /** R: cbam_phase_in_factor() = 1 - resmi faktor */
  const yukumlulukPayi = (y) => 1 - resmiFaktor(y);

  /** R: cbam_default_markup() */
  function markup(y, sektor) {
    if (y < 2026) throw new CbamHata("yil", "Varsayılan değer mark-up'ı 2026 ve sonrası için tanımlıdır.");
    const i = Math.min(y, 2028) - 2026;
    const s = sektor == null ? null : meta.markup.sektor[sektor];
    return (s ?? meta.markup.genel)[i];
  }

  /** R: cbam_ulke() */
  function ulkeCoz(ulke) {
    const u = sade(ulke);
    if (["bilinmiyor", "diger", "digerulkeler", "other", "unknown", sade(DIGER)].includes(u)) return DIGER;
    if (u === "turkey" || u === "turkiye") return "Turkiye";
    if (MUAF.includes(u)) {
      throw new CbamHata("muaf-ulke", `${ulke} CBAM kapsamı dışındadır: AB ETS'yi uygulayan ya da ona bağlı ülkelerden gelen mallar için CBAM sertifikası gerekmez.`);
    }
    const bul = ulkeler.find((x) => sade(x.ad) === u);
    if (!bul) throw new CbamHata("ulke", `${ulke} varsayılan değer tablosunda yok. Ülkeniz listede yoksa "Bilinmiyor / listede yok" seçeneğini kullanın.`);
    return bul.ad;
  }

  /** R: cbam_default_intensity() */
  async function varsayilanYogunluk(cnKodu, ulkeAdi = "Turkiye") {
    const cn = rakamlar(cnKodu);
    if (!cn) return null;
    const ulke = ulkeCoz(ulkeAdi);
    const ara = async (ad) => {
      const t = await tablo(`dv/${dosyaAdi.get(ad)}.json`);
      for (let n = cn.length; n >= 2; n--) {
        const r = t.find((s) => s.cn_kodu === cn.slice(0, n));
        if (r) return r;
      }
      const uzun = t.filter((s) => s.cn_kodu.startsWith(cn));
      if (uzun.length === 1) return uzun[0];
      if (uzun.length > 1) {
        throw new CbamHata("taric",
          `CN ${cn} birden fazla TARIC koduna ayrılıyor. 10 haneli kodu girin.`,
          { secenekler: uzun.map((s) => ({ cn: s.cn_kodu, aciklama: s.aciklama })) });
      }
      return null;
    };
    let r = await ara(ulke);
    let yedek = false;
    if ((r === null || NA(sayi(r.dogrudan))) && ulke !== DIGER) {
      r = await ara(DIGER);
      yedek = true;
    }
    if (r === null || NA(sayi(r.dogrudan))) return null;
    return {
      cn_kodu: r.cn_kodu, eslesme: r.cn_kodu === cn ? "tam" : "onek", ulke: ulkeler.find((x) => x.ad === (yedek ? DIGER : ulke)).ad,
      mense: ulke, yedek, sektor: r.sektor, aciklama: r.aciklama,
      dogrudan: sayi(r.dogrudan), dolayli: sayi(r.dolayli), toplam: sayi(r.toplam),
      rota: r.rota ?? "", kaynak: kaynakMetni(r.kaynak_belge, r.kaynak_yeri), durum: (r.durum ?? "").trim(),
    };
  }

  /** R: cbam_default_see() */
  async function varsayilanSee(cnKodu, yil = null, ulke = "Turkiye") {
    const dv = await varsayilanYogunluk(cnKodu, ulke);
    if (dv === null) return null;
    const dolayliVar = !NA(dv.dolayli);
    const temel = dolayliVar ? dv.toplam : dv.dogrudan;
    const mu = yil === null ? 0 : markup(yil, dv.sektor);
    return {
      temel, markup: mu, deger: temel * (1 + mu), dolayli_var: dolayliVar,
      etiket: (dolayliVar ? "dogrudan + dolayli" : "dogrudan") +
        (mu > 0 ? `, varsayilan + %${fmtNum(100 * mu, 0)} mark-up` : ""),
      rota: dv.rota, dv,
    };
  }

  /** R: cbam_benchmark_by_cn(cn, "B", yil, rota) */
  async function benchmarkCn(cnKodu, yil = null, rota = null) {
    let cn = rakamlar(cnKodu);
    if (!cn) throw new CbamHata("cn", "CN kodunu girin.");
    if (cn.length > 8) cn = cn.slice(0, 8);
    let s = [];
    try {
      s = (await tablo(`bm/${cn.slice(0, 2)}.json`)).filter((r) => r.cn_kodu === cn);
    } catch { s = []; }
    if (s.length === 0) {
      throw new CbamHata("benchmark-yok",
        `CN ${cn} AB'nin CBAM benchmark tablosunda yok. Ürününüz CBAM kapsamında olmayabilir; kodu kontrol edin.`, { cn });
    }
    const deger = [], gosterge = [], satir = [];
    for (const r of s) {
      const v = sayi(r.bm_column_b);
      if (!NA(v)) { deger.push(v); gosterge.push(r.rota_b ?? ""); satir.push(r); }
    }
    const harf = gosterge.map((g) => (g.match(/[A-L]/g) ?? []).join(""));
    const yilKod = gosterge.map((g) => { const m = g.match(/\(([12])\)$/); return m ? m[1] : ""; });
    let sec = deger.map(() => true);
    let not = "";
    const notlar = []; // ayni notlarin dile cevrilebilir hali (arayuz icin)
    if (deger.length > 1 && harf.some((h) => h !== "")) {
      const istenen = rota == null ? [] : (String(rota).toUpperCase().match(/[A-L]/g) ?? []);
      const uyan = harf.map((h) => istenen.includes(h));
      if (uyan.some(Boolean)) {
        sec = uyan;
      } else {
        sec = harf.map((h) => h === harf[0]);
        const diger = [...new Set(gosterge.filter((_, k) => harf[k] !== harf[0]))];
        not = `Uretim rotasi belirlenemedi; tablodaki ilk rota ${gosterge[0]} kullanildi. ` +
          `Bu kod icin diger rotalar: ${diger.join(" ")} (--rota ile secin).`;
        notlar.push({ tur: "rota-belirsiz", ilk: gosterge[0], digerleri: diger });
      }
    }
    if (yilKod.some((k, i) => sec[i] && k !== "")) {
      const istenenYil = yil === null || yil <= 2027 ? "1" : "2";
      if (sec.some((v, i) => v && yilKod[i] === istenenYil)) sec = sec.map((v, i) => v && yilKod[i] === istenenYil);
      if (yil !== null && yil > 2030) {
        not = (not ? not + " " : "") + "2031 ve sonrasi icin resmi benchmark yayimlanmadi; 2028-30 degeri kullanildi.";
        notlar.push({ tur: "yil-2031" });
      }
    }
    const i = sec.indexOf(true);
    if (i < 0) {
      throw new CbamHata("benchmark-yok", `CN ${cn} için tabloda kullanılabilir benchmark değeri yok.`, { cn });
    }
    const r = satir[i];
    return {
      cn_kodu: r.cn_kodu, aciklama: r.aciklama, sektor: r.sektor,
      birim: meta.fonksiyonel_birim[r.sektor] ?? { birim: "ton urun", standart: true },
      sutun: "B", benchmark: deger[i], rota: gosterge[i], secenek: deger.length, not, notlar,
      kaynak: kaynakMetni(r.kaynak_belge, r.kaynak_yeri), durum: (r.durum ?? "").trim(),
    };
  }

  /** R: run_cbam_mc() + simulate_market() (odenen karbon 0, web yolu) */
  function monteCarlo({ quantity, ei, benchmark, year, carbon0, fx0 }) {
    const b = meta.belirsizlik;
    const n = b.n_sims;
    const horizon = Math.max(year - b.base_year, 0);
    const z = normalUretec(b.seed);
    const fxMu = Math.log((1 + b.inflation_tr) / (1 + b.inflation_eu));
    const kok = Math.sqrt(1 - b.rho ** 2);
    const odenmeyen = 1 - yukumlulukPayi(year);
    const ucretsiz = benchmark * quantity * odenmeyen;
    const cekim = { cost_eur: new Float64Array(n), cost_local: new Float64Array(n),
      cost_local_today: new Float64Array(n), certificates: new Float64Array(n) };
    for (let k = 0; k < n; k++) {
      const theta = b.theta_sdlog > 0 ? Math.exp(b.theta_sdlog * z()) : 1;
      const z1 = z();
      const z2 = b.rho * z1 + kok * z();
      const carbon = carbon0 * Math.exp((b.carbon_mu - 0.5 * b.carbon_sigma ** 2) * horizon +
        b.carbon_sigma * Math.sqrt(horizon) * z1);
      const fx = fx0 * Math.exp((fxMu - 0.5 * b.fx_sigma ** 2) * horizon +
        b.fx_sigma * Math.sqrt(horizon) * z2);
      const cert = Math.max(quantity * (ei * theta) - ucretsiz, 0);
      const eur = cert * carbon;
      cekim.certificates[k] = cert;
      cekim.cost_eur[k] = eur;
      cekim.cost_local[k] = eur * fx;
      cekim.cost_local_today[k] = eur * fx0;
    }
    for (const v of Object.values(cekim)) v.sort();
    return { n_sims: n, horizon, seed: b.seed, cekim,
      q: (alan, p) => yuzdelik(cekim[alan], p) };
  }

  /** R: cbam_estimate() (web yolu: odenen karbon 0, dolayli dahil degil, referans yok) */
  function tahmin({ quantity, ei, benchmark, year, carbon_price, fx_rate = 1, belirsizlik = true }) {
    if (!(quantity >= 0)) throw new CbamHata("miktar", "Miktar negatif olamaz.");
    if (!(ei >= 0)) throw new CbamHata("yogunluk", "Emisyon yoğunluğu negatif olamaz.");
    if (!(benchmark >= 0)) throw new CbamHata("benchmark", "Benchmark negatif olamaz.");
    if (!(carbon_price >= 0)) throw new CbamHata("fiyat", "Karbon fiyatı negatif olamaz.");
    if (!(fx_rate > 0)) throw new CbamHata("kur", "Kur sıfırdan büyük olmalı.");
    if (!Number.isInteger(year) || year < 2026) {
      throw new CbamHata("yil", "Yıl 2026 ya da sonrası olmalı: CBAM mali yükümlülüğü 2026'da başlar.");
    }
    const embedded = quantity * ei;
    const factorY = yukumlulukPayi(year);
    const freeAllocation = benchmark * quantity * (1 - factorY);
    // certificates_due(): free_allocation * cscf (1), odenen karbon dusumu 0
    let certificates = Math.max(embedded - benchmark * quantity * (1 - factorY) * 1 - 0, 0);
    let costEur = certificates * carbon_price;
    let costLocal = costEur * fx_rate;
    // Web yolunda urun referansi yok: is_de_minimis() sektorsuz cagrilir.
    const exempt = quantity <= meta.de_minimis.esik;
    if (exempt) { certificates = 0; costEur = 0; costLocal = 0; }
    const sim = belirsizlik && !exempt && quantity > 0
      ? monteCarlo({ quantity, ei, benchmark, year, carbon0: carbon_price, fx0: fx_rate }) : null;
    return {
      deterministic: {
        embedded, free_allocation: freeAllocation, certificates, cost_eur: costEur,
        cost_local: costLocal, cost_per_tonne: quantity > 0 ? costEur / quantity : 0,
        taxed_share: embedded > 0 ? certificates / embedded : 0, de_minimis: exempt,
      },
      simulation: sim,
      inputs: { quantity, ei_total: ei, benchmark, year, cbam_factor: factorY,
        carbon_price, fx_rate, horizon: Math.max(year - meta.belirsizlik.base_year, 0),
        base_year: meta.belirsizlik.base_year },
    };
  }

  /** R: cbam_yillik_yol(quantity, cn, ulke, carbon_price) */
  async function yillikYol(quantity, cn, ulke, carbonPrice) {
    const satirlar = [];
    for (const y of meta.yillar) {
      let see = null;
      try { see = await varsayilanSee(cn, y, ulke); } catch { see = null; }
      const e = see ? see.deger : NaN;
      const b = (await benchmarkCn(cn, y, see ? see.rota : null)).benchmark;
      const est = tahmin({ quantity, ei: e, benchmark: b, year: y, carbon_price: carbonPrice, belirsizlik: false });
      satirlar.push({ yil: y, faktor: resmiFaktor(y), yogunluk: e, markup: see ? see.markup : 0,
        benchmark: b, sertifika: est.deterministic.certificates, cost_eur: est.deterministic.cost_eur });
    }
    return satirlar;
  }

  /**
   * Web formunun hesabi (R: cbam_web_rapor()'un rapor oncesi adimlari).
   * Hata durumunda CbamHata firlatir.
   */
  async function hesapla({ cn, miktar, yil, ulke = "Turkiye", fiyat = 80, kur = 1 }) {
    const see = await varsayilanSee(cn, yil, ulke);
    if (see === null) {
      throw new CbamHata("tabloda-yok", "Bu kod AB'nin varsayılan değer tablolarında yok. Kodu kontrol edin; mal CBAM kapsamında olmayabilir.");
    }
    const bm = await benchmarkCn(cn, yil, see.rota);
    const sonuc = tahmin({ quantity: miktar, ei: see.deger, benchmark: bm.benchmark, year: yil,
      carbon_price: fiyat, fx_rate: kur });
    const yillik = await yillikYol(miktar, cn, ulke, fiyat);
    return { ...sonuc, see, bm, yillik, veri_surumu: meta.surum, girdi: { cn: rakamlar(cn), miktar, yil, ulke, fiyat, kur } };
  }

  return {
    meta, ulkeler, hesapla,
    // test ve ileri kullanim icin
    varsayilanSee, benchmarkCn, tahmin, yillikYol, resmiFaktor, yukumlulukPayi,
  };
}
