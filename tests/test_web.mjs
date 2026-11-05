// stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Bu dosya GNU Affero General Public License v3 (ya da sonraki bir surum)
// kosullariyla dagitilir; HICBIR GARANTI VERILMEZ. Ayrintilar: LICENSE
// EK SART (AGPL 7(b)): yazar atiflari ve telif bildirimleri korunmalidir.
// Bkz. NOTICE ve LICENSE-ADDITIONAL-TERMS.md
//
// Tarayici motoru R motoruyla ayni sonucu veriyor mu?
//
// Calistirma:  node tests/test_web.mjs   (proje kokunden; Node 18+, paket gerekmez)
//
// data/web/ornekler.json, R motorunun ornek girdilerdeki ciktilaridir
// (tools/web_veri.R). Kurallar:
//   - Kesin hesap (yogunluk, benchmark, sertifika, maliyet, yillik yol)
//     BIREBIR ayni olmali: tolerans yok, === karsilastirmasi.
//   - Hata vakalarinda ayni turde hata olmali.
//   - Belirsizlik yuzdelikleri farkli rastgele sayi ureticisiyle cekildigi
//     icin istatistiksel tolerans icinde olmali.

import { readFile } from "node:fs/promises";
import { motorOlustur, fmtNum, CbamHata } from "../cbam-motor.js";

const KOK = new URL("../data/web/", import.meta.url);
const yukle = async (yol) => JSON.parse(await readFile(new URL(yol, KOK), "utf8"));
const motor = await motorOlustur(yukle);
const altin = await yukle("ornekler.json");

let gecti = 0, kaldi = 0;
const kalanlar = [];
const kontrol = (etiket, kosul, ayrinti = "") => {
  if (kosul) { gecti++; return; }
  kaldi++;
  kalanlar.push(`  [KALDI] ${etiket}${ayrinti ? "\n          " + ayrinti : ""}`);
};
const ayni = (a, b) => a === b || (Number.isNaN(a) && b === null) || (a === "" && b === null);

// --- 1. Veri surumu: test edilen tablolar R'nin urettigiyle ayni mi ---------
kontrol("veri surumu meta.json = ornekler.json", motor.meta.surum === altin.surum,
  `${motor.meta.surum} / ${altin.surum}`);

// --- 2. Sayi bicimi (R: fmt_num) ---------------------------------------------
for (const [x, d, beklenen] of [[196068, 0, "196.068"], [2450.85, 1, "2.450,8"], [0.515, 3, "0,515"],
  [49017000, 0, "49.017.000"], [-705.6, 1, "-705,6"], [196068.5, 0, "196.069"], [0, 2, "0,00"]]) {
  kontrol(`fmtNum(${x}, ${d})`, fmtNum(x, d) === beklenen, `${fmtNum(x, d)} != ${beklenen}`);
}

// --- 3. Altin vakalar ---------------------------------------------------------
const hataTuru = (m) =>
  m.startsWith("TABLODA_YOK") ? "tabloda-yok"
    : m.includes("TARIC") ? "taric"
      : m.includes("benchmark tablosunda yok") ? "benchmark-yok"
        : "bilinmeyen: " + m.split("\n")[0];

