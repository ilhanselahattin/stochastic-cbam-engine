#  stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
#  SPDX-License-Identifier: AGPL-3.0-or-later
#
#  Bu dosya GNU Affero General Public License v3 (ya da sonraki bir surum)
#  kosullariyla dagitilir; HICBIR GARANTI VERILMEZ. Ayrintilar: LICENSE
#  EK SART (AGPL 7(b)): yazar atiflari ve telif bildirimleri korunmalidir.
#  Bkz. NOTICE ve LICENSE-ADDITIONAL-TERMS.md

#  Tarayici surumu icin veri disa aktarimi
#
#  Calistirma:  Rscript tools/web_veri.R            (proje kokunden)
#               Rscript tools/web_veri.R --kontrol  (yalnizca guncel mi diye bakar)
#
#  Tarayicidaki hesap makinesi (hesaplayici.js + cbam-motor.js) R calistirmaz.
#  Ihtiyac duydugu her sey buradan uretilen JSON dosyalarindan gelir:
#
#    data/web/meta.json        mevzuat takvimi (CBAM faktoru, mark-up), de minimis
#                              esigi ve belirsizlik varsayimlari - motorun KENDI
#                              fonksiyonlarindan ve varsayilan argumanlarindan
#    data/web/ulkeler.json     varsayilan deger tablosundaki ulkeler
#    data/web/dv/<ulke>.json   ulke basina varsayilan emisyon degerleri (CSV'nin aynisi)
#    data/web/bm/<fasil>.json  CN fasli basina benchmark satirlari (CSV'nin aynisi)
#    data/web/ornekler.json    ALTIN SONUCLAR: R motorunun ornek girdilerdeki ciktilari.
#                              tests/test_web.mjs, JavaScript motorunu bunlarla
#                              karsilastirir; iki taraf ayrisirsa test kalir.
#
#  Sayilar CSV'deki metin aynen korunarak yazilir; R'nin as.numeric() ile
#  JavaScript'in Number() fonksiyonu ayni metni ayni sayiya cevirir.

if (!file.exists("load_all.R")) {
  stop("Proje kokunden calistirin: Rscript tools/web_veri.R")
}
suppressMessages(source("load_all.R"))

kontrol <- "--kontrol" %in% commandArgs(trailingOnly = TRUE)
HEDEF <- file.path("data", "web")

# --- Kucuk JSON yazicisi (base R; jsonlite bagimliligi olmasin) ------------
js_metin <- function(s) {
  s <- enc2utf8(as.character(s))
  s <- gsub("\\", "\\\\", s, fixed = TRUE)
  s <- gsub("\"", "\\\"", s, fixed = TRUE)
  s <- gsub("\n", "\\n", s, fixed = TRUE)
  s <- gsub("\r", "\\r", s, fixed = TRUE)
  s <- gsub("\t", "\\t", s, fixed = TRUE)
  paste0("\"", s, "\"")
}
#  En kisa ve geri donuste birebir ayni sayiyi veren yazim: once 15 anlamli
#  basamak denenir, ayni double'a donmuyorsa 17 basamak kullanilir.
js_sayi <- function(x) {
  vapply(x, function(v) {
    if (is.na(v)) return("null")
    k <- formatC(v, digits = 15, format = "g")
    if (as.numeric(k) == v) trimws(k) else sprintf("%.17g", v)
  }, "")
}
#  ham(): CSV'deki sayi metnini oldugu gibi yazar (bos -> null).
ham <- function(x) structure(list(x), class = "ham_sayi")
json <- function(x) {
  if (is.null(x)) return("null")
  if (inherits(x, "ham_sayi")) {
    v <- trimws(x[[1]])
    if (is.na(v) || !nzchar(v)) return("null")
    if (is.na(suppressWarnings(as.numeric(v)))) stop("sayi degil: ", v)
    return(v)
  }
  if (is.list(x)) {
    if (!is.null(names(x)) && all(nzchar(names(x)))) {
      return(paste0("{", paste0(js_metin(names(x)), ":",
                                vapply(x, json, ""), collapse = ","), "}"))
    }
    return(paste0("[", paste(vapply(x, json, ""), collapse = ","), "]"))
  }
  tek <- !inherits(x, "AsIs") && length(x) == 1
  ogeler <- if (is.character(x)) {
    ifelse(is.na(x), "null", js_metin(x))
  } else if (is.logical(x)) {
    ifelse(is.na(x), "null", ifelse(x, "true", "false"))
  } else {
    js_sayi(x)
  }
  if (tek) ogeler else paste0("[", paste(ogeler, collapse = ","), "]")
}

