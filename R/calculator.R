#  stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
#  SPDX-License-Identifier: AGPL-3.0-or-later
#
#  Bu dosya GNU Affero General Public License v3 (ya da sonraki bir surum)
#  kosullariyla dagitilir; HICBIR GARANTI VERILMEZ. Ayrintilar: LICENSE
#  EK SART (AGPL 7(b)): yazar atiflari ve telif bildirimleri korunmalidir.
#  Bkz. NOTICE ve LICENSE-ADDITIONAL-TERMS.md

#  Hesap Makinesi Katmani
#
#  Motor katmani (certificates_due, run_cbam_mc, ...) saf hesap yapar ve
#  ham sayi dondurur. Bu katman kullanicinin girdigi degerleri alip tek bir
#  okunabilir cevaba cevirir: kac sertifika, kac EUR, kac TRY, ton basina ne.
#
#  Iki cevap birden verilir:
#    (1) Deterministik hesap - "hesap makinesi" cevabi. Her adimi gorunur,
#        elle kagit uzerinde dogrulanabilir.
#    (2) Belirsizlik araligi  - ayni girdilerin karbon fiyati ve kur
#        dalgalanmasi altinda ne kadar oynadigi.
#
#  (1) olmadan arac guvenilmez gorunur; (2) olmadan yaniltici olur.