let mcEnBuyuk = 0;
for (const v of altin.vakalar) {
  const g = v.girdi;
  const ad = `${g.cn} ${g.ulke} ${g.yil} ${g.miktar} t ${g.fiyat} EUR kur ${g.kur}`;
  let s, hata = null;
  try {
    s = await motor.hesapla(g);
  } catch (e) {
    if (!(e instanceof CbamHata)) throw e;
    hata = e;
  }
  if (v.hata) {
    kontrol(`${ad}: hata turu`, hata && hata.kod === hataTuru(v.hata),
      `R: ${hataTuru(v.hata)} | JS: ${hata ? hata.kod : "hata yok"}`);
    continue;
  }
  if (hata) { kontrol(`${ad}: hesap`, false, `JS hata verdi: ${hata.message}`); continue; }

  for (const k of ["temel", "markup", "deger", "etiket", "rota", "dolayli_var"]) {
    kontrol(`${ad}: see.${k}`, ayni(s.see[k], v.see[k]), `${s.see[k]} != ${v.see[k]}`);
  }
  for (const k of ["cn_kodu", "eslesme", "mense", "yedek", "sektor", "aciklama", "kaynak"]) {
    kontrol(`${ad}: dv.${k}`, ayni(s.see.dv[k], v.see[k]), `${s.see.dv[k]} != ${v.see[k]}`);
  }
  for (const k of ["benchmark", "rota", "not", "cn_kodu", "sektor", "kaynak", "secenek"]) {
    kontrol(`${ad}: bm.${k}`, ayni(s.bm[k], v.bm[k]), `${s.bm[k]} != ${v.bm[k]}`);
  }
  kontrol(`${ad}: bm.birim`, s.bm.birim.birim === v.bm.birim);
  for (const k of ["embedded", "free_allocation", "certificates", "cost_eur", "cost_local",
    "cost_per_tonne", "taxed_share", "de_minimis"]) {
    kontrol(`${ad}: det.${k}`, s.deterministic[k] === v.det[k], `${s.deterministic[k]} != ${v.det[k]}`);
  }
  kontrol(`${ad}: cbam_factor`, s.inputs.cbam_factor === v.det.cbam_factor);
  kontrol(`${ad}: horizon`, s.inputs.horizon === v.det.horizon);
  kontrol(`${ad}: yillik satir sayisi`, s.yillik.length === v.yillik.length);
  s.yillik.forEach((r, i) => {
    for (const k of Object.keys(v.yillik[i])) {
      kontrol(`${ad}: yillik ${r.yil}.${k}`, ayni(r[k], v.yillik[i][k]), `${r[k]} != ${v.yillik[i][k]}`);
    }
  });

  kontrol(`${ad}: belirsizlik var/yok`, (s.simulation === null) === (v.mc === null));
  if (s.simulation && v.mc) {
    const p = { cost_eur: [.05, .25, .5, .75, .95], cost_local_today: [.05, .5, .95],
      cost_local: [.5, .95], certificates: [.05, .5, .95] };
    for (const [alan, olasilik] of Object.entries(p)) {
      const ust = Math.abs(v.mc[alan][v.mc[alan].length - 1]);
      olasilik.forEach((pp, i) => {
        const r = v.mc[alan][i], j = s.simulation.q(alan, pp);
        // Goreli %4; sifira yakin alt yuzdeliklerde ust degerin %0,5'i taban.
        const tol = Math.max(0.04 * Math.abs(r), 0.005 * ust, 1e-9);
        const sapma = Math.abs(j - r) / Math.max(Math.abs(r), 0.005 * ust, 1e-9);
        // Raporlanan sapma: yalnizca anlamli buyuklukteki yuzdelikler (ust degerin %5'i ustu)
        if (Math.abs(r) > 0.05 * ust) mcEnBuyuk = Math.max(mcEnBuyuk, sapma);
        kontrol(`${ad}: mc ${alan} q${pp}`, Math.abs(j - r) <= tol, `JS ${j} / R ${r}`);
      });
    }
  }
}

// --- 4. Ayni girdi ayni sonucu verir (tekrarlanabilirlik) ---------------------
{
  const g = { cn: "72081000", miktar: 1000, yil: 2030, ulke: "Turkiye", fiyat: 80, kur: 1 };
  const a = await motor.hesapla(g), b = await motor.hesapla(g);
  kontrol("ayni girdi -> ayni belirsizlik sonucu",
    a.simulation.q("cost_eur", 0.95) === b.simulation.q("cost_eur", 0.95));
}

console.log(kalanlar.join("\n"));
console.log("=====================================");
console.log(`Toplam: ${gecti} gecti, ${kaldi} kaldi  (${altin.vakalar.length} vaka; ` +
  `belirsizlikte en buyuk goreli sapma %${(100 * mcEnBuyuk).toFixed(2)})`);
console.log("=====================================");
process.exit(kaldi ? 1 : 0);
