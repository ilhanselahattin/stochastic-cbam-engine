#  stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
#  SPDX-License-Identifier: AGPL-3.0-or-later
#
#  Bu dosya GNU Affero General Public License v3 (ya da sonraki bir surum)
#  kosullariyla dagitilir; HICBIR GARANTI VERILMEZ. Ayrintilar: LICENSE
#  EK SART (AGPL 7(b)): yazar atiflari ve telif bildirimleri korunmalidir.
#  Bkz. NOTICE ve LICENSE-ADDITIONAL-TERMS.md

#  Monte Carlo Motoru
#
#  Belirsizlik kaynaklarini tek bir simulasyon dongusunde birlestirir:
#    - theta_f  : firma teknoloji heterojenligi (lognormal)
#    - carbon   : EU ETS fiyati (GBM)
#    - fx       : doviz kuru (GBM, karbon fiyati ile korele)
#
#  Cikti tek bir nokta tahmini degil, maruziyetin olasilik dagilimidir.

#' CBAM maruziyet Monte Carlo simulasyonu
#'
#' @param n_sims Simulasyon sayisi.
#' @param quantity Yillik ihracat miktari (ton).
#' @param ei_sector Sektor ortalama emisyon yogunlugu (tCO2e / ton).
#' @param theta_sdlog Firma teknoloji heterojenligi (log-olcekte std. sapma).
#'   0 verilirse firma sektor ortalamasinda sabitlenir.
#' @param theta_meanlog Teknoloji katsayisinin log-ortalamasi.
#' @param benchmark AB ETS urun benchmark'i (tCO2e / ton).
#' @param year Yukumluluk yili; phase-in faktorunu belirler.
#' @param base_year Baslangic fiyatlarinin (\code{carbon_price_0}, \code{fx_0})
#'   gozlendigi yil. Zaman ufku buradan turetilir.
#' @param horizon Zaman ufku (yil). \code{NULL} ise \code{year - base_year}
#'   olarak hesaplanir - normalde bu birakilmalidir. Yalnizca ufku bilincli
#'   olarak ayirmak isteyen ileri kullanim icin elle verilebilir.
#' @param carbon_price_0 Baslangic EU ETS fiyati (EUR/tCO2e).
#' @param fx_0 Baslangic kuru (TRY/EUR).
#' @param seed Tekrarlanabilirlik icin rastgele sayi tohumu. Cagiranin RNG
#'   durumu fonksiyon cikisinda geri yuklenir.
#' @param ... \code{simulate_market()} fonksiyonuna aktarilan ek parametreler
#'   (carbon_mu, carbon_sigma, fx_mu, fx_sigma, rho).
#' @return \code{cbam_mc} sinifinda liste: \code{draws} (simulasyon bazinda
#'   data.frame) ve \code{inputs} (kullanilan parametreler).
run_cbam_mc <- function(n_sims = 10000,
                        quantity,
                        ei_sector,
                        theta_sdlog = 0.25,
                        theta_meanlog = 0,
                        benchmark,
                        year = 2030,
                        base_year = 2026,
                        horizon = NULL,
                        carbon_price_0 = 75,
                        fx_0 = 1,
                        carbon_price_paid = 0,
                        cbam_reference_price = NULL,
                        seed = NULL,
                        ...) {
  # Tohum yalnizca bu fonksiyonun icinde etkili olmali; cagiranin oturumundaki
  # rastgele sayi akisini kalici degistirmek sessiz bir yan etkidir.
  if (!is.null(seed)) {
    has_old <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
    old_seed <- if (has_old) {
      get(".Random.seed", envir = globalenv(), inherits = FALSE)
    } else {
      NULL
    }
    on.exit({
      if (is.null(old_seed)) {
        if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
          rm(".Random.seed", envir = globalenv())
        }
      } else {
        assign(".Random.seed", old_seed, envir = globalenv())
      }
    }, add = TRUE)
    set.seed(seed)
  }

  stopifnot(n_sims > 0, quantity >= 0, ei_sector >= 0, benchmark >= 0)
  if (length(year) != 1) {
    stop("year tek bir yil olmali; birden fazla yil icin ayri simulasyon calistirin.")
  }
  if (year < 2026) {
    stop("year 2026 ya da sonrasi olmali: CBAM mali yukumlulugu 2026'da baslar.")
  }

  # Zaman ufku yukumluluk yilindan turetilir. Bunu kullaniciya birakmak,
  # 2034 senaryosunun tek yillik belirsizlikle kosulmasina ve riskin
  # sistematik olarak eksik gosterilmesine yol aciyordu.
  if (is.null(horizon)) {
    horizon <- max(year - base_year, 0)
  }
  stopifnot(horizon >= 0)

  # 1) Firma teknoloji heterojenligi
  theta <- if (theta_sdlog > 0) {
    sample_theta(n_sims, meanlog = theta_meanlog, sdlog = theta_sdlog)
  } else {
    rep(exp(theta_meanlog), n_sims)
  }
  ei_firm <- firm_emission_intensity(ei_sector, theta)

  # 2) Gomulu emisyon (yasal taban, E_CBAM)
  embedded <- embedded_emissions(quantity, ei_firm)

  # 3) Piyasa belirsizligi
  market <- simulate_market(n_sims, carbon_price_0 = carbon_price_0,
                            fx_0 = fx_0, horizon = horizon, ...)

  # 4) Yasal yukumluluk
  # Mensede odenen karbon deterministik hesapla AYNI sekilde dusulmeli;
  # v1.0.0'da buraya aktarilmiyordu (deterministik 0 EUR iken simulasyon
  # milyonlarca EUR gosterebiliyordu). Sertifika referans fiyati piyasayla
  # birlikte olceklenir: ufuk 0'da deterministik sonuca birebir esittir,
  # RP = karbon fiyati verildiginde odenen karbon EUR olarak aynen dusulur.
  rp_sim <- NULL
  if (carbon_price_paid > 0) {
    if (is.null(cbam_reference_price) || cbam_reference_price <= 0) {
      stop("carbon_price_paid verildiginde cbam_reference_price de gerekli.")
    }
    # Baslangic fiyati 0 ise olcekleme tanimsiz (0/0); referans fiyat sabit kalir.
    rp_sim <- if (carbon_price_0 > 0) {
      cbam_reference_price * market$carbon_price / carbon_price_0
    } else cbam_reference_price
  }
  factor_y <- cbam_phase_in_factor(year)
  certs <- certificates_due(
    embedded = embedded,
    quantity = quantity,
    benchmark = benchmark,
    cbam_factor = factor_y,
    carbon_price_paid = carbon_price_paid,
    cbam_reference_price = rp_sim
  )

  # 5) Maliyet
  cost <- cbam_cost(certs, market$carbon_price, market$fx_rate)

  # Uc ayri TRY tutari, cunku uc ayri soruya cevap veriyorlar:
  #   cost_local_today : bugunku kurla. "Bu bugun olsaydi ne oderdim?"
  #                      Varsayim icermez, en savunulabilir olanidir.
  #   cost_local       : o yilin nominal kuruyla. Faturada gorunecek rakam,
  #                      ama tamamen kur suruklemesi varsayimina bagli.
  #   cost_local_real  : nominal tutarin bugunun alim gucune indirgenmisi.
  draws <- data.frame(
    theta            = theta,
    ei_firm          = ei_firm,
    embedded         = embedded,
    certificates     = certs,
    carbon_price     = market$carbon_price,
    fx_rate          = market$fx_rate,
    cost_eur         = cost$cost_eur,
    cost_local_today = cost$cost_eur * fx_0,
    cost_local       = cost$cost_local,
    cost_local_real  = cost$cost_local / market$deflator_tr
  )

  structure(
    list(
      draws = draws,
      inputs = list(
        n_sims = n_sims, quantity = quantity, ei_sector = ei_sector,
        theta_sdlog = theta_sdlog, theta_meanlog = theta_meanlog,
        benchmark = benchmark, year = year, base_year = base_year,
        horizon = horizon, cbam_factor = factor_y,
        carbon_price_0 = carbon_price_0, fx_0 = fx_0,
        seed = seed
      )
    ),
    class = "cbam_mc"
  )
}