#' CBAM maliyet hesabi
#'
#' @param quantity AB'ye yillik ihracat miktari (ton).
#' @param ei_direct Dogrudan (Scope 1) emisyon yogunlugu (tCO2e / ton).
#' @param benchmark AB ETS urun benchmark'i (tCO2e / ton).
#' @param year Yukumluluk yili.
#' @param carbon_price EU ETS sertifika fiyati (EUR / tCO2e).
#' @param fx_rate Doviz kuru (TRY / EUR). 1 birakilirsa yalnizca EUR raporlanir.
#' @param carbon_price_paid Mense ulkede fiilen odenmis karbon FIYATI
#'   (SECPP), mal tonu basina EUR. Miktar degil fiyattir.
#' @param cbam_reference_price CBAM sertifikasi referans fiyati (EUR/tCO2e).
#' @param ei_indirect Dolayli (elektrik) emisyon yogunlugu (tCO2e / ton).
#' @param include_indirect Dolayli emisyonlar hesaba katilsin mi? CBAM'de
#'   demir-celik icin gecis doneminde raporlanir ancak vergilendirilmez.
#' @param uncertainty Belirsizlik araligi da hesaplansin mi?
#' @param theta_sdlog Firma teknoloji heterojenligi (log-olcekte std. sapma).
#' @param base_year Karbon fiyati ve kurun gozlendigi yil; zaman ufku
#'   \code{year - base_year} olarak turetilir.
#' @param n_sims Belirsizlik hesabindaki simulasyon sayisi.
#' @param seed Tekrarlanabilirlik icin rastgele sayi tohumu.
#' @param reference \code{cbam_product()} ciktisi ya da NULL. Verildiginde
#'   kullanilan degerlerin kaynagi ciktida gosterilir ve dogrulanmamis veri
#'   icin uyari basilir.
#' @param kaynaklar \code{reference} yokken (CN kodu yolu) degerlerin
#'   kaynagi: \code{list(yogunluk = , benchmark = )}. Raporda gosterilir;
#'   verilmezse "kullanici girdisi" yazilir.
#' @param ... \code{run_cbam_mc()} uzerinden \code{simulate_market()}'e
#'   aktarilan ek parametreler (carbon_sigma, fx_mu, fx_sigma, rho).
#' @return \code{cbam_estimate} sinifinda liste.
cbam_estimate <- function(quantity,
                          ei_direct,
                          benchmark,
                          year = 2026,
                          carbon_price = 80,
                          fx_rate = 1,
                          carbon_price_paid = 0,
                          cbam_reference_price = NULL,
                          ei_indirect = 0,
                          include_indirect = FALSE,
                          uncertainty = TRUE,
                          theta_sdlog = 0.20,
                          base_year = 2026,
                          n_sims = 50000,
                          seed = 2026,
                          inflation_tr = 0.25,
                          inflation_eu = 0.02,
                          reference = NULL,
                          functional_unit = NULL,
                          ei_label = "dogrudan",
                          kaynaklar = NULL,
                          ...) {
  stopifnot(is.numeric(quantity), is.numeric(ei_direct), is.numeric(benchmark))
  if (length(quantity) != 1 || length(ei_direct) != 1 || length(benchmark) != 1) {
    stop("quantity, ei_direct ve benchmark tek deger olmali.")
  }
  if (quantity < 0) stop("quantity negatif olamaz.")
  if (ei_direct < 0) stop("ei_direct negatif olamaz.")
  if (benchmark < 0) stop("benchmark negatif olamaz.")
  if (carbon_price < 0) stop("carbon_price negatif olamaz.")
  if (fx_rate <= 0) stop("fx_rate pozitif olmali.")
  gecerli_yil(year)
  # Gecis doneminde (2023-2025) yalnizca raporlama vardi; mali yukumluluk
  # 2026'da basliyor (D5). Ucretsiz tahsisat payi %100 olsa bile benchmark
  # ustu emisyon formulde sertifikaya donusurdu - v1.0.0 2025 icin boyle
  # sahte bir maliyet gosteriyordu. Sessiz sifir yerine acik hata.
  if (length(year) != 1 || year < 2026) {
    stop(paste0("year 2026 ya da sonrasi olmali: CBAM mali yukumlulugu ",
                "kesin donemle (2026) baslar, oncesinde yalnizca raporlama vardir."))
  }

  # --- Deterministik hesap ---------------------------------------------
  ei_total <- if (isTRUE(include_indirect)) ei_direct + ei_indirect else ei_direct
  embedded <- embedded_emissions(quantity, ei_direct, ei_indirect,
                                 include_indirect = include_indirect)
  factor_y <- cbam_phase_in_factor(year)
  free_allocation <- benchmark * quantity * (1 - factor_y)
  certificates <- certificates_due(
    embedded             = embedded,
    quantity             = quantity,
    benchmark            = benchmark,
    cbam_factor          = factor_y,
    carbon_price_paid    = carbon_price_paid,
    cbam_reference_price = cbam_reference_price
  )
  cost <- cbam_cost(certificates, carbon_price, fx_rate)

  # De minimis: esik 50 ton NET KUTLE (emisyon degil). Ithalatci basina
  # yillik kumulatif ve tum CN kodlari toplaminda gecerli oldugu icin
  # buradaki kontrol yalnizca "bu miktar tek basina esigin altinda" der.
  exempt <- is_de_minimis(quantity, sektor = if (!is.null(reference))
                            reference$sektor else NULL)
  if (exempt) {
    certificates <- 0
    cost <- list(cost_eur = 0, cost_local = 0)
  }

  # --- Belirsizlik araligi ---------------------------------------------
  sim <- NULL
  if (isTRUE(uncertainty) && !exempt && quantity > 0) {
    sim <- run_cbam_mc(
      n_sims             = n_sims,
      quantity           = quantity,
      ei_sector          = ei_total,
      theta_sdlog        = theta_sdlog,
      benchmark          = benchmark,
      year               = year,
      base_year          = base_year,
      carbon_price_0     = carbon_price,
      fx_0               = fx_rate,
      carbon_price_paid    = carbon_price_paid,
      cbam_reference_price = cbam_reference_price,
      seed               = seed,
      inflation_tr       = inflation_tr,
      inflation_eu       = inflation_eu,
      ...
    )
  }

  structure(
    list(
      deterministic = list(
        embedded        = embedded,
        free_allocation = free_allocation,
        certificates    = certificates,
        cost_eur        = cost$cost_eur,
        cost_local      = cost$cost_local,
        cost_per_tonne  = if (quantity > 0) cost$cost_eur / quantity else 0,
        taxed_share     = if (embedded > 0) certificates / embedded else 0,
        de_minimis      = exempt
      ),
      simulation = sim,
      reference = reference,
      inputs = list(
        quantity = quantity, ei_direct = ei_direct, ei_indirect = ei_indirect,
        include_indirect = include_indirect, ei_total = ei_total,
        benchmark = benchmark, year = year, cbam_factor = factor_y,
        carbon_price = carbon_price, fx_rate = fx_rate,
        carbon_price_paid = carbon_price_paid,
        cbam_reference_price = cbam_reference_price,
        theta_sdlog = theta_sdlog, base_year = base_year,
        horizon = max(year - base_year, 0), n_sims = n_sims, seed = seed,
        inflation_tr = inflation_tr, inflation_eu = inflation_eu,
        ei_label = ei_label,
        kaynaklar = kaynaklar,
        functional_unit = if (is.null(functional_unit)) {
          list(birim = "ton urun", standart = TRUE)
        } else {
          functional_unit
        }
      )
    ),
    class = "cbam_estimate"
  )
}

