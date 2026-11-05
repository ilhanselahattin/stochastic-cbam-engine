#!/usr/bin/env Rscript
#
#  stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
#  SPDX-License-Identifier: AGPL-3.0-or-later
#
#  Bu dosya GNU Affero General Public License v3 (ya da sonraki bir surum)
#  kosullariyla dagitilir; HICBIR GARANTI VERILMEZ. Ayrintilar: LICENSE
#  EK SART (AGPL 7(b)): yazar atiflari ve telif bildirimleri korunmalidir.
#  Bkz. NOTICE ve LICENSE-ADDITIONAL-TERMS.md
#
#  CBAM HESAP MAKINESI - komut satiri arayuzu
#
#  Kullanim:
#    Rscript hesapla.R --miktar 250000 --yogunluk 1.95 --benchmark 1.288 \
#                      --yil 2030 --karbon-fiyati 80 --kur 48
#
#    Rscript hesapla.R --rota bof --miktar 250000 --yil 2030 --kur 48
#    Rscript hesapla.R --yardim
#
#  Bu dosya yalnizca girdi ayristirma ve yardim metni icerir; hesabin
#  tamami R/calculator.R icindedir.

suppressWarnings(suppressMessages(source("load_all.R")))

# Urun tanimlari data/urunler.csv ve data/benchmarks.csv icinden gelir;
# bu dosyada gomulu deger yoktur. Kaynak belgeler data-raw/mevzuat/ altinda.

yardim <- function() {
  cat("
CBAM HESAP MAKINESI
===================

Kendi rakamlarinizi girin, yillik CBAM maliyetinizi hesaplayin.

KULLANIM
  Rscript hesapla.R [secenekler]

ZORUNLU
  --miktar <ton>          AB'ye yillik ihracat miktari

  ve benchmark icin asagidakilerden biri:
  --cn <kod>              CN kodunuz (gumruk beyaninizda yazar). Benchmark
                          resmi AB tablosundan otomatik gelir. ONERILEN.
  --urun <kod>            Hazir urun tanimi. Kodlar icin: --urunler
  --benchmark <tCO2e/ton> Benchmark'i elle verin

  --yogunluk <tCO2e/ton>  Kendi olctugunuz dogrudan emisyon yogunlugunuz.
                          Vermezseniz mevzuatin VARSAYILAN degeri kullanilir
                          (Default Values Act) ve mevzuat geregi yila gore
                          artirilir (mark-up: 2026 %10, 2027 %20, 2028+ %30;
                          gubrede %1). Kendi degerinizi vermek genelde
                          lehinizedir; ona mark-up uygulanmaz.
  --ulke <ad>             Mense ulke (varsayilan: Turkiye). 122 ulke var, liste
                          icin --ulkeler. Listede yoksa ya da bilinmiyorsa:
                          --ulke diger
  --rota <harf>           Uretim rotasi, benchmark birden fazlaysa (ornek: C =
                          yuksek firin, D = DRI/EAF, E = hurda/EAF). Verilmezse
                          ulkenin varsayilan rotasi kullanilir.

  --sutun <A|B>           Benchmark sutunu (varsayilan: B)
                            B = tum uretim zinciri (cevherden urune kendi
                                ureten entegre tesis)
                            A = tek uretim sureci (yalnizca son islemi
                                yapan tesis, ornek sadece haddeleme)
                          Yanlis sutun 30 kata varan hata demektir.

ISTEGE BAGLI
  --yil <yil>             Yukumluluk yili           (varsayilan: 2026)
  --karbon-fiyati <EUR>   EU ETS fiyati             (varsayilan: 80)
  --kur <TRY/EUR>         Doviz kuru                (varsayilan: 1, yalniz EUR)
  --odenen-karbon-fiyati <EUR>
                          Mensede fiilen odenmis karbon FIYATI, MAL TONU
                          basina EUR (SECPP). Miktar degil FIYAT. Iade ve
                          tazminatlar dusulmus olmali. CBAM Tuzugu Md. 9.
  --sertifika-referans-fiyati <EUR>
                          CBAM sertifikasi referans fiyati (EUR/tCO2e).
                          Odenen karbon verildiyse ZORUNLU - odenen fiyat
                          buna bolunerek tCO2e'ye cevrilir.
  --dolayli <tCO2e/ton>   Elektrik kaynakli dolayli emisyon
  --dolayli-dahil         Dolayli emisyonu hesaba kat
  --sacilim <sd>          Tesis verimliligi sacilimi (varsayilan: 0.20)
  --baz-yil <yil>         Fiyatlarin gozlendigi yil (varsayilan: 2026)
  --simulasyon <n>        Simulasyon sayisi         (varsayilan: 50000)
  --tohum <n>             Rastgele sayi tohumu      (varsayilan: 2026)
  --kesin                 Belirsizlik hesaplamadan yalniz deterministik sonuc
  --rapor <dosya.html>    Paylasilabilir HTML rapor uret
  --firma <ad>            Raporun ustunde gorunecek firma adi
  --not <metin>           Raporun Varsayimlar kutusuna eklenecek not(lar);
                          birden fazlasi ';' ile ayrilir
  --urunler               Referans tablosundaki urunleri listele
  --ulkeler               Varsayilan deger tablosundaki ulkeleri listele
  --yardim                Bu metni goster

ORNEKLER
  # CN kodunuz ve kendi tesis yogunlugunuzla (ONERILEN yol)
  Rscript hesapla.R --cn 72081000 --yogunluk 1.95 --miktar 250000 \\
                    --yil 2030 --karbon-fiyati 80 --kur 48

  # Yalnizca son islemi yapiyorsaniz (ornek: sadece haddeleme)
  Rscript hesapla.R --cn 72081000 --yogunluk 0.08 --sutun A \\
                    --miktar 250000 --yil 2030

  # Ham aluminyum, hazir urun tanimiyla
  Rscript hesapla.R --urun alu-ham --miktar 15000 --yil 2030 --kur 48

  # Paylasilabilir HTML rapor
  Rscript hesapla.R --cn 72081000 --yogunluk 1.95 --miktar 250000 \\
                    --yil 2030 --kur 48 --firma \'Ornek Celik A.S.\' \\
                    --rapor cikti/rapor.html

  # Turkiye'de karbon odemesi yapilmis ise (fiyat, miktar degil)
  Rscript hesapla.R --cn 72081000 --miktar 250000 --yil 2030 \\
                    --odenen-karbon-fiyati 12.5 --sertifika-referans-fiyati 80

NOT
  Referans degerlerin her biri kaynagini tasir ve ciktida gosterilir.
  Kaynak belgeler data-raw/mevzuat/ altindadir.
  Henuz dogrulanmamis degerler ciktida acikca isaretlenir.
  Cikan sayilar yatirim veya beyan karari icin tek basina yeterli degildir.

")
}

# --- Argüman ayristirma -----------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0 || "--yardim" %in% args || "--help" %in% args) {
  yardim()
  quit(status = 0)
}