#' Risk ozeti (%90 guven araligi)
#'
#' @param x \code{run_cbam_mc()} ciktisi.
#' @param probs Raporlanacak yuzdelikler.
#' @return Anahtar metriklerin yuzdeliklerini iceren data.frame.
risk_summary <- function(x, probs = c(0.05, 0.25, 0.50, 0.75, 0.95)) {
  if (!inherits(x, "cbam_mc")) {
    stop("x, run_cbam_mc() ciktisi olmali.")
  }
  metrics <- c("embedded", "certificates", "cost_eur",
               "cost_local_today", "cost_local_real", "cost_local")
  out <- lapply(metrics, function(m) {
    v <- x$draws[[m]]
    c(mean = mean(v), sd = stats::sd(v), stats::quantile(v, probs))
  })
  res <- as.data.frame(do.call(rbind, out))
  rownames(res) <- metrics
  res
}

#' Riske Maruz Deger (Value at Risk)
#'
#' Verilen guven duzeyinde asilmayacak maksimum maliyet.
#'
#' @param x \code{run_cbam_mc()} ciktisi.
#' @param level Guven duzeyi (varsayilan 0.95).
#' @param metric Hangi maliyet sutunu kullanilsin.
#' @return Tek sayi: VaR degeri.
cbam_var <- function(x, level = 0.95, metric = "cost_eur") {
  if (!inherits(x, "cbam_mc")) {
    stop("x, run_cbam_mc() ciktisi olmali.")
  }
  unname(stats::quantile(x$draws[[metric]], probs = level))
}

#' @export
print.cbam_mc <- function(x, ...) {
  cat("Stokastik CBAM Maruziyet Simulasyonu\n")
  cat("------------------------------------\n")
  cat(sprintf("Simulasyon sayisi : %s\n", fmt_num(x$inputs$n_sims)))
  cat(sprintf("Yukumluluk yili   : %d (yukumluluk payi: %.1f%%)\n",
              x$inputs$year, 100 * x$inputs$cbam_factor))
  cat(sprintf("Zaman ufku        : %g yil (baz yil: %d)\n",
              x$inputs$horizon, x$inputs$base_year))
  cat(sprintf("Ihracat miktari   : %s ton\n", fmt_num(x$inputs$quantity)))
  cat("\nCBAM maliyeti (EUR):\n")
  q <- stats::quantile(x$draws$cost_eur, c(0.05, 0.50, 0.95))
  cat(sprintf("  %%5  alt sinir : %15s\n", fmt_num(q[1])))
  cat(sprintf("  Medyan         : %15s\n", fmt_num(q[2])))
  cat(sprintf("  %%95 ust sinir : %15s\n", fmt_num(q[3])))
  cat(sprintf("  Ortalama       : %15s\n", fmt_num(mean(x$draws$cost_eur))))
  invisible(x)
}
