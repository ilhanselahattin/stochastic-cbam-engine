#  stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
#  SPDX-License-Identifier: AGPL-3.0-or-later
#
#  Bu dosya GNU Affero General Public License v3 (ya da sonraki bir surum)
#  kosullariyla dagitilir; HICBIR GARANTI VERILMEZ. Ayrintilar: LICENSE
#  EK SART (AGPL 7(b)): yazar atiflari ve telif bildirimleri korunmalidir.
#  Bkz. NOTICE ve LICENSE-ADDITIONAL-TERMS.md

#  CBAM Yukumluluk Modulu
#
#  Yasal cerceve: Regulation (EU) 2023/956 (CBAM Tuzugu) ve tadilleri,
#  Free Allocation Adjustment Act (CIR (EU) 2025/2620).
#  Bu modul E_CBAM (yasal olarak vergilendirilen emisyon) hesabini yapar;
#  tedarik zinciri genelindeki E_MRIO arastirma ekindedir: research/mrio.R.

#' Mevzuattaki resmi CBAM faktoru (ucretsiz tahsisat payi)
#'
#' DIKKAT - ISIM KARISIKLIGI: Mevzuatin "CBAM factor" dedigi deger, ucretsiz
#' tahsisatin HALA GECERLI OLAN payidir; yukumluluk payi degildir. 2026'da
#' %97,5'tir (yani tahsisatin %97,5'i durur), 2034'te %0'dir.
#'
#' Bu fonksiyon mevzuattaki degeri aynen dondurur. Motorun geri kalani
#' yukumluluk payiyla calisir; bkz. cbam_phase_in_factor().
#'
#' Kaynak: Free Allocation Adjustment Act, CIR (EU) 2025/2620; Guidance No. 4
#' Tablo 2-1; EU ETS Direktifi Madde 10a(1a).
#'
#' @param year Takvim yili (tam sayi). Vektor verilebilir.
#' @return 0 ile 1 arasinda resmi CBAM faktoru.
cbam_factor_official <- function(year) {
  gecerli_yil(year)
  schedule <- c(
    "2026" = 0.975, "2027" = 0.950, "2028" = 0.900,
    "2029" = 0.775, "2030" = 0.515, "2031" = 0.390,
    "2032" = 0.265, "2033" = 0.140, "2034" = 0.000
  )
  out <- numeric(length(year))
  out[year < 2026] <- 1        # Gecis donemi: tahsisat tam, mali yukumluluk yok
  out[year >= 2034] <- 0       # Tahsisat tamamen kalkti
  mid <- year >= 2026 & year < 2034
  out[mid] <- unname(schedule[as.character(year[mid])])
  out
}

#' Cross-sectoral correction factor (CSCF)
#'
#' EU ETS Direktifi Madde 10a(5) uyarinca belirlenir ve ucretsiz tahsisat
#' hesabina carpan olarak girer. 2026-2030 donemi degerleri Commission
#' Implementing Decision (EU) 2026/1862 ile yayimlanmistir; 2031'den itibaren
#' gecerli degerlerin 2030 sonunda yayimlanmasi bekleniyor.
#'
#' Su an tum yillar icin 1,0 oldugundan sayisal etkisi yoktur; formulde yer
#' almasi, deger degistiginde motorun sessizce yanlis hesap yapmamasi icindir.
#'
#' @param year Takvim yili.
#' @return CSCF degeri (boyutsuz).
cbam_cscf <- function(year) {
  gecerli_yil(year)
  rep(1.0, length(year))
}

#' Yil girdisini dogrula
#'
#' @param year Kontrol edilecek deger.
#' @return Gorunmez TRUE; gecersizse hata firlatir.
gecerli_yil <- function(year) {
  if (!is.numeric(year) || length(year) == 0) {
    stop("year bos olmayan sayisal bir vektor olmali.")
  }
  if (anyNA(year)) {
    stop("year NA icermemeli.")
  }
  if (any(year != trunc(year))) {
    stop("year tam sayi olmali (ornek: 2030).")
  }
  invisible(TRUE)
}

#' CBAM yukumluluk payi (phase-in faktoru)
#'
#' Gomulu emisyonun ucretsiz tahsisatla KARSILANMAYAN, yani yukumluluk doguran
#' payi. Mevzuattaki resmi CBAM faktorunun tumleyenidir:
#'
#'     yukumluluk_payi = 1 - cbam_factor_official(year)
#'
#' 2026'da %2,5, 2030'da %48,5, 2034'te %100. 2026 oncesinde 0 (gecis
#' doneminde yalnizca raporlama vardir, mali yukumluluk dogmaz).
#'
#' @param year Takvim yili (tam sayi). Vektor verilebilir.
#' @return 0 ile 1 arasinda yukumluluk payi.
cbam_phase_in_factor <- function(year) {
  # Tek dogruluk kaynagi resmi tablodur; buradaki deger ondan turetilir.
  # Iki ayri tablo tutmak, birinin guncellenip digerinin unutulmasi demekti.
  1 - cbam_factor_official(year)
}