if ("--ulkeler" %in% args) {
  dv <- cbam_default_intensities()
  n <- tapply(!is.na(dv$dogrudan), dv$ulke, sum)
  n <- n[names(n) != CBAM_DIGER_ULKELER]
  cat(sprintf("\nVarsayilan deger tablosu: %d ulke + '%s'\n", length(n),
              CBAM_DIGER_ULKELER))
  cat(sprintf("Kaynak: %s (Default Values Act Ek I)\n\n", dv$kaynak_belge[1]))
  cat(sprintf("  %-40s %s\n", "ULKE (--ulke ile)", "DEGERLI KOD"))
  for (k in names(n)) cat(sprintf("  %-40s %5d\n", k, n[[k]]))
  cat("\n  Listede olmayan ulke ya da menseyi bilinmeyen mal: --ulke diger\n")
  cat("  Ulke sayfasinda olmayan ya da '-' olan mal icin de otomatik olarak\n")
  cat("  'Other countries and territories' kullanilir (Rehber No. 3 s.114).\n")
  cat("  CBAM'den muaf: Izlanda, Norvec, Lihtenstayn, Isvicre (+ Ek III bolgeleri).\n\n")
  quit(status = 0)
}

if ("--urunler" %in% args) {
  u <- cbam_products()
  b <- cbam_benchmarks()
  cat(sprintf("\nReferans veri paketi: %s\n", cbam_data_version()))
  cat(sprintf("Benchmark tablosu   : %d CN kodu, %d deger (resmi, dogrulandi)\n\n",
              length(unique(b$cn_kodu)), nrow(b)))
  bicim <- function(v) if (is.na(v)) "-" else sprintf("%.3f", v)
  cat(sprintf("  %-16s %-30s %-10s %8s %8s %8s\n",
              "KOD", "URUN", "CN", "YOGUNL.", "BM(A)", "BM(B)"))
  cat("  ", strrep("-", 86), "\n", sep = "")
  sektor_onceki <- ""
  for (k in seq_len(nrow(u))) {
    if (u$sektor[k] != sektor_onceki) {
      cat(sprintf("  [%s]\n", toupper(u$sektor[k])))
      sektor_onceki <- u$sektor[k]
    }
    j <- match(substr(u$cn_kodu[k], 1, 8), b$cn_kodu)
    cat(sprintf("  %-16s %-30s %-10s %8s %8s %8s\n",
                u$urun_kodu[k], u$urun_adi[k], u$cn_kodu[k],
                bicim(u$varsayilan_yogunluk[k]),
                if (is.na(j)) "-" else bicim(b$bm_column_a[j]),
                if (is.na(j)) "-" else bicim(b$bm_column_b[j])))
  }
  hazir <- sum(!is.na(u$varsayilan_yogunluk))
  cat("\n  Benchmark'lar : CBAM Benchmarks tablosu (resmi)\n")
  yedek <- vapply(u$cn_kodu, function(cn) isTRUE(tryCatch(
    cbam_default_intensity(cn)$yedek, error = function(e) FALSE)), logical(1))
  cat(sprintf("  Yogunluklar   : Default Values Act, Turkiye (%d/%d urunde var)\n",
              hazir, nrow(u)))
  if (any(yedek)) {
    cat(sprintf("                  %s: Turkiye sayfasinda yok -> Other countries tablosu\n",
                paste(u$urun_kodu[yedek], collapse = ", ")))
  }
  cat("\n  YOGUNL. mark-up'siz TEMEL varsayilan degerdir; hesapta yila gore\n")
  cat("  %10 (2026), %20 (2027), %30 (2028+) artirilir, gubrede %1.\n")
  cat("  Kendi olctugunuz degeri --yogunluk ile verirseniz mark-up\n")
  cat("  uygulanmaz ve maliyetiniz buyuk ihtimalle duser.\n")
  cat("\n  Urununuz listede yoksa CN kodunuzla dogrudan hesaplayin:\n")
  cat("    Rscript hesapla.R --cn <kod> --miktar <ton>\n\n")
  quit(status = 0)
}

