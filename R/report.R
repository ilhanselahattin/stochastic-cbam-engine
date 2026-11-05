#  stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
#  SPDX-License-Identifier: AGPL-3.0-or-later
#
#  Bu dosya GNU Affero General Public License v3 (ya da sonraki bir surum)
#  kosullariyla dagitilir; HICBIR GARANTI VERILMEZ. Ayrintilar: LICENSE
#  EK SART (AGPL 7(b)): yazar atiflari ve telif bildirimleri korunmalidir.
#  Bkz. NOTICE ve LICENSE-ADDITIONAL-TERMS.md

#  Rapor Katmani
#
#  cbam_estimate() ciktisini paylasilabilir tek bir HTML dosyasina cevirir.
#  Ihracatcinin yonetim kuruluna, denetcisine ya da musterisine goturebilecegi
#  belge budur.
#
#  Tasarim kurallari:
#    - Tek dosya, disaridan hicbir sey yuklemez. Internet olmadan acilir,
#      e-postayla gonderilir, tarayicidan PDF'e basilir.
#    - Sifir bagimlilik: HTML metin olarak uretilir, grafik satir ici SVG'dir.
#    - Hesabin her ara adimi raporda gorunur. Rapor bir sonuc degil, bir
#      muhakeme zinciridir; denetlenebilirlik urunun kendisidir.
#    - Kunye her rapora gomulu gelir (AGPL 7(b) atif sarti).

#' HTML'de guvenli metin
#'
#' @param x Karakter vektor.
#' @return Ozel karakterleri kacisli karakter vektor.
html_kacis <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub("\"", "&quot;", x, fixed = TRUE)
}

#' Dagilim histogramini satir ici SVG olarak ciz
#'
#' Harici grafik paketi kullanilmaz; cubuklar dogrudan SVG dikdortgeni olarak
#' uretilir. Boylece rapor tek dosya olarak kendi kendine yeter.
#'
#' @param v Sayisal vektor (maliyet cekilisleri).
#' @param genislik SVG genisligi (piksel).
#' @param yukseklik SVG yuksekligi (piksel).
#' @return SVG karakter dizisi.
svg_histogram <- function(v, genislik = 720, yukseklik = 220) {
  v <- v[is.finite(v)]
  if (length(v) < 2 || diff(range(v)) == 0) {
    return("<p class=\"not\">Dagilim cizilemedi: deger sacilimi yok.</p>")
  }
  # Ust %2'lik kuyruk grafigi okunamaz hale getiriyor; cizimden kirpilir.
  ust <- stats::quantile(v, 0.98)
  vg <- v[v <= ust]
  h <- graphics::hist(vg, breaks = 40, plot = FALSE)
  if (max(h$counts) == 0) return("")

  sol <- 8; sag <- 8; alt <- 26
  ic_g <- genislik - sol - sag
  ic_y <- yukseklik - alt
  n <- length(h$counts)
  bar_g <- ic_g / n
  olcek <- ic_y / max(h$counts)

  cubuklar <- vapply(seq_len(n), function(i) {
    yuk <- h$counts[i] * olcek
    sprintf(paste0('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" class="cubuk">',
                   '<title>%s - %s EUR: senaryolarin %%%s</title></rect>'),
            sol + (i - 1) * bar_g, ic_y - yuk, max(bar_g - 1, 0.5), yuk,
            fmt_num(h$breaks[i]), fmt_num(h$breaks[i + 1]),
            fmt_num(100 * h$counts[i] / length(v), 1))
  }, character(1))

  # Medyan ve %95 cizgileri
  q <- stats::quantile(v, c(0.50, 0.95))
  konum <- function(x) {
    sol + (x - min(h$breaks)) / (max(h$breaks) - min(h$breaks)) * ic_g
  }
  cizgiler <- character(0)
  for (k in seq_along(q)) {
    if (q[k] >= min(h$breaks) && q[k] <= max(h$breaks)) {
      x <- konum(q[k])
      etiket <- if (k == 1) "medyan" else "%95"
      cizgiler <- c(cizgiler, sprintf(
        paste0('<line x1="%.1f" y1="0" x2="%.1f" y2="%.1f" class="isaret"/>',
               '<text x="%.1f" y="%.1f" class="isaret-etiket">%s</text>'),
        x, x, ic_y, x + 4, 12, etiket))
    }
  }

  paste0(
    sprintf('<svg viewBox="0 0 %d %d" class="grafik" role="img" ',
            genislik, yukseklik),
    'aria-label="CBAM maliyeti olasilik dagilimi">',
    paste(cubuklar, collapse = ""),
    paste(cizgiler, collapse = ""),
    sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" class="eksen"/>',
            sol, ic_y, genislik - sag, ic_y),
    sprintf('<text x="%d" y="%d" class="eksen-etiket">%s</text>',
            sol, yukseklik - 6, html_kacis(fmt_num(min(h$breaks)))),
    sprintf('<text x="%d" y="%d" class="eksen-etiket" text-anchor="end">%s</text>',
            genislik - sag, yukseklik - 6, html_kacis(fmt_num(max(h$breaks)))),
    '</svg>'
  )
}