#' Odenmesi gereken CBAM sertifikasi (tCO2e)
#'
#' Ithalatci, AB ureticisinin hala aldigi ucretsiz tahsisat kadar muaftir.
#' Bu muafiyet CBAM faktoru arttikca erir:
#'
#'     sertifika = gomulu_emisyon - benchmark * miktar * (1 - cbam_factor)
#'                 - mensede_odenen_karbon
#'
#' @param embedded Gomulu emisyon (tCO2e).
#' @param quantity Ihracat miktari (ton).
#' @param benchmark AB ETS urun benchmark'i (tCO2e / ton). Demir-celik sicak
#'   metal icin yaklasik 1,288 tCO2e/ton.
#' @param cbam_factor Yukumluluk payi, bkz. \code{cbam_phase_in_factor()}.
#'   \code{(1 - cbam_factor)} mevzuattaki resmi CBAM faktorune esittir.
#' @param carbon_price_paid Mense ulkede fiilen odenmis karbon fiyati
#'   (SECPP), **mal tonu basina EUR**. Iade ve tazminatlar dusulmus olmali.
#'   Bu bir MIKTAR degil FIYATTIR; sertifika referans fiyatina bolunerek
#'   tCO2e'ye cevrilir.
#' @param cbam_reference_price CBAM sertifikasinin referans fiyati
#'   (RP_CBAM), EUR/tCO2e. Komisyon yillik ortalama olarak belirler
#'   (CBAM Tuzugu Md. 21). \code{carbon_price_paid > 0} ise zorunludur.
#' @param cscf Cross-sectoral correction factor, bkz. \code{cbam_cscf()}.
#'   Varsayilan 1; su an tum yillar icin 1'dir.
#' @return Satin alinmasi gereken sertifika miktari (tCO2e), negatif olamaz.
certificates_due <- function(embedded,
                             quantity,
                             benchmark,
                             cbam_factor,
                             carbon_price_paid = 0,
                             cbam_reference_price = NULL,
                             cscf = 1) {
  stopifnot(is.numeric(embedded), is.numeric(quantity), is.numeric(benchmark))
  if (any(cbam_factor < 0 | cbam_factor > 1, na.rm = TRUE)) {
    stop("cbam_factor 0 ile 1 arasinda olmali.")
  }
  if (any(cscf < 0, na.rm = TRUE)) {
    stop("cscf negatif olamaz.")
  }
  if (any(carbon_price_paid < 0, na.rm = TRUE)) {
    stop("carbon_price_paid negatif olamaz.")
  }

  # Resmi formul (Rehber No. 1, s.14; CBAM Tuzugu Md. 6(2)(c), 7, 9 ve 31):
  #
  #   CBAM Obligation = max[0 ; SEE - SEFA - SECPP / RP_CBAM] * M
  #
  # SECPP mal tonu basina EUR cinsindendir; sertifika referans fiyatina
  # bolununce tCO2e/ton olur. Onceki surumde bu parametre dogrudan tCO2e
  # olarak dusuluyordu - birim yanlisti.
  free_allocation <- benchmark * quantity * (1 - cbam_factor) * cscf

  odenen_dusum <- 0
  if (any(carbon_price_paid > 0, na.rm = TRUE)) {
    if (is.null(cbam_reference_price) || any(cbam_reference_price <= 0)) {
      stop(paste0(
        "carbon_price_paid verildiginde cbam_reference_price de gerekli.\n",
        "  Odenen karbon bir FIYATTIR (EUR/ton mal); tCO2e'ye cevrilmesi icin\n",
        "  CBAM sertifikasinin referans fiyati (EUR/tCO2e) lazim."))
    }
    odenen_dusum <- quantity * carbon_price_paid / cbam_reference_price
  }

  pmax(embedded - free_allocation - odenen_dusum, 0)
}

#' CBAM maliyeti (EUR ve yerel para)
#'
#' @param certificates Sertifika miktari (tCO2e).
#' @param carbon_price EU ETS sertifika fiyati (EUR / tCO2e).
#' @param fx_rate Doviz kuru (yerel para / EUR). Varsayilan 1 -> yalniz EUR.
#' @return \code{cost_eur} ve \code{cost_local} iceren liste.
cbam_cost <- function(certificates, carbon_price, fx_rate = 1) {
  stopifnot(is.numeric(certificates), is.numeric(carbon_price))
  if (any(carbon_price < 0, na.rm = TRUE)) {
    stop("carbon_price negatif olamaz.")
  }
  cost_eur <- certificates * carbon_price
  list(cost_eur = cost_eur, cost_local = cost_eur * fx_rate)
}

#' De minimis muafiyeti (kutle esigi)
#'
#' Kaynak: CBAM Tuzugu Md. 2a ve Ek VII nokta 1; Rehber No. 1 s.23.
#'
#' Esik **50 ton NET KUTLE**dir - emisyon degil. Onceki surumde 50 tCO2e
#' olarak uygulaniyordu; birim yanlisti.
#'
#' Esigin uc onemli ozelligi var:
#'   - Ithalatci basina, takvim yili boyunca KUMULATIFTIR
#'   - TUM CN kodlari toplaminda gecerlidir, urun basina degil
#'   - Yil icinde asilirsa, o yil ithal edilen TUM mallar yukumlu hale gelir
#'     (esik asilmadan once ithal edilenler dahil)
#'
#' Bu fonksiyon tek bir miktari kontrol eder; ithalatcinin yillik toplamini
#' bilemez. Sonucu "bu miktar tek basina esigin altinda" diye okuyun.
#'
#' Muafiyet elektrik ve hidrojen ithalatina UYGULANMAZ.
#'
#' @param quantity Net kutle (ton).
#' @param threshold Esik deger (ton). Varsayilan 50.
#' @param sektor Sektor adi; "hydrogen" ise muafiyet uygulanmaz.
#' @return Mantiksal vektor: TRUE ise (tek basina) esigin altinda.
is_de_minimis <- function(quantity, threshold = 50, sektor = NULL) {
  if (!is.null(sektor) &&
        tolower(trimws(sektor)) %in% c("hydrogen", "hidrojen", "electricity",
                                       "elektrik")) {
    return(rep(FALSE, length(quantity)))
  }
  # "does not cumulatively exceed" (Rehber No. 1, s.23): tam 50 ton muaftir.
  quantity <= threshold
}