bayraklar <- c("--dolayli-dahil", "--kesin")
opt <- list()
i <- 1
while (i <= length(args)) {
  a <- args[i]
  if (!startsWith(a, "--")) {
    cat(sprintf("HATA: beklenmeyen girdi '%s'. --yardim ile secenekleri gorun.\n", a))
    quit(status = 1)
  }
  anahtar <- substring(a, 3)
  if (a %in% bayraklar) {
    opt[[anahtar]] <- TRUE
    i <- i + 1
  } else {
    if (i + 1 > length(args)) {
      cat(sprintf("HATA: '%s' bir deger bekliyor.\n", a))
      quit(status = 1)
    }
    opt[[anahtar]] <- args[i + 1]
    i <- i + 2
  }
}

sayi_metin <- function(anahtar, varsayilan = NULL) {
  if (is.null(opt[[anahtar]])) return(varsayilan)
  trimws(opt[[anahtar]])
}

sayi <- function(anahtar, varsayilan = NULL) {
  if (is.null(opt[[anahtar]])) return(varsayilan)
  v <- suppressWarnings(as.numeric(opt[[anahtar]]))
  if (is.na(v)) {
    cat(sprintf("HATA: --%s sayisal olmali, '%s' verildi.\n",
                anahtar, opt[[anahtar]]))
    quit(status = 1)
  }
  v
}

# --- Girdi dogrulama --------------------------------------------------------
miktar <- sayi("miktar")
if (is.null(miktar)) {
  cat("HATA: --miktar zorunlu. --yardim ile ornekleri gorun.\n")
  quit(status = 1)
}

yogunluk  <- sayi("yogunluk")
benchmark <- sayi("benchmark")
sacilim   <- sayi("sacilim")
referans  <- NULL

sutun <- if (is.null(opt[["sutun"]])) "B" else toupper(trimws(opt[["sutun"]]))
if (!sutun %in% c("A", "B")) {
  cat("HATA: --sutun 'A' ya da 'B' olmali. --yardim ile aciklamayi gorun.\n")
  quit(status = 1)
}

hata_ver <- function(e) {
  cat(sprintf("HATA: %s\n", conditionMessage(e)))
  quit(status = 1)
}