#' Kisa para gosterimi (eksen ve etiketler icin)
#'
#' @param x Tutar.
#' @return "12,3 M" / "450 bin" / "820" bicimi.
kisa_tutar <- function(x) {
  if (abs(x) >= 1e6) return(paste0(fmt_num(x / 1e6, 1), " M"))
  if (abs(x) >= 1e4) return(paste0(fmt_num(x / 1e3, 0), " bin"))
  fmt_num(x)
}

#' Ust ucu yuvarlatilmis dikey cubuk (taban kare, uc 4 px yuvarlak)
#'
#' @return SVG path.
svg_cubuk <- function(x, y, g, taban, r = 4) {
  h <- taban - y
  if (h <= 0) return("")
  r <- min(r, h, g / 2)
  sprintf("M%.1f,%.1f V%.1f Q%.1f,%.1f %.1f,%.1f H%.1f Q%.1f,%.1f %.1f,%.1f V%.1f Z",
          x, taban, y + r, x, y, x + r, y, x + g - r, x + g, y, x + g, y + r, taban)
}

#' Yillara gore CBAM maliyeti (2026-2034) - SVG cubuk grafik
#'
#' Tek seri; secili yil ve son yil dogrudan etiketlenir, her cubugun ustune
#' gelince tam deger gorunur (SVG title - betik yok, rapor cevrimdisi kalir).
#'
#' @param yol \code{yil}, \code{cost_eur} sutunlu data.frame.
#' @param secili Raporun yili.
#' @return SVG metni.
svg_yillik <- function(yol, secili, genislik = 720, yukseklik = 250) {
  if (is.null(yol) || nrow(yol) == 0 || max(yol$cost_eur) <= 0) return("")
  sol <- 58; sag <- 10; ust <- 24; alt <- 28
  taban <- yukseklik - alt
  ic_g <- genislik - sol - sag
  tik <- pretty(c(0, max(yol$cost_eur)), n = 4)
  ymax <- max(tik)
  yk <- function(v) taban - v / ymax * (taban - ust)
  slot <- ic_g / nrow(yol)
  g <- min(24, slot * 0.55)

  izgara <- paste(vapply(tik, function(t) sprintf(paste0(
    '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" class="%s"/>',
    '<text x="%d" y="%.1f" class="eksen-etiket" text-anchor="end">%s</text>'),
    sol, yk(t), genislik - sag, yk(t), if (t == 0) "eksen" else "izgara",
    sol - 6, yk(t) + 4, html_kacis(kisa_tutar(t))), ""), collapse = "")

  cubuk <- paste(vapply(seq_len(nrow(yol)), function(k) {
    x <- sol + (k - 1) * slot + (slot - g) / 2
    v <- yol$cost_eur[k]; y <- yol$yil[k]
    etiket <- if (y == secili || k == nrow(yol)) sprintf(
      '<text x="%.1f" y="%.1f" class="deger-etiket" text-anchor="middle">%s</text>',
      x + g / 2, yk(v) - 6, html_kacis(kisa_tutar(v))) else ""
    sprintf(paste0('<g><path d="%s" class="seri"/>',
                   '<rect x="%.1f" y="%d" width="%.1f" height="%.1f" class="isabet">',
                   '<title>%d: %s EUR</title></rect>%s',
                   '<text x="%.1f" y="%d" class="eksen-etiket%s" text-anchor="middle">%d</text></g>'),
            svg_cubuk(x, yk(v), g, taban), sol + (k - 1) * slot, ust, slot,
            taban - ust, y, fmt_num(v), etiket, x + g / 2, yukseklik - 8,
            if (y == secili) " secili" else "", y)
  }, ""), collapse = "")

  paste0(sprintf('<svg viewBox="0 0 %d %d" class="grafik" role="img" ', genislik, yukseklik),
         'aria-label="Yillara gore CBAM maliyeti, 2026-2034">', izgara, cubuk, '</svg>')
}

