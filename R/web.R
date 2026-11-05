#  stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
#  SPDX-License-Identifier: AGPL-3.0-or-later
#
#  Bu dosya GNU Affero General Public License v3 (ya da sonraki bir surum)
#  kosullariyla dagitilir; HICBIR GARANTI VERILMEZ. Ayrintilar: LICENSE
#  EK SART (AGPL 7(b)): yazar atiflari ve telif bildirimleri korunmalidir.
#  Bkz. NOTICE ve LICENSE-ADDITIONAL-TERMS.md

#  Web sayfasi girisi
#
#  index.html bu fonksiyonu tarayicida (WebR) cagirir. Hesap motorun kendi
#  fonksiyonlariyla yapilir; sayfada ayri bir hesap yoktur.
#
#  Bilincli sinir: formda kendi olcum degeri ve uretim rotasi yoktur. Kendi
#  degeriyle calisan bir EAF ureticisi icin ulkenin varsayilan rotasi yanlis
#  benchmark verir ve sonuc sifira kadar duserdi. Bu ikisi birlikte eklenecek.

#' Varsayilan degerle tam rapor uret
#'
#' @param cn CN ya da TARIC kodu.
#' @param miktar Miktar (ton).
#' @param yil Yil.
#' @param ulke Mense ulke.
#' @param karbon_fiyati Karbon fiyati (EUR/tCO2e).
#' @param kur Doviz kuru (TRY/EUR); 1 ise yalnizca EUR raporlanir.
#' @param dosya Raporun yazilacagi dosya.
#' @param n_sims Simulasyon sayisi.
#' @param seed Rastgele sayi tohumu.
#' @return Raporun HTML metni.
cbam_web_rapor <- function(cn, miktar, yil, ulke = "Turkiye", karbon_fiyati = 80,
                           kur = 1, dosya = tempfile(fileext = ".html"),
                           n_sims = 50000, seed = 2026) {
  see <- cbam_default_see(cn, yil, ulke)
  if (is.null(see)) {
    stop("Bu kod AB tablolarinda yok. Kodu kontrol edin; mal CBAM kapsaminda olmayabilir.")
  }
  bm <- cbam_benchmark_by_cn(cn, "B", yil = yil, rota = see$rota)
  sonuc <- cbam_estimate(
    quantity = miktar, ei_direct = see$deger, benchmark = bm$benchmark,
    year = yil, carbon_price = karbon_fiyati, fx_rate = kur, n_sims = n_sims,
    seed = seed, ei_label = see$etiket, functional_unit = bm$birim,
    kaynaklar = list(
      urun = sprintf("CN %s - %s - mense %s", gsub("[^0-9]", "", cn),
                     see$dv$aciklama, see$dv$mense),
      yogunluk = sprintf(
        "%s, CN %s | temel %s + %%%s mark-up (Rehber No. 3 s.113)",
        see$dv$kaynak, see$dv$cn_kodu, fmt_num(see$temel, 3),
        fmt_num(100 * see$markup, 0)),
      benchmark = sprintf("%s, CN %s, Column %s%s", bm$kaynak, bm$cn_kodu, bm$sutun,
                          if (nzchar(bm$rota)) paste0(" ", bm$rota) else ""),
      ei_temel = see$temel))
  notlar <- c(
    "Emisyon yogunlugu: AB varsayilan degeri + mark-up. Kendi olcum degeri girisi henuz yok.",
    if (nzchar(bm$rota)) sprintf(
      "Uretim rotasi secimi henuz yok: mense icin AB tablosundaki rota %s kullanildi.",
      bm$rota),
    if (isTRUE(see$dv$yedek)) sprintf(
      "%s sayfasinda bu mal icin deger yok; 'Other countries and territories' kullanildi.",
      see$dv$mense),
    if (nzchar(bm$not)) bm$not,
    "Oncul (ara urun) zinciri hesaba katilmaz.",
    sprintf("Karbon fiyati %s EUR/tCO2e kullanici girdisidir, tahmin degildir.",
            fmt_num(karbon_fiyati, 2)),
    if (!is.null(sonuc$simulation)) paste0(
      "Belirsizlik parametreleri aracin varsayilanlaridir, kaynagi DOGRULANMADI."))
  yillik <- cbam_yillik_yol(miktar, cn, ulke, carbon_price = karbon_fiyati)
  cbam_rapor(sonuc, dosya, yillik = yillik, notlar = notlar, olcum_grafigi = FALSE)
  paste(readLines(dosya, warn = FALSE), collapse = "\n")
}