birim <- NULL
kaynaklar <- NULL
yogunluk_etiketi <- "dogrudan"

yil <- sayi("yil", 2026)
if (yil < 2026) {
  cat("HATA: --yil 2026 ya da sonrasi olmali. CBAM mali yukumlulugu kesin\n")
  cat("      donemle (2026) baslar; oncesinde yalnizca raporlama vardir.\n")
  quit(status = 1)
}

# Varsayilan degerin hesaba girecek hali (mark-up dahil) tek bir yerden gelir:
# cbam_default_see(). --cn ve --urun yollari ayni sayiyi uretmek zorunda.
varsayilan_yaz <- function(s) {
  dv <- s$dv
  if (s$dolayli_var) {
    cat(sprintf("Varsayilan yogunluk = %s tCO2e/ton (%s, TOPLAM)\n",
                fmt_num(s$temel, 3), dv$ulke))
    cat(sprintf("  dogrudan %s + dolayli %s\n",
                fmt_num(dv$dogrudan, 3), fmt_num(dv$dolayli, 3)))
    cat("  Bu sektorde dolayli (elektrik) emisyon CBAM kapsamindadir.\n")
  } else {
    cat(sprintf("Varsayilan yogunluk = %s tCO2e/ton (%s, dogrudan)\n",
                fmt_num(s$temel, 3), dv$ulke))
    cat("  Bu sektorde dolayli emisyon CBAM kapsami disindadir (Ek II).\n")
  }
  if (isTRUE(dv$yedek)) {
    cat(sprintf(paste0(
      "  !! %s sayfasinda bu mal icin deger yok (listede degil ya da '-').\n",
      "     Kural geregi 'Other countries and territories' tablosu kullanildi\n",
      "     (Rehber No. 3 s.114). Bu deger genelde ulke degerinden yuksektir.\n"),
      dv$mense))
  }
  cat(sprintf("  + %d mark-up'i %%%s  ->  %s tCO2e/ton hesapta kullanilir\n",
              yil, fmt_num(100 * s$markup, 0), fmt_num(s$deger, 3)))
  cat("    (Rehber No. 3 s.113: varsayilan degerler 2026 %10, 2027 %20,\n")
  cat("     2028+ %30 artirilir; gubrede %1)\n")
  cat(sprintf("  Kaynak: %s | CN %s (%s eslesme)\n",
              dv$kaynak, dv$cn_kodu, dv$eslesme))
  cat("  !! Bu mevzuatin VARSAYILAN degeridir, tesisinizin degeri degildir.\n")
  cat("     Kendi olctugunuz degeri --yogunluk ile verirseniz mark-up\n")
  cat("     uygulanmaz ve maliyetiniz buyuk ihtimalle duser.\n")
}