#' Ayni girdilerle 2026-2034 maliyet yolu
#'
#' Her yil icin o yilin mevzuat parametreleri kullanilir: CBAM faktoru,
#' varsayilan degerin mark-up'i (yogunluk verilmediyse) ve yila bagli
#' benchmark. Karbon fiyati her yil ayni tutulur - grafik yalnizca mevzuat
#' takviminin etkisini gosterir, fiyat belirsizligini degil.
#'
#' @param quantity Miktar (ton).
#' @param cn_kodu CN kodu; NULL ise \code{ei} ve \code{benchmark} sabit kalir.
#' @param ei Kullanicinin olctugu yogunluk; NULL ise varsayilan + mark-up.
#' @param benchmark Elle verilmis benchmark; NULL ise tablodan, yila gore.
#' @return \code{yil}, \code{faktor}, \code{yogunluk}, \code{markup},
#'   \code{benchmark}, \code{sertifika}, \code{cost_eur} sutunlu data.frame.
cbam_yillik_yol <- function(quantity, cn_kodu = NULL, ulke = "Turkiye",
                            ei = NULL, benchmark = NULL, sutun = "B",
                            rota = NULL, carbon_price = 80,
                            carbon_price_paid = 0, cbam_reference_price = NULL,
                            ei_indirect = 0, include_indirect = FALSE,
                            yillar = 2026:2034) {
  do.call(rbind, lapply(yillar, function(y) {
    # Varsayilan deger satiri, kullanici kendi yogunlugunu verse bile ulkenin
    # benchmark ROTASINI tasir; manset hesapla ayni rota kullanilmali.
    see <- if (!is.null(cn_kodu)) {
      tryCatch(cbam_default_see(cn_kodu, y, ulke), error = function(e) NULL)
    } else NULL
    e <- if (!is.null(ei)) ei else if (!is.null(see)) see$deger else NA_real_
    r <- if (!is.null(rota)) rota else if (!is.null(see)) see$rota else NULL
    b <- if (!is.null(benchmark)) benchmark else
      cbam_benchmark_by_cn(cn_kodu, sutun, yil = y, rota = r)$benchmark
    est <- cbam_estimate(quantity, e, b, year = y, carbon_price = carbon_price,
                         carbon_price_paid = carbon_price_paid,
                         cbam_reference_price = cbam_reference_price,
                         ei_indirect = ei_indirect,
                         include_indirect = include_indirect,
                         uncertainty = FALSE)
    data.frame(yil = y, faktor = cbam_factor_official(y), yogunluk = e,
               markup = if (is.null(ei) && !is.null(see)) see$markup else 0,
               benchmark = b,
               sertifika = est$deterministic$certificates,
               cost_eur = est$deterministic$cost_eur)
  }))
}