uretilen <- list()
yaz <- function(yol, icerik) {
  uretilen[[yol]] <<- paste0(icerik, "\n")
}

# --- meta.json: takvim ve varsayimlar motorun kendisinden -------------------
yillar <- 2026:2034
sektorler <- sort(unique(cbam_default_intensities()$sektor))
f_tahmin <- formals(cbam_estimate)
f_piyasa <- formals(simulate_market)
f_web <- formals(cbam_web_rapor)
meta <- list(
  surum = cbam_data_version(),
  yillar = I(yillar),
  cbam_faktoru = I(cbam_factor_official(yillar)),
  markup = list(
    yillar = I(2026:2028),
    genel = I(cbam_default_markup(2026:2028)),
    sektor = as.list(setNames(
      lapply(sektorler, function(s) I(cbam_default_markup(2026:2028, s))), sektorler))),
  de_minimis = list(
    esik = eval(formals(is_de_minimis)$threshold),
    # Web yolunda (CN kodu ile, urun referansi olmadan) sektor bilgisi
    # is_de_minimis()'e verilmez: cbam_estimate(reference = NULL).
    # Tarayici surumu bu davranisi birebir izler.
    web_yolunda_sektor_verilir = FALSE),
  diger_ulke = CBAM_DIGER_ULKELER,
  belirsizlik = list(
    n_sims = eval(f_web$n_sims), seed = eval(f_web$seed),
    base_year = eval(f_tahmin$base_year), theta_sdlog = eval(f_tahmin$theta_sdlog),
    inflation_tr = eval(f_tahmin$inflation_tr), inflation_eu = eval(f_tahmin$inflation_eu),
    carbon_mu = eval(f_piyasa$carbon_mu), carbon_sigma = eval(f_piyasa$carbon_sigma),
    fx_sigma = eval(f_piyasa$fx_sigma), rho = eval(f_piyasa$rho)),
  fonksiyonel_birim = as.list(setNames(lapply(sektorler, function(s) {
    b <- cbam_fonksiyonel_birim(s); list(birim = b$birim, standart = b$standart)
  }), sektorler))
)
yaz(file.path(HEDEF, "meta.json"), json(meta))

# --- Ulkeler ve ulke basina varsayilan degerler -----------------------------
ham_dv <- cbam_read_table("varsayilan_yogunluk")
dosya_adi <- function(u) {
  s <- tolower(iconv(u, "UTF-8", "ASCII//TRANSLIT"))
  gsub("(^-|-$)", "", gsub("[^a-z0-9]+", "-", s))
}
tum_ulkeler <- unique(ham_dv$ulke)
# Sira: Turkiye, digerleri alfabetik (C yerel ayari: her makinede ayni),
# en sonda "bilinmiyor / listede yok".
digerleri <- setdiff(tum_ulkeler, c("Turkiye", CBAM_DIGER_ULKELER))
sira <- c("Turkiye", digerleri[order(toupper(digerleri), method = "radix")],
          CBAM_DIGER_ULKELER)
yaz(file.path(HEDEF, "ulkeler.json"), json(lapply(sira, function(u) {
  list(ad = u, dosya = dosya_adi(u))
})))
for (u in tum_ulkeler) {
  t <- ham_dv[ham_dv$ulke == u, ]
  satirlar <- lapply(seq_len(nrow(t)), function(k) list(
    t$cn_kodu[k], t$sektor[k], t$aciklama[k], ham(t$dogrudan[k]), ham(t$dolayli[k]),
    ham(t$toplam[k]), t$rota[k], t$kaynak_belge[k], t$kaynak_yeri[k], trimws(t$durum[k])))
  yaz(file.path(HEDEF, "dv", paste0(dosya_adi(u), ".json")), json(list(
    alanlar = I(c("cn_kodu", "sektor", "aciklama", "dogrudan", "dolayli", "toplam",
                  "rota", "kaynak_belge", "kaynak_yeri", "durum")),
    ulke = u, satirlar = satirlar)))
}

