// stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Gomulebilir CBAM hesaplayicisi. Kullanim (herhangi bir sayfada):
//
//   <div data-cbam-hesaplayici></div>
//   <script type="module" src="https://ilhanselahattin.github.io/stochastic-cbam-engine/hesaplayici.js"></script>
//
// Hesap motorun kendi R kodu ve veri tablolariyla, tarayicida (WebR) yapilir;
// dosyalar bu betigin yanindan okunur. Agir kisim "Hesaplayiciyi baslat"a
// basilinca yuklenir. data-otomatik varsa sayfa acilinca baslar.
//
// Gorunum bilincli olarak dayatilmaz: renk ve yazi tipi sayfadan gelir.
// Her parca cbam- onekli bir sinif tasir; site kendi CSS'iyle bicimlendirir.

const TABAN = new URL(".", import.meta.url);
const WEBR = "https://webr.r-wasm.org/v0.4.2/webr.mjs";
const DOSYALAR = [
  "R/calculator.R", "R/cbam.R", "R/emissions.R", "R/monte_carlo.R", "R/reference.R",
  "R/report.R", "R/stochastic.R", "R/utils.R", "R/web.R",
  "data/benchmarks.csv", "data/urunler.csv", "data/varsayilan_yogunluk.csv", "data/VERSION",
];

// Yalnizca yerlesim; renk, yazi tipi ve kenarliklar sayfaya kalir.
const YERLESIM = `
:where(.cbam-form) { display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:1rem; margin:1rem 0; }
:where(.cbam-form label) { display:block; }
:where(.cbam-form input, .cbam-form select) { display:block; width:100%; box-sizing:border-box; margin-top:.3rem; font:inherit; }
:where(.cbam-ipucu) { display:block; font-size:.8em; opacity:.75; }
:where(.cbam-eylem) { grid-column:1/-1; display:flex; gap:1rem; align-items:center; flex-wrap:wrap; }
:where(.cbam-hata) { white-space:pre-wrap; }
:where(.cbam-rapor) { display:block; width:100%; border:0; background:#fff; }
:where(.cbam-indir) { display:inline-block; margin:.5rem 0; }`;

const FORM = `
<form class="cbam-form" novalidate>
  <label>CN kodu
    <input name="cn" inputmode="numeric" autocomplete="off" value="72081000">
    <span class="cbam-ipucu">Örnek: 72081000 (sıcak haddelenmiş rulo)</span>
  </label>
  <label>Miktar (ton / yıl)
    <input name="miktar" type="number" min="0" step="any" value="1000">
  </label>
  <label>Yıl <select name="yil"></select></label>
  <label>Menşe ülke
    <select name="ulke"><option value="Turkiye">Türkiye</option></select>
  </label>
  <label>Karbon fiyatı (EUR / tCO2e)
    <input name="fiyat" type="number" min="0" step="any" value="80">
    <span class="cbam-ipucu">Varsayımdır, tahmin değildir.</span>
  </label>
  <label>Kur (TRY / EUR)
    <input name="kur" type="number" min="0" step="any" placeholder="İsteğe bağlı">
    <span class="cbam-ipucu">Boş bırakılırsa yalnızca EUR gösterilir.</span>
  </label>
  <div class="cbam-eylem">
    <button class="cbam-hesapla" type="submit" disabled>Hesapla</button>
    <span class="cbam-durum" role="status"></span>
  </div>
</form>
<div class="cbam-hata" role="alert" hidden></div>
<section class="cbam-sonuc" hidden>
  <a class="cbam-indir" download="cbam-rapor.html" href="#">Raporu indir</a>
  <iframe class="cbam-rapor" title="CBAM maliyet raporu" sandbox="allow-same-origin"></iframe>
</section>`;

let webR; // sayfada birden fazla hesaplayici olsa da motor bir kez yuklenir

async function motoruYukle() {
  if (webR) return webR;
  const { WebR } = await import(WEBR);
  const w = new WebR();
  await w.init();
  await w.FS.mkdir("R");
  await w.FS.mkdir("data");
  await Promise.all(DOSYALAR.map(async (f) => {
    const y = await fetch(new URL(f, TABAN));
    if (!y.ok) throw new Error(f + " okunamadı");
    await w.FS.writeFile(f, new Uint8Array(await y.arrayBuffer()));
  }));
  await w.evalRVoid(
    'invisible(lapply(list.files("R", full.names = TRUE), source, encoding = "UTF-8"))');
  return (webR = w);
}