#' @export
print.cbam_estimate <- function(x, ...) {
  i <- x$inputs
  d <- x$deterministic
  line <- strrep("=", 68)
  thin <- strrep("-", 68)

  r <- x$reference

  cat("\n"); cat(line, "\n")
  cat("  CBAM MALIYET HESABI\n")
  if (!is.null(r)) {
    cat(sprintf("  %s\n", r$urun_adi))
  }
  cat(line, "\n")

  # Dogrulanmamis referans degerleri, resmi deger sanilmadan once soylenmeli.
  uyari <- if (!is.null(r)) cbam_dogrulama_uyarisi(r) else NULL
  if (!is.null(uyari)) {
    cat("\n")
    for (u in uyari) cat(u, "\n", sep = "")
  }
  cat("\n")

  # Cimento ve gubrede operatorun IZLEME birimi ton urun degildir, ama
  # yukumluluk hesabi ton urun uzerinden yapilir. Kullanicinin elindeki
  # emisyon verisi izleme biriminde ise once donusturmesi gerekir.
  fb <- i$functional_unit
  if (!isTRUE(fb$standart)) {
    cat(sprintf(paste0(
      "!! BIRIM NOTU: bu sektorde emisyon %s basina IZLENIR ve\n",
      "   raporlanir. Yukumluluk hesabi ise TON URUN uzerinden yapilir\n",
      "   (Rehber No. 1, s.15) - bu araca da miktar TON URUN girilir.\n",
      "   Emisyon yogunlugunuz %s basina ise, once ton urune cevirin:\n",
      "   Methodology Act Ek III, bilesim formulleri.\n\n"),
      fb$birim, fb$birim))
  }

  cat("GIRDILER\n")
  cat(sprintf("  Ihracat miktari        : %15s ton urun/yil\n",
              fmt_num(i$quantity)))
  cat(sprintf("  Emisyon yogunlugu      : %15s tCO2e/ton  (%s)\n",
              fmt_num(i$ei_direct, 3),
              if (is.null(i$ei_label)) "dogrudan" else i$ei_label))
  if (!is.null(r)) {
    cat(sprintf("  %sKaynak: %s\n", strrep(" ", 27), r$yogunluk_kaynak))
  }
  if (i$include_indirect) {
    cat(sprintf("  + dolayli (elektrik)   : %15s tCO2e/ton\n",
                fmt_num(i$ei_indirect, 3)))
  }
  cat(sprintf("  AB ETS benchmark       : %15s tCO2e/ton\n",
              fmt_num(i$benchmark, 3)))
  if (!is.null(r)) {
    cat(sprintf("  %sKaynak: %s\n", strrep(" ", 27), r$benchmark_kaynak))
    if (nzchar(r$benchmark_gecerlilik)) {
      cat(sprintf("  %sGecerlilik: %s\n", strrep(" ", 27),
                  r$benchmark_gecerlilik))
    }
    if (!is.null(r$benchmark_not) && nzchar(r$benchmark_not)) {
      cat(sprintf("  %sNot: %s\n", strrep(" ", 27), r$benchmark_not))
    }
  }
  cat(sprintf("  Yukumluluk yili        : %15d\n", i$year))
  cat(sprintf("  Karbon fiyati          : %15s EUR/tCO2e\n",
              fmt_num(i$carbon_price, 2)))
  if (i$fx_rate != 1) {
    cat(sprintf("  Doviz kuru             : %15s TRY/EUR\n",
                fmt_num(i$fx_rate, 2)))
  }

  if (isTRUE(d$de_minimis)) {
    cat("\n"); cat(thin, "\n")
    cat("  DE MINIMIS MUAFIYETI\n\n")
    cat(sprintf("  Ithalat miktari %s ton, 50 ton net kutle esigini asmiyor.\n",
                fmt_num(i$quantity)))
    cat("  Bu miktar icin CBAM yukumlulugu dogmuyor.\n\n")
    cat("  !! ONEMLI: Esik ITHALATCI BASINA ve TAKVIM YILI BOYUNCA\n")
    cat("     KUMULATIFTIR; tum CN kodlari toplaminda gecerlidir.\n")
    cat("     Yil icinde 50 tonu asarsaniz, o yil ithal ettiginiz TUM mallar\n")
    cat("     yukumlu hale gelir - esik asilmadan once gelenler dahil.\n")
    cat("     Burada yalnizca bu tek miktar kontrol edildi.\n")
    cat("     Kaynak: CBAM Tuzugu Md. 2a, Ek VII nokta 1\n")
    cat(line, "\n\n")
    return(invisible(x))
  }

  # Her satir: etiket | acik formul | sonuc. Formulun gorunur olmasi
  # bilincli bir tercih - kapali kutu araclardan ayrisan nokta bu.
  satir <- function(etiket, formul, deger, birim) {
    cat(sprintf("  %-21s %-24s = %13s %s\n", etiket, formul, deger, birim))
  }
  kalan_faktor <- 1 - i$cbam_factor

  cat("\nHESAP\n")
  satir("Gomulu emisyon",
        sprintf("%s x %s", fmt_num(i$quantity), fmt_num(i$ei_total, 3)),
        fmt_num(d$embedded), "tCO2e")
  satir("Ucretsiz tahsisat",
        sprintf("%s x %s x %s", fmt_num(i$benchmark, 3),
                fmt_num(i$quantity), fmt_num(kalan_faktor, 3)),
        paste0("-", fmt_num(d$free_allocation)), "tCO2e")
  # Mevzuattaki "CBAM factor" ucretsiz tahsisatin KALAN payidir (Rehber
  # No. 4 Tablo 2-1); i$cbam_factor ise onun tumleyeni, yukumluluk payi.
  cat(sprintf("  %-21s (%s = resmi CBAM faktoru; yukumluluk payi %s)\n", "",
              fmt_num(kalan_faktor, 3), fmt_num(i$cbam_factor, 3)))
  if (i$carbon_price_paid > 0) {
    satir("Mensede odenen karbon",
          sprintf("%s x %s / %s", fmt_num(i$quantity),
                  fmt_num(i$carbon_price_paid, 2),
                  fmt_num(i$cbam_reference_price, 2)),
          paste0("-", fmt_num(i$quantity * i$carbon_price_paid /
                                i$cbam_reference_price)), "tCO2e")
    cat(sprintf("  %-21s (EUR/ton mal / sertifika referans fiyati)\n", ""))
  }
  cat("  ", thin, "\n", sep = "")
  satir("SERTIFIKA YUKUMLULUGU", "", fmt_num(d$certificates), "tCO2e")
  cat(sprintf("  %-21s %-24s   %13s\n", "", "",
              sprintf("(emisyonun %%%s'i)", fmt_num(100 * d$taxed_share, 1))))

  cat("\n")
  satir("CBAM MALIYETI",
        sprintf("%s x %s EUR", fmt_num(d$certificates),
                fmt_num(i$carbon_price, 2)),
        fmt_num(d$cost_eur), "EUR")
  if (i$fx_rate != 1) {
    satir("", sprintf("x %s TRY/EUR", fmt_num(i$fx_rate, 2)),
          fmt_num(d$cost_local), "TRY")
  }
  satir("Ton basina yuk", "", fmt_num(d$cost_per_tonne, 2), "EUR/ton")

  if (!is.null(x$simulation)) {
    s <- x$simulation
    q <- stats::quantile(s$draws$cost_eur, c(0.05, 0.50, 0.95))
    cat("\n"); cat(thin, "\n")
    cat(sprintf("BELIRSIZLIK  (%s simulasyon, %g yillik ufuk)\n",
                fmt_num(i$n_sims), i$horizon))
    if (i$horizon == 0) {
      cat("  Yukumluluk yili baz yil ile ayni: fiyat ve kur belirsizligi yok.\n")
      cat("  Asagidaki aralik yalnizca tesis verimliligi sacilimindan gelir.\n")
    } else {
      cat("  Karbon fiyati, kur ve tesis verimliligi birlikte oynatildiginda:\n")
    }
    cat("\n")
    cat(sprintf("    %%5  (iyimser)     : %15s EUR\n", fmt_num(q[1])))
    cat(sprintf("    Medyan            : %15s EUR\n", fmt_num(q[2])))
    cat(sprintf("    %%95 (VaR)         : %15s EUR\n", fmt_num(q[3])))
    cat("\n")
    cat("  Butcelenmesi gereken rakam %95 senaryosudur; medyan zamanin\n")
    cat("  yarisinda asilir.\n")

    if (i$fx_rate != 1) {
      qt <- stats::quantile(s$draws$cost_local_today, c(0.05, 0.50, 0.95))
      qn <- stats::quantile(s$draws$cost_local, c(0.50, 0.95))
      cat("\n  TRY karsiligi - iki ayri soru, iki ayri rakam:\n\n")
      cat(sprintf("    %-28s %-7s %17s TRY\n",
                  sprintf("Bugunku kurla (%s TRY/EUR)", fmt_num(i$fx_rate, 0)),
                  "medyan", fmt_num(qt[2])))
      cat(sprintf("    %-28s %-7s %17s TRY\n", "", "%95", fmt_num(qt[3])))
      cat(sprintf("    %-28s %-7s %17s TRY\n",
                  sprintf("%d nominal kuruyla", i$year),
                  "medyan", fmt_num(qn[1])))
      cat(sprintf("    %-28s %-7s %17s TRY\n", "", "%95", fmt_num(qn[2])))
      if (i$horizon > 0) {
        cat(sprintf(paste0(
          "\n  Nominal rakam kur suruklemesi varsayimina baglidir ve %g yil\n",
          "  boyunca bilesiklenir. Planlamada BUGUNKU KURLA satirini kullanin.\n",
          "  Kur varsayimi enflasyon farkindan turetilir (TR %%%s / AB %%%s),\n",
          "  elle secilmis bir sayi degildir.\n"),
          i$horizon,
          fmt_num(100 * i$inflation_tr, 1),
          fmt_num(100 * i$inflation_eu, 1)))
      }
    }
  }

  cat("\n"); cat(line, "\n")
  cat(sprintf(paste0("stochastic-cbam-engine | %d: CBAM faktoru %%%s, ",
                     "yukumluluk payi %%%s (Rehber No. 4 Tablo 2-1)\n"),
              i$year, fmt_num(100 * (1 - i$cbam_factor), 1),
              fmt_num(100 * i$cbam_factor, 1)))
  # Veri surumu HER ZAMAN gorunur olmali. Referans tablolari Komisyon
  # tarafindan habersiz revize ediliyor; kullanicinin hangi tarihli veriyle
  # hesap yaptigini gormesi, sayinin kendisi kadar onemli.
  surum <- tryCatch(cbam_data_version(), error = function(e) NULL)
  if (!is.null(surum)) {
    cat(sprintf("Referans veri paketi: %s%s\n", surum,
                if (!is.null(r) && !isTRUE(r$dogrulandi)) {
                  "  [DOGRULANMAMIS]"
                } else {
                  ""
                }))
  }
  if (!is.null(x$simulation)) {
    cat(sprintf("Tohum: %s | Parametreler gosterim amaclidir, dogrulayin.\n",
                as.character(i$seed)))
  }
  cat(line, "\n\n")
  invisible(x)
}