# --- Benchmark'lar (CN fasli basina, ilk 2 hane) ----------------------------
ham_bm <- cbam_read_table("benchmarks")
for (fasil in sort(unique(substr(ham_bm$cn_kodu, 1, 2)))) {
  t <- ham_bm[substr(ham_bm$cn_kodu, 1, 2) == fasil, ]
  satirlar <- lapply(seq_len(nrow(t)), function(k) list(
    t$cn_kodu[k], t$sektor[k], t$aciklama[k], ham(t$bm_column_a[k]), t$rota_a[k],
    ham(t$bm_column_b[k]), t$rota_b[k], t$kaynak_belge[k], t$kaynak_yeri[k],
    trimws(t$durum[k])))
  yaz(file.path(HEDEF, "bm", paste0(fasil, ".json")), json(list(
    alanlar = I(c("cn_kodu", "sektor", "aciklama", "bm_column_a", "rota_a",
                  "bm_column_b", "rota_b", "kaynak_belge", "kaynak_yeri", "durum")),
    satirlar = satirlar)))
}

# --- Altin sonuclar: web formunun yaptigi hesabin R'daki karsiligi ----------
#  cbam_web_rapor() ile ayni adimlar; rapor yazilmadan ham sonuclar saklanir.
ornek <- function(cn, miktar, yil, ulke, fiyat, kur) {
  girdi <- list(cn = cn, miktar = miktar, yil = yil, ulke = ulke, fiyat = fiyat, kur = kur)
  sonuc <- tryCatch({
    see <- cbam_default_see(cn, yil, ulke)
    if (is.null(see)) stop("TABLODA_YOK")
    bm <- cbam_benchmark_by_cn(cn, "B", yil = yil, rota = see$rota)
    est <- cbam_estimate(
      quantity = miktar, ei_direct = see$deger, benchmark = bm$benchmark, year = yil,
      carbon_price = fiyat, fx_rate = kur, n_sims = eval(f_web$n_sims),
      seed = eval(f_web$seed), ei_label = see$etiket, functional_unit = bm$birim)
    yillik <- cbam_yillik_yol(miktar, cn, ulke, carbon_price = fiyat)
    d <- est$deterministic
    q <- function(v, p) I(unname(stats::quantile(v, p)))
    mc <- if (is.null(est$simulation)) NULL else {
      dr <- est$simulation$draws
      list(cost_eur = q(dr$cost_eur, c(.05, .25, .5, .75, .95)),
           cost_local_today = q(dr$cost_local_today, c(.05, .5, .95)),
           cost_local = q(dr$cost_local, c(.5, .95)),
           certificates = q(dr$certificates, c(.05, .5, .95)))
    }
    list(
      see = list(temel = see$temel, markup = see$markup, deger = see$deger,
                 etiket = see$etiket, rota = see$rota, dolayli_var = see$dolayli_var,
                 cn_kodu = see$dv$cn_kodu, eslesme = see$dv$eslesme,
                 mense = see$dv$mense, yedek = see$dv$yedek, sektor = see$dv$sektor,
                 aciklama = see$dv$aciklama, kaynak = see$dv$kaynak),
      bm = list(benchmark = bm$benchmark, rota = bm$rota, not = bm$not,
                cn_kodu = bm$cn_kodu, sektor = bm$sektor, kaynak = bm$kaynak,
                secenek = bm$secenek, birim = bm$birim$birim),
      det = list(embedded = d$embedded, free_allocation = d$free_allocation,
                 certificates = d$certificates, cost_eur = d$cost_eur,
                 cost_local = d$cost_local, cost_per_tonne = d$cost_per_tonne,
                 taxed_share = d$taxed_share, de_minimis = d$de_minimis,
                 cbam_factor = est$inputs$cbam_factor, horizon = est$inputs$horizon),
      yillik = lapply(seq_len(nrow(yillik)), function(k) list(
        yil = yillik$yil[k], faktor = yillik$faktor[k], yogunluk = yillik$yogunluk[k],
        markup = yillik$markup[k], benchmark = yillik$benchmark[k],
        sertifika = yillik$sertifika[k], cost_eur = yillik$cost_eur[k])),
      mc = mc)
  }, error = function(e) list(hata = conditionMessage(e)))
  c(list(girdi = girdi), sonuc)
}