#' Emisyon yogunluguna gore maliyet - SVG cizgi grafik
#'
#' Maliyet = max(0; M x SEE - SEFA x M - odenen) x fiyat; yogunlugun
#' parcali dogrusal fonksiyonu. Esik (yukun basladigi yogunluk) ve bu hesabin
#' yogunlugu isaretlenir. Kendi olcumunu yaptirmayi dusunen icin.
#'
#' @return SVG metni.
svg_yogunluk <- function(i, ei_temel = NULL, genislik = 720, yukseklik = 250) {
  esik <- i$benchmark * (1 - i$cbam_factor) +
    if (i$carbon_price_paid > 0) i$carbon_price_paid / i$cbam_reference_price else 0
  ust_x <- max(i$ei_total * 1.15, esik * 1.5)
  maliyet <- function(e) max(0, (e - esik) * i$quantity) * i$carbon_price
  sol <- 58; sag <- 12; ust <- 24; alt <- 40
  taban <- yukseklik - alt
  ic_g <- genislik - sol - sag
  tik <- pretty(c(0, maliyet(ust_x)), n = 4); ymax <- max(tik)
  xk <- function(e) sol + e / ust_x * ic_g
  yk <- function(v) taban - v / ymax * (taban - ust)
  xt <- pretty(c(0, ust_x), n = 6); xt <- xt[xt <= ust_x]

  izgara <- paste(vapply(tik, function(t) sprintf(paste0(
    '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" class="%s"/>',
    '<text x="%d" y="%.1f" class="eksen-etiket" text-anchor="end">%s</text>'),
    sol, yk(t), genislik - sag, yk(t), if (t == 0) "eksen" else "izgara",
    sol - 6, yk(t) + 4, html_kacis(kisa_tutar(t))), ""), collapse = "")
  xetiket <- paste(sprintf(
    '<text x="%.1f" y="%d" class="eksen-etiket" text-anchor="middle">%s</text>',
    xk(xt), yukseklik - 22, vapply(xt, function(e) fmt_num(e, 1), "")), collapse = "")

  cizgi <- sprintf('<polyline points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" class="seri-cizgi"/>',
                   xk(0), yk(0), xk(esik), yk(0), xk(ust_x), yk(maliyet(ust_x)))
  # Cizgi saga dogru yukseldigi icin bos alan noktanin sol-ustu (cizginin
  # ustu) ve sag-alti (cizginin alti); etiketler oraya konur.
  nokta <- function(e, ad, yukari = TRUE) {
    v <- maliyet(e)
    sprintf(paste0('<g><circle cx="%.1f" cy="%.1f" r="5" class="nokta"/>',
                   '<circle cx="%.1f" cy="%.1f" r="12" class="isabet">',
                   '<title>%s: %s tCO2e/t -> %s EUR</title></circle>',
                   '<text x="%.1f" y="%.1f" class="deger-etiket" text-anchor="%s">%s</text></g>'),
            xk(e), yk(v), xk(e), yk(v), html_kacis(ad), fmt_num(e, 3), fmt_num(v),
            xk(e) + if (yukari) -9 else 10, yk(v) + if (yukari) -9 else 20,
            if (yukari) "end" else "start",
            html_kacis(sprintf("%s %s", ad, fmt_num(e, 3))))
  }
  isaretler <- c(nokta(i$ei_total, "bu hesap"),
                 sprintf(paste0('<g><circle cx="%.1f" cy="%.1f" r="5" class="nokta"/>',
                                '<text x="%.1f" y="%.1f" class="deger-etiket" ',
                                'text-anchor="end">yuk baslar: %s</text></g>'),
                         xk(esik), yk(0), xk(esik) - 9, yk(0) - 9, fmt_num(esik, 3)))
  if (!is.null(ei_temel) && abs(ei_temel - i$ei_total) > 1e-9) {
    isaretler <- c(isaretler, nokta(ei_temel, "mark-up'siz", FALSE))
  }
  paste0(sprintf('<svg viewBox="0 0 %d %d" class="grafik" role="img" ', genislik, yukseklik),
         'aria-label="Emisyon yogunluguna gore CBAM maliyeti">', izgara, xetiket,
         sprintf('<text x="%.1f" y="%d" class="eksen-etiket" text-anchor="middle">%s</text>',
                 sol + ic_g / 2, yukseklik - 4, "emisyon yogunlugu (tCO2e / ton urun)"),
         cizgi, paste(isaretler, collapse = ""), '</svg>')
}

#' Hesap tablosu satiri
#'
#' @param etiket Satir etiketi.
#' @param formul Acik formul metni.
#' @param deger Bicimlenmis sonuc.
#' @param birim Birim.
#' @param sinif Ek CSS sinifi.
#' @return HTML satiri.
rapor_satir <- function(etiket, formul, deger, birim, sinif = "") {
  sprintf(paste0('<tr class="%s"><td class="etiket">%s</td>',
                 '<td class="formul">%s</td>',
                 '<td class="deger">%s</td><td class="birim">%s</td></tr>'),
          sinif, html_kacis(etiket), html_kacis(formul),
          html_kacis(deger), html_kacis(birim))
}