async function kur(kok) {
  kok.innerHTML = FORM;
  const q = (s) => kok.querySelector(s);
  const f = q(".cbam-form");
  const durum = (m) => { q(".cbam-durum").textContent = m; };
  const hata = (m) => { q(".cbam-hata").textContent = m; q(".cbam-hata").hidden = !m; };
  for (let y = 2026; y <= 2034; y++) f.yil.add(new Option(y, y));
  f.yil.value = "2030";

  durum("Hesap motoru yükleniyor. İlk açılış biraz sürebilir.");
  try {
    const w = await motoruYukle();
    const ulkeler = await w.evalRRaw(
      'sort(setdiff(unique(cbam_default_intensities()$ulke), c("Turkiye", CBAM_DIGER_ULKELER)))',
      "string[]");
    for (const u of ulkeler) f.ulke.add(new Option(u.replaceAll(";", ","), u));
    f.ulke.add(new Option("Bilinmiyor / listede yok", "diger"));
    q(".cbam-hesapla").disabled = false;
    durum("");
  } catch (e) {
    durum("");
    return hata("Hesap motoru yüklenemedi: " + e.message);
  }

  f.addEventListener("submit", async (olay) => {
    olay.preventDefault();
    hata("");
    const cn = f.cn.value.replace(/\D/g, "");
    const miktar = Number(f.miktar.value);
    const fiyat = Number(f.fiyat.value);
    const kurDeger = f.kur.value.trim() === "" ? 1 : Number(f.kur.value);
    if (!cn) return hata("CN kodunu girin.");
    if (!(miktar > 0)) return hata("Miktar sıfırdan büyük olmalı.");
    if (f.fiyat.value === "" || !(fiyat >= 0)) return hata("Karbon fiyatı girin.");
    if (!(kurDeger > 0)) return hata("Kur sıfırdan büyük olmalı.");

    q(".cbam-hesapla").disabled = true;
    durum("Hesaplanıyor…");
    try {
      const g = webR.objs.globalEnv;
      await g.bind("g_cn", cn);
      await g.bind("g_miktar", miktar);
      await g.bind("g_yil", Number(f.yil.value));
      await g.bind("g_ulke", f.ulke.value);
      await g.bind("g_fiyat", fiyat);
      await g.bind("g_kur", kurDeger);
      const cikti = await webR.evalRString(`tryCatch(
        cbam_web_rapor(g_cn, g_miktar, g_yil, g_ulke, g_fiyat, g_kur),
        error = function(e) paste0("HATA:", conditionMessage(e)))`);
      if (cikti.startsWith("HATA:")) {
        q(".cbam-sonuc").hidden = true;
        hata(cikti.slice(5));
      } else {
        const c = q(".cbam-rapor");
        c.onload = () => { c.style.height = c.contentDocument.documentElement.scrollHeight + 20 + "px"; };
        c.style.height = "0"; // olcum onceki raporun yuksekliginden etkilenmesin
        c.srcdoc = cikti;
        q(".cbam-indir").href = URL.createObjectURL(new Blob([cikti], { type: "text/html" }));
        q(".cbam-sonuc").hidden = false;
      }
    } catch (e) {
      hata("Hesap yapılamadı: " + e.message);
    } finally {
      q(".cbam-hesapla").disabled = false;
      durum("");
    }
  });
}

const stil = document.createElement("style");
stil.textContent = YERLESIM;
document.head.prepend(stil); // basa: sayfanin kendi CSS'i her zaman ustun gelir

for (const kok of document.querySelectorAll("[data-cbam-hesaplayici]")) {
  if (kok.hasAttribute("data-otomatik")) { kur(kok); continue; }
  const b = document.createElement("button");
  b.type = "button";
  b.className = "cbam-baslat";
  b.textContent = "Hesaplayıcıyı başlat";
  b.addEventListener("click", () => kur(kok), { once: true });
  kok.replaceChildren(b);
}