set.seed(42)
sabit <- list(
  list("72081000", 1000, 2030, "Turkiye", 80, 1),       # README ornegi
  list("72081000", 250000, 2030, "Turkiye", 80, 48),
  list("72081000", 40, 2026, "Turkiye", 80, 1),         # de minimis
  list("72081000", 50, 2027, "Turkiye", 80, 1),         # tam esik: muaf
  list("72081000", 51, 2027, "Turkiye", 80, 1),
  list("72081000", 1000, 2034, "Turkiye", 0, 1),        # fiyat 0
  list("28141000", 5000, 2026, "Turkiye", 95, 1),       # gubre, %1 mark-up
  list("28041000", 30, 2028, "Turkiye", 80, 1),         # hidrojen, kucuk miktar
  list("76011000", 12000, 2031, "China", 75, 40),       # aluminyum, 2031+ benchmark notu
  list("25231000", 10000, 2029, "Turkiye", 80, 1),      # TARIC'e ayriliyor: hata
  list("2523100010", 10000, 2029, "Turkiye", 80, 1),
  list("2523100090", 10000, 2029, "India", 80, 45),
  list("99999999", 1000, 2030, "Turkiye", 80, 1),       # tabloda yok
  list("7208", 1000, 2030, "Turkiye", 80, 1),           # kisa kod
  list("72081000", 1000, 2030, CBAM_DIGER_ULKELER, 80, 1),
  list("73181500", 800, 2032, "Ukraine", 110, 1),
  list("31021010", 20000, 2033, "Egypt", 60, 50))
ornek_satir <- ham_dv[sample(nrow(ham_dv), 160), ]
rastgele <- lapply(seq_len(nrow(ornek_satir)), function(k) list(
  ornek_satir$cn_kodu[k], sample(c(45, 120, 3000, 75000), 1), sample(yillar, 1),
  ornek_satir$ulke[k], sample(c(55, 80, 140), 1), sample(c(1, 1, 47.5), 1)))
vakalar <- c(sabit, rastgele)
yaz(file.path(HEDEF, "ornekler.json"), json(list(
  surum = cbam_data_version(),
  aciklama = paste("R motorunun (cbam_web_rapor ile ayni adimlar) ornek girdilerdeki",
                   "ciktilari. tests/test_web.mjs bunlarla karsilastirir."),
  vakalar = lapply(vakalar, function(v) do.call(ornek, unname(v))))))

# --- Yaz ya da karsilastir ---------------------------------------------------
#  ornekler.json --kontrol disinda: belirsizlik yuzdelikleri exp()/log() ile
#  hesaplanir ve isletim sistemine gore son basamakta farklilasabilir. Bu dosya
#  yalnizca test girdisidir; eskirse tests/test_web.mjs zaten kalir.
KONTROL_DISI <- file.path(HEDEF, "ornekler.json")
farkli <- character(0)
for (yol in names(uretilen)) {
  if (kontrol && yol %in% KONTROL_DISI) next
  eski <- if (file.exists(yol)) paste0(paste(readLines(yol, encoding = "UTF-8", warn = FALSE),
                                             collapse = "\n"), "\n") else NA
  if (!identical(eski, uretilen[[yol]])) {
    farkli <- c(farkli, yol)
    if (!kontrol) {
      dir.create(dirname(yol), recursive = TRUE, showWarnings = FALSE)
      con <- file(yol, open = "wb"); writeBin(charToRaw(enc2utf8(uretilen[[yol]])), con); close(con)
    }
  }
}
eski_dosyalar <- setdiff(list.files(HEDEF, recursive = TRUE, full.names = TRUE), names(uretilen))
if (kontrol) {
  if (length(farkli) || length(eski_dosyalar)) {
    cat("data/web guncel degil. Calistirin: Rscript tools/web_veri.R\n")
    cat(paste0("  ", c(farkli, eski_dosyalar), "\n"), sep = "")
    quit(status = 1)
  }
  cat(sprintf("data/web guncel (%d dosya; ornekler.json haric).\n",
              length(uretilen) - length(KONTROL_DISI)))
} else {
  if (length(eski_dosyalar)) file.remove(eski_dosyalar)
  cat(sprintf("data/web: %d dosya, %d degisti.\n", length(uretilen), length(farkli)))
}