#' CBAM hesabindan HTML rapor uret
#'
#' @param x \code{cbam_estimate()} ciktisi.
#' @param dosya Yazilacak HTML dosyasinin yolu.
#' @param baslik Rapor basligi.
#' @param firma Firma adi (istege bagli, raporun ustunde gorunur).
#' @param yillik Istege bagli 2026-2034 tablosu (\code{yil}, \code{faktor},
#'   \code{yogunluk}, \code{markup}, \code{benchmark}, \code{sertifika},
#'   \code{cost_eur}); verilirse yillara gore maliyet grafigi cizilir.
#' @param olcum_grafigi FALSE ise kendi olcumuyle maliyet grafigi cizilmez. Esigi
#'   rotaya bagli oldugundan, rota secimi olmayan web formu bunu gostermez.
#' @param notlar Istege bagli metin vektoru; "Varsayimlar" kutusunda gosterilir
#'   (ornek: gosterim icin secilen parametreler).
#' @return Yazilan dosyanin yolu (gorunmez).
cbam_rapor <- function(x, dosya, baslik = "CBAM Maliyet Raporu", firma = NULL,
                       yillik = NULL, notlar = NULL, olcum_grafigi = TRUE) {
  if (!inherits(x, "cbam_estimate")) {
    stop("x, cbam_estimate() ciktisi olmali.")
  }
  i <- x$inputs
  d <- x$deterministic
  r <- x$reference
  tarih <- format(Sys.Date(), "%d.%m.%Y")

  kalan <- 1 - i$cbam_factor
  # Kucuk miktarlarda tam sayiya yuvarlamak tabloyu "16 - 6 = 9" gibi
  # tutarsiz gosterir; 1.000 tCO2e altinda bir ondalik.
  fmt_ton <- function(v) fmt_num(v, if (abs(v) < 1000) 1 else 0)
  uyari <- if (!is.null(r)) cbam_dogrulama_uyarisi(r) else NULL

  # --- Ozet kartlari ---
  kartlar <- c(
    sprintf('<div class="kart"><div class="kart-deger">%s</div>
             <div class="kart-etiket">EUR / yil</div></div>',
            fmt_num(d$cost_eur)),
    sprintf('<div class="kart"><div class="kart-deger">%s</div>
             <div class="kart-etiket">EUR / ton</div></div>',
            fmt_num(d$cost_per_tonne, 2)),
    sprintf('<div class="kart"><div class="kart-deger">%s</div>
             <div class="kart-etiket">tCO2e sertifika</div></div>',
            fmt_num(d$certificates)),
    sprintf('<div class="kart"><div class="kart-deger">%%%s</div>
             <div class="kart-etiket">emisyonun vergilenen orani</div></div>',
            fmt_num(100 * d$taxed_share, 1))
  )

  # --- Hesap tablosu ---
  satirlar <- c(
    rapor_satir("Gomulu emisyon",
                sprintf("%s ton x %s", fmt_num(i$quantity),
                        fmt_num(i$ei_total, 3)),
                fmt_ton(d$embedded), "tCO2e"),
    rapor_satir("Ucretsiz tahsisat",
                sprintf("%s x %s x %s", fmt_num(i$benchmark, 3),
                        fmt_num(i$quantity), fmt_num(kalan, 3)),
                paste0("−", fmt_ton(d$free_allocation)), "tCO2e")
  )
  if (i$carbon_price_paid > 0) {
    satirlar <- c(satirlar,
      rapor_satir("Mensede odenen karbon", "",
                  paste0("−", fmt_num(i$quantity * i$carbon_price_paid /
                                        i$cbam_reference_price)), "tCO2e"))
  }
  # De minimis: sertifika 0'a cekilir; tabloda nedeni yazilmazsa okuyan
  # "16 - 6 = 0" gorup hesap hatasi sanar.
  odenen <- if (i$carbon_price_paid > 0) {
    i$quantity * i$carbon_price_paid / i$cbam_reference_price
  } else 0
  esik_ustu <- max(0, d$embedded - d$free_allocation - odenen)
  if (isTRUE(d$de_minimis)) {
    satirlar <- c(satirlar,
      rapor_satir("De minimis muafiyeti",
                  sprintf("%s ton <= 50 ton", fmt_num(i$quantity)),
                  paste0("−", fmt_ton(esik_ustu)), "tCO2e"))
  }
  satirlar <- c(satirlar,
    rapor_satir("Sertifika yukumlulugu", "", fmt_ton(d$certificates),
                "tCO2e", "toplam"),
    rapor_satir("CBAM maliyeti",
                sprintf("%s x %s EUR", fmt_ton(d$certificates),
                        fmt_num(i$carbon_price, 2)),
                fmt_num(d$cost_eur), "EUR", "toplam"))
  if (i$fx_rate != 1) {
    satirlar <- c(satirlar,
      rapor_satir("", sprintf("x %s TRY/EUR (bugunku kur)",
                              fmt_num(i$fx_rate, 2)),
                  fmt_num(d$cost_local), "TRY"))
  }

  # --- Grafikler: yillara gore maliyet + yogunluga gore maliyet ---
  # Her grafigin altinda ayni veri tablo olarak durur (erisilebilirlik).
  tablo <- function(bas, satir) {
    sprintf(paste0('<details><summary>Tablo olarak goster</summary><table>',
                   '<thead><tr>%s</tr></thead><tbody>%s</tbody></table></details>'),
            paste(sprintf("<th>%s</th>", bas), collapse = ""),
            paste(satir, collapse = ""))
  }
  grafikler <- ""
  if (!isTRUE(d$de_minimis) && !is.null(yillik) && nrow(yillik) > 0) {
    markup_notu <- if (any(yillik$markup > 0)) {
      ", varsayilan degerin mark-up'i (2026 %10, 2027 %20, 2028+ %30)"
    } else ""
    grafikler <- paste0(grafikler, sprintf('
<section>
  <h2>Yillara gore CBAM maliyeti, 2026-2034</h2>
  <p>Ayni miktar, ayni karbon fiyati (%s EUR/tCO2e). Yalnizca mevzuat takvimi
  degisiyor: ucretsiz tahsisatin azalmasi%s ve yila bagli benchmark.
  Fiyat ve kur belirsizligi asagidaki dagilim bolumundedir.</p>
  %s
  <p class="not">Cubugun ustune gelince tutar gorunur. Her yil ayni karbon fiyati
  varsayilmistir; gercek maliyet o yilin sertifika fiyatina baglidir.</p>
  %s
</section>', fmt_num(i$carbon_price, 2), html_kacis(markup_notu),
      svg_yillik(yillik, i$year),
      tablo(c("Yil", "CBAM faktoru", "Yogunluk", "Benchmark", "Sertifika (tCO2e)",
              "EUR"),
            sprintf(paste0('<tr><td>%d</td><td>%%%s</td><td>%s</td><td>%s</td>',
                           '<td class="deger">%s</td><td class="deger">%s</td></tr>'),
                    yillik$yil, fmt_num(100 * yillik$faktor, 1),
                    fmt_num(yillik$yogunluk, 3), fmt_num(yillik$benchmark, 3),
                    fmt_num(yillik$sertifika), fmt_num(yillik$cost_eur)))))
  }
  if (isTRUE(olcum_grafigi) && !isTRUE(d$de_minimis) && d$embedded > 0) {
    esik <- i$benchmark * (1 - i$cbam_factor) +
      if (i$carbon_price_paid > 0) i$carbon_price_paid / i$cbam_reference_price else 0
    adim <- seq(0, max(i$ei_total * 1.15, esik * 1.5), length.out = 7)
    grafikler <- paste0(grafikler, sprintf('
<section>
  <h2>Kendi olcumunuzle maliyet</h2>
  <p>%d icin maliyet emisyon yogunlugunun dogrusal fonksiyonudur: %s tCO2e/t
  esiginin altinda yuk yoktur; ustunde her 0,1 tCO2e/t azalma yilda
  <strong>%s EUR</strong> kazandirir. Dogrulanmis kendi olcumunuz varsayilan
  degerin yerine gecer ve ona mark-up uygulanmaz. Esik bu hesaptaki benchmark
  degerine goredir; farkli bir uretim rotasinda degisir.</p>
  %s
  %s
</section>', i$year, fmt_num(esik, 3),
      fmt_num(0.1 * i$quantity * i$carbon_price),
      svg_yogunluk(i, i$kaynaklar$ei_temel),
      tablo(c("Yogunluk (tCO2e/t)", "EUR / yil"),
            sprintf('<tr><td>%s</td><td class="deger">%s</td></tr>',
                    fmt_num(adim, 3),
                    fmt_num(pmax(0, (adim - esik) * i$quantity) * i$carbon_price)))))
  }
  notlar_html <- if (length(notlar)) {
    sprintf('<div class="bilgi"><strong>Varsayimlar</strong><ul>%s</ul></div>',
            paste(sprintf("<li>%s</li>", html_kacis(notlar)), collapse = ""))
  } else ""

  # --- Belirsizlik bolumu ---
  belirsizlik <- ""
  if (!is.null(x$simulation)) {
    v <- x$simulation$draws$cost_eur
    q <- stats::quantile(v, c(0.05, 0.25, 0.50, 0.75, 0.95))
    yuzdelik <- paste(vapply(seq_along(q), function(k) {
      sprintf('<tr><td>%s</td><td class="deger">%s</td></tr>',
              c("%5 (iyimser)", "%25", "Medyan", "%75",
                "%95 (VaR)")[k], fmt_num(q[k]))
    }, character(1)), collapse = "")

    ufuk_notu <- if (i$horizon == 0) {
      "Yukumluluk yili baz yil ile ayni; fiyat ve kur belirsizligi yok.
       Asagidaki aralik yalnizca tesis verimliligi sacilimindan gelir."
    } else {
      sprintf("Karbon fiyati ve doviz kuru %g yillik ufukta Geometrik Brown
               Hareketi ile, tesis verimliligi lognormal dagilimla oynatildi.
               %s bagimsiz senaryo kosuldu.", i$horizon, fmt_num(i$n_sims))
    }

    belirsizlik <- sprintf('
<section>
  <h2>Belirsizlik</h2>
  <p>%s</p>
  %s
  <div class="iki-sutun">
    <table class="yuzdelik">
      <thead><tr><th>Senaryo</th><th class="deger">EUR / yil</th></tr></thead>
      <tbody>%s</tbody>
    </table>
    <div class="yorum">
      <p><strong>Butcelenmesi gereken rakam %%95 senaryosudur.</strong>
      Medyan zamanin yarisinda asilir; tek bir sayiya gore butce yapan
      taraf, ihtimallerin yarisinda yanilir.</p>
      <p class="not">Grafikte ust %%2&#39;lik kuyruk okunabilirlik icin
      kirpilmistir; yuzdelik tablosu tam dagilimdan hesaplanmistir.</p>
    </div>
  </div>
</section>', ufuk_notu, svg_histogram(v), yuzdelik)
  }

  # --- Uyari bloku ---
  uyari_html <- if (!is.null(uyari)) {
    sprintf('<div class="uyari"><strong>%s</strong><ul>%s</ul></div>',
            html_kacis(uyari[1]),
            paste(sprintf("<li>%s</li>", html_kacis(trimws(uyari[-1]))),
                  collapse = ""))
  } else ""
  if (isTRUE(d$de_minimis)) {
    uyari_html <- paste0(uyari_html, sprintf(paste0(
      '<div class="uyari"><strong>De minimis muafiyeti: bu miktar icin CBAM ',
      'yukumlulugu dogmuyor.</strong><ul>',
      '<li>%s ton, 50 ton net kutle esigini asmiyor (CBAM Tuzugu Md. 2a, ',
      'Ek VII nokta 1; Rehber No. 1 s.23).</li>',
      '<li>Esik ITHALATCI BASINA, takvim yili boyunca KUMULATIF ve tum CN ',
      'kodlari toplaminda gecerlidir.</li>',
      '<li>Ithalatcinin %d yilindaki toplami 50 tonu asarsa o yilin TUM ',
      'ithalati yukumlu olur - esik asilmadan once gelenler dahil. O durumda ',
      'bu %s ton icin yuk: <strong>%s tCO2e, %s EUR</strong> ',
      '(%s EUR/tCO2e ile).</li>',
      '<li>Muafiyet elektrik ve hidrojene uygulanmaz.</li></ul></div>'),
      fmt_num(i$quantity), i$year, fmt_num(i$quantity),
      fmt_num(esik_ustu, 1), fmt_num(esik_ustu * i$carbon_price, 2),
      fmt_num(i$carbon_price, 2)))
  }

  # --- Provenans ---
  # Kaynak sirasi: urun referansi > hesaba verilen kaynaklar > kullanici.
  # v1.0.0'da CN kodu yolunda resmi degerler "kullanici girdisi" gorunuyordu.
  kaynak <- function(alan) {
    if (!is.null(r)) return(r[[paste0(alan, "_kaynak")]])
    k <- i$kaynaklar[[alan]]
    if (is.null(k)) "kullanici girdisi" else k
  }
  prov <- c(
    sprintf("<tr><td>Ihracat miktari</td><td>%s ton/yil</td><td></td></tr>",
            fmt_num(i$quantity)),
    sprintf("<tr><td>Emisyon yogunlugu</td><td>%s tCO2e/ton</td><td>%s</td></tr>",
            fmt_num(i$ei_direct, 3),
            html_kacis(kaynak("yogunluk"))),
    sprintf("<tr><td>AB ETS benchmark</td><td>%s tCO2e/ton</td><td>%s</td></tr>",
            fmt_num(i$benchmark, 3),
            html_kacis(kaynak("benchmark"))),
    sprintf(paste0("<tr><td>CBAM faktoru (%d)</td><td>%%%s</td><td>ucretsiz tahsisatin ",
                   "kalan payi; yukumluluk payi %%%s. Rehber No. 4 Tablo 2-1 ",
                   "(CIR (EU) 2025/2620)</td></tr>"),
            i$year, fmt_num(100 * (1 - i$cbam_factor), 1),
            fmt_num(100 * i$cbam_factor, 1)),
    sprintf("<tr><td>Karbon fiyati</td><td>%s EUR/tCO2e</td><td>kullanici girdisi</td></tr>",
            fmt_num(i$carbon_price, 2)),
    if (i$fx_rate != 1) {
      sprintf("<tr><td>Doviz kuru</td><td>%s TRY/EUR</td><td>kullanici girdisi</td></tr>",
              fmt_num(i$fx_rate, 2))
    } else {
      "<tr><td>Doviz kuru</td><td>girilmedi</td><td>yalnizca EUR raporlandi</td></tr>"
    },
    sprintf("<tr><td>Zaman ufku</td><td>%g yil</td><td>baz yil %d</td></tr>",
            i$horizon, i$base_year),
    sprintf("<tr><td>Rastgele tohum</td><td>%s</td><td>tekrarlanabilirlik</td></tr>",
            html_kacis(as.character(i$seed))),
    # v1.0.0 CN kodu yolunda (referans nesnesi yok) resmi tablolarla yapilan
    # hesabi da "DOGRULANMADI" gosteriyordu.
    sprintf("<tr><td>Referans veri paketi</td><td>%s</td><td>%s</td></tr>",
            html_kacis(cbam_data_version()),
            if (!is.null(r)) {
              if (isTRUE(r$dogrulandi)) "dogrulandi" else "<strong>DOGRULANMADI</strong>"
            } else if (!is.null(i$kaynaklar$benchmark)) {
              "resmi tablolar, dogrulandi"
            } else {
              "kullanilmadi (degerler kullanici girdisi)"
            })
  )

  html <- sprintf('<!doctype html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
<style>
  :root { --ink:#1a1a1a; --soft:#666; --line:#ddd; --bg:#fff;
          --vurgu:#1f4e5f; --seri-1:#2a78d6; --ink-2:#52514e;
          --izgara:#e1e0d9; --eksen:#c3c2b7; --uyari-bg:#fff4e5; --uyari-ink:#8a4b00; }
  * { box-sizing:border-box; }
  body { margin:0; padding:2rem 1.25rem; background:var(--bg); color:var(--ink);
         font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; }
  .sayfa { max-width:820px; margin:0 auto; }
  header { border-bottom:3px solid var(--vurgu); padding-bottom:1rem;
           margin-bottom:1.5rem; }
  h1 { margin:0 0 .25rem; font-size:1.6rem; }
  .altbilgi { color:var(--soft); font-size:.9rem; }
  h2 { font-size:1.15rem; margin:2rem 0 .75rem; color:var(--vurgu);
       border-bottom:1px solid var(--line); padding-bottom:.35rem; }
  .kartlar { display:flex; flex-wrap:wrap; gap:.75rem; margin:1.5rem 0; }
  .kart { flex:1 1 160px; border:1px solid var(--line); border-radius:6px;
          padding:.9rem 1rem; }
  .kart-deger { font-size:1.5rem; font-weight:600; letter-spacing:-.02em; }
  .kart-etiket { color:var(--soft); font-size:.8rem; margin-top:.2rem; }
  table { width:100%%; border-collapse:collapse; font-size:.95rem; }
  th,td { padding:.5rem .6rem; border-bottom:1px solid var(--line);
          text-align:left; vertical-align:top; }
  th { font-size:.8rem; text-transform:uppercase; letter-spacing:.04em;
       color:var(--soft); }
  .deger { text-align:right; font-variant-numeric:tabular-nums;
           white-space:nowrap; }
  .formul { color:var(--soft); font-size:.85rem;
            font-family:ui-monospace,SFMono-Regular,Consolas,monospace; }
  .birim { color:var(--soft); font-size:.85rem; white-space:nowrap; }
  tr.toplam td { font-weight:600; border-top:2px solid var(--ink);
                 border-bottom:none; }
  .uyari { background:var(--uyari-bg); color:var(--uyari-ink);
           border-left:4px solid currentColor; padding:.9rem 1rem;
           border-radius:0 4px 4px 0; margin:1.25rem 0; font-size:.92rem; }
  .uyari ul { margin:.5rem 0 0; padding-left:1.1rem; }
  .grafik { width:100%%; height:auto; margin:1rem 0 .5rem; }
  /* Grafik renkleri: dataviz referans paleti; seri-1 beyaz zeminde dogrulandi
     (validate_palette.js --surface #ffffff, tum kontroller PASS). Tek seri. */
  .cubuk, .seri { fill:var(--seri-1); }
  .seri-cizgi { fill:none; stroke:var(--seri-1); stroke-width:2;
                stroke-linejoin:round; }
  .nokta { fill:var(--seri-1); stroke:var(--bg); stroke-width:2; }
  .isabet { fill:transparent; }
  g:hover .seri, .cubuk:hover { opacity:.8; }
  .isaret { stroke:var(--ink-2); stroke-width:1; }
  .isaret-etiket { fill:var(--ink-2); font-size:11px; }
  .eksen { stroke:var(--eksen); stroke-width:1; }
  .izgara { stroke:var(--izgara); stroke-width:1; }
  .deger-etiket { fill:var(--ink); font-size:12px; font-weight:600; }
  .secili { fill:var(--ink); font-weight:700; }
  details { margin:.5rem 0 0; font-size:.9rem; }
  summary { cursor:pointer; color:var(--soft); }
  .bilgi { background:#f3f6f8; border-left:4px solid var(--vurgu);
           padding:.9rem 1rem; border-radius:0 4px 4px 0; margin:1.25rem 0;
           font-size:.92rem; }
  .bilgi ul { margin:.5rem 0 0; padding-left:1.1rem; }
  .eksen-etiket { fill:var(--soft); font-size:11px; }
  .iki-sutun { display:flex; flex-wrap:wrap; gap:1.5rem; align-items:flex-start; }
  .iki-sutun > * { flex:1 1 280px; }
  .yorum p { margin:0 0 .75rem; }
  .not { color:var(--soft); font-size:.85rem; }
  footer { margin-top:2.5rem; padding-top:1rem; border-top:1px solid var(--line);
           color:var(--soft); font-size:.82rem; }
  @media print {
    body { padding:0; font-size:11pt; }
    h2 { page-break-after:avoid; }
    section { page-break-inside:avoid; }
  }
</style></head><body><div class="sayfa">

<header>
  <h1>%s</h1>
  <div class="altbilgi">%s%s &middot; %s</div>
</header>

%s%s

<div class="kartlar">%s</div>

<section>
  <h2>Hesap</h2>
  <table>
    <thead><tr><th>Kalem</th><th>Formul</th>
    <th class="deger">Deger</th><th></th></tr></thead>
    <tbody>%s</tbody>
  </table>
  <p class="not">Her ara adim gorunurdur; sonuc kagit uzerinde
  dogrulanabilir. 2034&#39;te CBAM faktoru %%0&#39;a indiginde (yukumluluk payi
  %%100) ucretsiz tahsisat sifirlanir ve benchmark hesaptan tamamen duser.</p>
</section>

%s%s

<section>
  <h2>Girdiler ve Kaynaklar</h2>
  <table>
    <thead><tr><th>Parametre</th><th>Deger</th><th>Kaynak</th></tr></thead>
    <tbody>%s</tbody>
  </table>
</section>

<footer>
  <p><strong>stochastic-cbam-engine</strong> &middot; Selahattin
  &#304;lhan &middot; ORCID 0009-0007-4824-752X<br>
  A&#199;IK KAYNAK &middot; AGPL-3.0-or-later &middot;
  github.com/ilhanselahattin/stochastic-cbam-engine</p>
  <p>Bu rapor a&#231;&#305;k kaynakl&#305; bir hesap motoruyla
  &#252;retilmi&#351;tir; y&#246;ntemin tamam&#305; denetlenebilir.
  Beyan, yat&#305;r&#305;m veya fiyatlama karar&#305; i&#231;in tek
  ba&#351;&#305;na yeterli de&#287;ildir. &#199;eli&#351;ki halinde resm&#238;
  mevzuat metni ge&#231;erlidir.</p>
</footer>

</div></body></html>',
    html_kacis(baslik),
    html_kacis(baslik),
    if (!is.null(firma)) paste0(html_kacis(firma), " &middot; ") else "",
    if (!is.null(r)) html_kacis(r$urun_adi)
    else if (!is.null(i$kaynaklar$urun)) html_kacis(i$kaynaklar$urun)
    else "Kullanici tanimli urun",
    sprintf("%s tarihinde uretildi", tarih),
    uyari_html,
    notlar_html,
    paste(kartlar, collapse = ""),
    paste(satirlar, collapse = ""),
    grafikler,
    belirsizlik,
    paste(prov, collapse = "")
  )

  dizin <- dirname(dosya)
  if (!dir.exists(dizin)) dir.create(dizin, recursive = TRUE)
  writeLines(html, dosya, useBytes = TRUE)
  invisible(dosya)
}