if (!is.null(opt[["cn"]])) {
  # CN kodu yolu: benchmark resmi tablodan gelir. Yogunluk verilmediyse
  # mevzuatin varsayilan degeri kullanilir - bir tahmin degil, Default
  # Values Act'in ongordugu deger; olcmemeyi odullendirmemek icin yuksek.
  see <- tryCatch(cbam_default_see(opt[["cn"]], yil, sayi_metin("ulke", "Turkiye")),
                  error = hata_ver)
  # Benchmark rotasi: kullanici verdiyse o, yoksa ulkenin varsayilan rotasi
  # (Default Values Act Ek I son sutun; Rehber No. 4 s.20).
  rota <- sayi_metin("rota", if (is.null(see)) NULL else see$rota)
  bm <- tryCatch(cbam_benchmark_by_cn(opt[["cn"]], sutun, yil = yil, rota = rota),
                 error = hata_ver)
  kaynaklar <- list(
    yogunluk = "kullanici girdisi (tesis verisi)",
    urun = sprintf("CN %s - %s - mense %s", gsub("[^0-9]", "", opt[["cn"]]),
                   if (!is.null(see)) see$dv$aciklama else bm$aciklama,
                   if (!is.null(see)) see$dv$mense else sayi_metin("ulke", "Turkiye")))
  if (is.null(benchmark)) {
    benchmark <- bm$benchmark
    kaynaklar$benchmark <- sprintf("%s, CN %s, Column %s%s", bm$kaynak,
                                   bm$cn_kodu, bm$sutun,
                                   if (nzchar(bm$rota)) paste0(" ", bm$rota) else "")
  }
  birim <- bm$birim

  cat(sprintf("\nCN %s | %s\n", bm$cn_kodu, bm$aciklama))
  cat(sprintf("Benchmark Column %s%s = %s tCO2e/ton | Kaynak: %s\n",
              bm$sutun, if (nzchar(bm$rota)) paste0(" ", bm$rota) else "",
              fmt_num(bm$benchmark, 3), bm$kaynak))
  if (nzchar(bm$not)) cat(sprintf("  Not: %s\n", bm$not))

  if (is.null(yogunluk)) {
    if (is.null(see)) {
      cat("\nHATA: bu CN kodu icin varsayilan yogunluk tablosunda kayit yok.\n")
      cat("      --yogunluk ile kendi tesis verinizi verin.\n")
      quit(status = 1)
    }
    yogunluk <- see$deger
    yogunluk_etiketi <- see$etiket
    kaynaklar$yogunluk <- sprintf(
      "%s, CN %s | temel %s + %%%s mark-up (Rehber No. 3 s.113)",
      see$dv$kaynak, see$dv$cn_kodu, fmt_num(see$temel, 3),
      fmt_num(100 * see$markup, 0))
    kaynaklar$ei_temel <- see$temel
    varsayilan_yaz(see)
  }
} else if (!is.null(opt[["urun"]])) {
  referans <- tryCatch(
    cbam_product(tolower(trimws(opt[["urun"]])), sutun, yil = yil),
    error = function(e) {
      cat(sprintf("HATA: %s\n", conditionMessage(e)))
      cat("      --urunler ile mevcut kodlari listeleyin.\n")
      quit(status = 1)
    }
  )
  # Kullanicinin verdigi deger her zaman referans degerin onune gecer:
  # tesis verisi sektor ortalamasindan iyidir.
  if (is.null(yogunluk)) {
    yogunluk <- referans$varsayilan_yogunluk
    yogunluk_etiketi <- referans$yogunluk_etiketi
  } else {
    referans$yogunluk_kaynak <- "kullanici girdisi (tesis verisi)"
  }
  if (is.null(benchmark)) benchmark <- referans$benchmark
  if (is.null(sacilim))   sacilim   <- referans$varsayilan_sacilim
  birim <- tryCatch(cbam_benchmark_by_cn(referans$cn_kodu, sutun)$birim,
                    error = function(e) NULL)
}

# Kendi olcum degeri + rota yok: ulkenin varsayilan rotasi varsayilir. Hurda-EAF
# ureticisinde bu, benchmark'i kat kat yuksek gosterip maliyeti sifira kadar
# dusurebilir; kullanici bilmeli.
rota_uyarisi <- NULL
cn_kontrol <- if (!is.null(opt[["cn"]])) opt[["cn"]] else if (!is.null(referans)) referans$cn_kodu
if (!is.null(sayi("yogunluk")) && is.null(opt[["rota"]]) && is.null(sayi("benchmark")) &&
    !is.null(cn_kontrol)) {
  r_gosterge <- tryCatch(cbam_benchmark_by_cn(
    cn_kontrol, sutun, yil = yil,
    rota = tryCatch(cbam_default_see(cn_kontrol, yil, sayi_metin("ulke", "Turkiye"))$rota,
                    error = function(e) NULL))$rota, error = function(e) "")
  if (grepl("[A-L]", r_gosterge)) {
    rota_uyarisi <- sprintf(paste0(
      "Kendi degerinizle hesapta uretim rotasi %s varsayildi. Tesisiniz farkli ",
      "bir rotayla uretiyorsa (ornek hurda-EAF) --rota ile belirtin; aksi halde ",
      "maliyet olmasi gerekenden cok dusuk cikabilir."), r_gosterge)
    cat(sprintf("\n!! %s\n", rota_uyarisi))
  }
}

if (is.null(yogunluk) || is.null(benchmark)) {
  cat("HATA: benchmark icin --cn, --urun ya da --benchmark verin;\n")
  cat("      emisyon yogunlugu icin --yogunluk verin.\n")
  cat("      --urunler ile hazir tanimlari, --yardim ile ornekleri gorun.\n")
  quit(status = 1)
}
if (is.null(sacilim)) sacilim <- 0.20

# --- Hesap ------------------------------------------------------------------
# Motor katmani hatalari kullaniciya R yigin izi olarak degil, tek satirlik
# anlasilir mesaj olarak gosterilir.
sonuc <- tryCatch(
  cbam_estimate(
    quantity           = miktar,
    ei_direct          = yogunluk,
    benchmark          = benchmark,
    year               = yil,
    carbon_price       = sayi("karbon-fiyati", 80),
    fx_rate            = sayi("kur", 1),
    carbon_price_paid    = sayi("odenen-karbon-fiyati", 0),
    cbam_reference_price = sayi("sertifika-referans-fiyati", NULL),
    ei_indirect        = sayi("dolayli", 0),
    include_indirect   = isTRUE(opt[["dolayli-dahil"]]),
    uncertainty        = !isTRUE(opt[["kesin"]]),
    theta_sdlog        = sacilim,
    base_year          = sayi("baz-yil", 2026),
    n_sims             = sayi("simulasyon", 50000),
    seed               = sayi("tohum", 2026),
    reference          = referans,
    functional_unit    = birim,
    ei_label           = yogunluk_etiketi,
    kaynaklar          = kaynaklar
  ),
  error = function(e) {
    cat(sprintf("HATA: %s\n", conditionMessage(e)))
    cat("      --yardim ile secenekleri ve ornekleri gorun.\n")
    quit(status = 1)
  }
)

print(sonuc)

if (!is.null(opt[["rapor"]])) {
  # Yillara gore maliyet yolu: ayni girdiler, her yil o yilin mevzuati.
  cn_yol <- if (!is.null(opt[["cn"]])) opt[["cn"]] else if (!is.null(referans)) referans$cn_kodu
  yillik <- tryCatch(
    cbam_yillik_yol(
      quantity = miktar, cn_kodu = cn_yol, ulke = sayi_metin("ulke", "Turkiye"),
      ei = if (!is.null(sayi("yogunluk")) || is.null(cn_yol)) yogunluk else NULL,
      benchmark = sayi("benchmark", if (is.null(cn_yol)) benchmark else NULL),
      sutun = sutun, rota = sayi_metin("rota"),
      carbon_price = sayi("karbon-fiyati", 80),
      carbon_price_paid = sayi("odenen-karbon-fiyati", 0),
      cbam_reference_price = sayi("sertifika-referans-fiyati", NULL),
      ei_indirect = sayi("dolayli", 0),
      include_indirect = isTRUE(opt[["dolayli-dahil"]])),
    error = function(e) NULL)

  # Kullanicinin vermedigi her deger raporda acikca yazilir: okuyan, hangi
  # sayinin aracin varsayimi oldugunu bilmeli.
  girilmedi <- function(k) is.null(opt[[k]])
  notlar <- c(
    if (!is.null(opt[["not"]])) trimws(strsplit(opt[["not"]], ";", fixed = TRUE)[[1]]),
    rota_uyarisi,
    if (girilmedi("karbon-fiyati"))
      "Karbon fiyati 80 EUR/tCO2e: aracin varsayilani, girilmedi. Gercek maliyet o yilin CBAM sertifika fiyatina baglidir.",
    if (girilmedi("yil")) "Yukumluluk yili 2026: aracin varsayilani, girilmedi.",
    if (girilmedi("yogunluk") && !is.null(cn_yol))
      "Emisyon yogunlugu: AB varsayilan degeri + mark-up (tesis olcumu girilmedi).",
    if (girilmedi("kur")) "Doviz kuru girilmedi: yalnizca EUR raporlandi.",
    if (!is.null(sonuc$simulation)) sprintf(paste0(
      "Belirsizlik parametreleri (aracin varsayilanlari, kaynagi DOGRULANMADI): ",
      "karbon fiyati yillik surukleme %%2, oynaklik %%35; kur oynakligi %%18, ",
      "kur suruklemesi enflasyon farkindan (TR %%25, AB %%2); fiyat-kur ",
      "korelasyonu 0,20; tesis verimliligi sacilimi %s; %s senaryo, tohum %s."),
      fmt_num(sacilim, 2), fmt_num(sayi("simulasyon", 50000)),
      as.character(sayi("tohum", 2026)))
  )

  yol <- tryCatch(
    cbam_rapor(sonuc, opt[["rapor"]], firma = opt[["firma"]],
               yillik = yillik, notlar = notlar),
    error = function(e) {
      cat(sprintf("HATA: rapor uretilemedi - %s\n", conditionMessage(e)))
      quit(status = 1)
    }
  )
  cat(sprintf("Rapor yazildi: %s\n", normalizePath(yol, winslash = "/")))
  cat("Tarayicida acip PDF olarak yazdirabilirsiniz.\n\n")
}
