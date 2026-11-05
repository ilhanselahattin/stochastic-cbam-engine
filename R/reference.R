#  stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
#  SPDX-License-Identifier: AGPL-3.0-or-later
#
#  Bu dosya GNU Affero General Public License v3 (ya da sonraki bir surum)
#  kosullariyla dagitilir; HICBIR GARANTI VERILMEZ. Ayrintilar: LICENSE
#  EK SART (AGPL 7(b)): yazar atiflari ve telif bildirimleri korunmalidir.
#  Bkz. NOTICE ve LICENSE-ADDITIONAL-TERMS.md

#  Referans Veri Katmani (Katman 0)
#
#  data/ altindaki islenmis referans tablolarini okur. Tablolarin tamami
#  data-raw/mevzuat/ icindeki resmi belgelerden elle aktarilmistir ve her
#  satir kendi kaynagini tasir (kaynak_belge + kaynak_yeri).
#
#  Tasarim kurallari:
#    - CSV kullanilir, .rda degil: git'te diff'lenir, GitHub'da okunur,
#      R olmadan da dogrulanabilir. Seffaflik misyonunun geregi.
#    - Yalnizca base R. Calisma zamaninda hicbir harici pakete bagli degil.
#    - Dogrulanmamis her deger yuksek sesle isaretlenir. Sessizce resmi
#      gorunen bir yer tutucu, bu projenin yapabilecegi en kotu hata olur.

CBAM_DATA_DIR <- "data"

#' Referans veri dizinini bul
#'
#' Betikler proje kokunden calistirilir; yine de bir ust dizine bakarak
#' analysis/ icinden calistirmayi da tolere eder.
#'
#' @return Veri dizininin yolu.
cbam_data_path <- function() {
  aday <- c(CBAM_DATA_DIR, file.path("..", CBAM_DATA_DIR))
  for (p in aday) {
    if (dir.exists(p) && file.exists(file.path(p, "urunler.csv"))) {
      return(p)
    }
  }
  stop("Referans veri bulunamadi. Proje kokunden calistirdiginizdan emin olun.")
}

#' Kullanilan referans veri paketinin surumu
#'
#' @return Surum etiketi (ornek: "params-2026.08").
cbam_data_version <- function() {
  f <- file.path(cbam_data_path(), "VERSION")
  if (!file.exists(f)) return("bilinmiyor")
  trimws(readLines(f, warn = FALSE)[1])
}

#' Referans tablosunu oku
#'
#' @param ad Dosya adi (uzantisiz).
#' @return data.frame.
cbam_read_table <- function(ad) {
  f <- file.path(cbam_data_path(), paste0(ad, ".csv"))
  if (!file.exists(f)) {
    stop(sprintf("Referans tablosu bulunamadi: %s", f))
  }
  # Varsayilan deger tablosu 122 ulkeyle ~3 MB; her aramada yeniden okumak
  # yerine dosya degismedikce bellekteki kopya kullanilir.
  anahtar <- paste(normalizePath(f), file.mtime(f))
  if (!exists(anahtar, envir = .cbam_onbellek, inherits = FALSE)) {
    assign(anahtar, utils::read.csv(f, stringsAsFactors = FALSE,
                                    colClasses = "character"),
           envir = .cbam_onbellek)
  }
  get(anahtar, envir = .cbam_onbellek, inherits = FALSE)
}

.cbam_onbellek <- new.env(parent = emptyenv())

#' Urun katalogu
#'
#' @return Urun kodu, adi, sektoru, varsayilan yogunlugu ve kaynak bilgisini
#'   iceren data.frame.
cbam_products <- function() {
  d <- cbam_read_table("urunler")
  d$varsayilan_sacilim <- as.numeric(d$varsayilan_sacilim)
  # Emisyon yogunlugu bu tabloda tutulmaz; mevzuatin varsayilan deger
  # tablosundan CN kodu uzerinden gelir. Bkz. cbam_default_see(). Buradaki
  # deger mark-up'siz TEMEL degerdir; mark-up yila baglidir, hesapta eklenir.
  d$varsayilan_yogunluk <- vapply(d$cn_kodu, function(cn) {
    s <- tryCatch(cbam_default_see(cn), error = function(e) NULL)
    if (is.null(s)) NA_real_ else s$temel
  }, numeric(1), USE.NAMES = FALSE)
  d
}

#' CBAM benchmark tablosu (CN kodu bazinda)
#'
#' Kaynak: Free Allocation Adjustment Act (CIR (EU) 2025/2620), Ek nokta 5;
#' Komisyon'un yayimladigi "CBAM Benchmarks" tablosu (6 Subat 2026).
#'
#' Iki sutun vardir ve secim hesabi ciddi sekilde degistirir:
#'   Column A : TEK bir uretim sureci icin benchmark. Yalnizca son islemi
#'              yapan tesis (ornek: sadece haddeleme) icin gecerlidir.
#'   Column B : TUM uretim zinciri icin benchmark. Cevherden urune kadar
#'              kendi ureten entegre tesis icin gecerlidir.
#'
#' Ornek (CN 72081000, sicak haddelenmis rulo): Column A = 0,044;
#' Column B = 1,370. Yanlis sutun 30 kat hata demektir.
#'
#' Bir CN kodunun birden fazla satiri olabilir (570 kodun 525'inde). Satirlar
#' resmi tablodaki gostergeyle ayrilir (Rehber No. 4, Tablo 2-2):
#'   (A)/(B)        gri / beyaz klinker-cimento
#'   (C)(D)(E)      karbon celigi: BF/BOF, DRI/EAF, hurda/EAF
#'   (F)(G)(H)      dusuk alasimli celik: BF/BOF, DRI/EAF, hurda/EAF
#'   (J)            yuksek alasimli celik (EAF)
#'   (K)/(L)        birincil / ikincil aluminyum
#'   (1)/(2)        uretim yili 2026-27 / 2028-30
#' Secim \code{cbam_benchmark_by_cn()} icinde yapilir.
#'
#' @return Benchmark satirlari ve kaynaklari (CN kodu tekrar edebilir).
cbam_benchmarks <- function() {
  d <- cbam_read_table("benchmarks")
  d$bm_column_a <- suppressWarnings(as.numeric(d$bm_column_a))
  d$bm_column_b <- suppressWarnings(as.numeric(d$bm_column_b))
  d
}

#' CN koduna gore benchmark degeri
#'
#' Kodun tek satiri varsa o dondurulur. Birden fazla satiri varsa rota ve
#' yila gore secilir (Rehber No. 4, s.17-21):
#'   - Rota harfi \code{rota} ile verilir. Varsayilan degerle calisilirken
#'     rota, Default Values Act Ek I'de ulke sayfasinin son sutunudur
#'     (bkz. \code{cbam_default_see()}). "(C)/(F)" gibi bilesik gosterge,
#'     kodda hangisi varsa onu secer.
#'   - Yil kodu: 2026-27 icin (1), 2028-30 icin (2). 2031 ve sonrasi icin
#'     resmi tabloda deger yoktur; (2) kullanilir ve \code{not} alani bunu
#'     soyler.
#'   - Rota belirlenemezse tablodaki ilk satir kullanilir ve \code{not}
#'     alternatifleri listeler - sessizce secmek yerine.
#'
#' @param cn_kodu CN kodu (metin ya da sayi; bosluklar temizlenir).
#' @param sutun \code{"B"} (tum uretim zinciri, varsayilan) ya da
#'   \code{"A"} (tek uretim sureci).
#' @param yil Uretim (raporlama) yili; NULL ise yil kodu (1) secilir.
#' @param rota Rota gostergesi, ornek \code{"C"}, \code{"(F)"} ya da
#'   \code{"(C)/(F)"}. NULL ise ilk satir.
#' @return Tek satirlik liste: deger, aciklama, sektor, rota gostergesi,
#'   kaynak, secim notu.
cbam_benchmark_by_cn <- function(cn_kodu, sutun = "B", yil = NULL, rota = NULL) {
  sutun <- toupper(trimws(sutun))
  if (!sutun %in% c("A", "B")) {
    stop("sutun 'A' (tek uretim sureci) ya da 'B' (tum zincir) olmali.")
  }
  cn <- gsub("[^0-9]", "", as.character(cn_kodu))
  if (!nzchar(cn)) {
    stop("cn_kodu bos olamaz.")
  }
  # Benchmark'lar 8 haneli CN kodundadir; 10 haneli TARIC kodu (ornek gri
  # klinker 2523100090) ilk 8 hanesiyle aranir. Gri/beyaz ayrimi rota
  # gostergesiyle (A)/(B) yapilir.
  if (nchar(cn) > 8) cn <- substr(cn, 1, 8)
  bm <- cbam_benchmarks()
  s <- bm[bm$cn_kodu == cn, ]
  if (nrow(s) == 0) {
    stop(sprintf(paste0(
      "CN kodu '%s' CBAM benchmark tablosunda yok.\n",
      "  Urununuz CBAM kapsaminda olmayabilir, ya da kodu kontrol edin.\n",
      "  Tabloda %d CN kodu tanimli (kaynak: %s)."),
      cn, length(unique(bm$cn_kodu)), bm$kaynak_belge[1]))
  }
  deger <- if (sutun == "A") s$bm_column_a else s$bm_column_b
  gosterge <- if (sutun == "A") s$rota_a else s$rota_b
  s <- s[!is.na(deger), ]; gosterge <- gosterge[!is.na(deger)]
  deger <- deger[!is.na(deger)]

  harf_al <- function(g) paste(regmatches(g, gregexpr("[A-L]", g))[[1]], collapse = "")
  harf <- vapply(gosterge, harf_al, "", USE.NAMES = FALSE)
  yil_kod <- ifelse(grepl("\\([12]\\)$", gosterge),
                    sub(".*\\(([12])\\)$", "\\1", gosterge), "")
  sec <- rep(TRUE, length(deger))
  not <- ""

  if (length(deger) > 1 && any(nzchar(harf))) {
    istenen <- if (is.null(rota)) character(0) else
      regmatches(rota, gregexpr("[A-L]", toupper(rota)))[[1]]
    uyan <- harf %in% istenen
    if (any(uyan)) {
      sec <- uyan
    } else {
      sec <- harf == harf[1]
      not <- sprintf(paste0(
        "Uretim rotasi belirlenemedi; tablodaki ilk rota %s kullanildi. ",
        "Bu kod icin diger rotalar: %s (--rota ile secin)."),
        gosterge[1], paste(unique(gosterge[harf != harf[1]]), collapse = " "))
    }
  }
  if (any(nzchar(yil_kod[sec]))) {
    istenen_yil <- if (is.null(yil) || yil <= 2027) "1" else "2"
    if (any(sec & yil_kod == istenen_yil)) sec <- sec & yil_kod == istenen_yil
    if (!is.null(yil) && yil > 2030) {
      not <- paste0(if (nzchar(not)) paste0(not, " ") else "",
                    "2031 ve sonrasi icin resmi benchmark yayimlanmadi; ",
                    "2028-30 degeri kullanildi.")
    }
  }
  i <- which(sec)[1]
  list(
    cn_kodu   = s$cn_kodu[i],
    aciklama  = s$aciklama[i],
    sektor    = s$sektor[i],
    birim     = cbam_fonksiyonel_birim(s$sektor[i]),
    sutun     = sutun,
    benchmark = deger[i],
    rota      = gosterge[i],
    secenek   = length(deger),
    not       = not,
    kaynak    = cbam_kaynak_metni(s$kaynak_belge[i], s$kaynak_yeri[i]),
    durum     = trimws(s$durum[i])
  )
}

#' Varsayilan emisyon yogunlugu tablosu
#'
#' Kaynak: Default Values Act. Ilk surum CIR (EU) 2025/2621 (16 Aralik 2025);
#' kullandigimiz Surum 2, **CIR (EU) 2026/1740** ile revize edilmis hali
#' (6 Agustos 2026, Ek I ve II). Surum bilgisi kaynak dosyanin
#' "Version History" sayfasindadir.
#'
#' Bu tablodaki degerler mark-up'siz TEMEL degerlerdir; hesapta yila gore
#' mark-up eklenir (bkz. \code{cbam_default_markup()}). Ornek: CN 28141000
#' (amonyak, Turkiye) temel toplam 2,270; %1 gubre mark-up'iyla 2,293.
#' Piyasada rastlanan 2,293 rakami (v1.0.0'da "tabloda yok" diye not
#' edilmisti) bu yuzden dogruydu - eksik olan bizdik.
#'
#' Bu degerler mevzuatin ongordugu varsayilanlardir. Kendi olctugunuz tesis
#' degeri her zaman bunlarin onune gecmelidir; varsayilanlar bilerek muhafazakar
#' (yuksek) secilir, cunku olcmemeyi odullendirmemek icin oyle tasarlanmislardir.
#'
#' @return CN kodu bazinda dogrudan/dolayli/toplam varsayilan degerler.
cbam_default_intensities <- function() {
  # Sayiya cevrilmis tablo da onbellekte tutulur: 11.670 satiri her aramada
  # yeniden cevirmek arama basina ~25 ms demekti.
  f <- file.path(cbam_data_path(), "varsayilan_yogunluk.csv")
  anahtar <- paste("sayisal", normalizePath(f), file.mtime(f))
  if (exists(anahtar, envir = .cbam_onbellek, inherits = FALSE)) {
    return(get(anahtar, envir = .cbam_onbellek, inherits = FALSE))
  }
  d <- cbam_read_table("varsayilan_yogunluk")
  # Tabloda deger girilmemis hucreler var (Komisyon o ürün icin varsayilan
  # yayimlamamis). Bos hucre NA olmali; as.numeric'in uyari uretmesi
  # kullaniciya gosterilecek bir sey degil, beklenen durum.
  sayiya <- function(x) {
    x <- trimws(as.character(x))
    x[!nzchar(x)] <- NA_character_
    suppressWarnings(as.numeric(x))
  }
  d$dogrudan <- sayiya(d$dogrudan)
  d$dolayli  <- sayiya(d$dolayli)
  d$toplam   <- sayiya(d$toplam)
  assign(anahtar, d, envir = .cbam_onbellek)
  d
}

CBAM_DIGER_ULKELER <- "Other Countries and Territories"

#' Mense ulke adini varsayilan deger tablosundaki ada cevir
#'
#' Tablo, Default Values Act Ek I'deki 122 ulke sayfasini ve menseyi
#' bilinmeyen ya da listede olmayan ulkeler icin "Other Countries and
#' Territories" tablosunu tasir. Buyuk/kucuk harf ve Turkce karakter fark
#' etmez. "bilinmiyor", "diger", "other" -> Other Countries and Territories.
#'
#' Taninmayan ad hata verir: kural geregi listede olmayan ulke "Other"
#' tablosunu kullanir, ama yazim hatasinin sessizce bu tabloya dusmesi
#' yanlis bir sonucu resmi gibi gosterirdi. Kullanici bunu acikca secmeli.
#'
#' @param ulke Ulke adi.
#' @return Tablodaki ulke adi.
cbam_ulke <- function(ulke) {
  sade <- function(s) tolower(gsub("[^a-z]", "",
                                   tolower(iconv(s, "UTF-8", "ASCII//TRANSLIT"))))
  u <- sade(ulke)
  if (u %in% c("bilinmiyor", "diger", "digerulkeler", "other", "unknown",
               sade(CBAM_DIGER_ULKELER))) {
    return(CBAM_DIGER_ULKELER)
  }
  if (u %in% c("turkey", "turkiye")) return("Turkiye")
  if (cbam_muaf_ulke(ulke)) {
    stop(sprintf(paste0(
      "'%s' CBAM kapsami disindadir: AB ETS'yi uygulayan ya da ona bagli ulke\n",
      "  (Izlanda, Norvec, Lihtenstayn, Isvicre) veya Ek III bolgesi.\n",
      "  Bu menseli mallar icin CBAM sertifikasi gerekmez (Rehber No. 1 dn.3;\n",
      "  Rehber No. 4 dn.11)."), ulke))
  }
  adlar <- unique(cbam_default_intensities()$ulke)
  i <- match(u, vapply(adlar, sade, ""))
  if (is.na(i)) {
    stop(sprintf(paste0(
      "Ulke '%s' varsayilan deger tablosunda yok.\n",
      "  Tablodaki %d ulke icin: Rscript hesapla.R --ulkeler\n",
      "  Ulkeniz gercekten listede yoksa kural geregi 'Other countries and\n",
      "  territories' tablosu kullanilir: --ulke diger (Rehber No. 3 s.114)."),
      ulke, length(adlar) - 1))
  }
  adlar[i]
}

#' CBAM'den muaf mense mi?
#'
#' AB ETS'yi uygulayan (Izlanda, Norvec, Lihtenstayn) ya da ona tam bagli
#' (Isvicre) ulkeler ile Tuzuk Ek III nokta 1 bolgeleri (Busingen,
#' Heligoland, Livigno, Ceuta, Melilla). Kaynak: Rehber No. 1 dn.3,
#' Rehber No. 4 dn.11.
#'
#' @param ulke Ulke ya da bolge adi.
#' @return Mantiksal.
cbam_muaf_ulke <- function(ulke) {
  u <- tolower(gsub("[^a-z]", "", tolower(iconv(ulke, "UTF-8", "ASCII//TRANSLIT"))))
  u %in% c("iceland", "izlanda", "norway", "norvec", "liechtenstein",
           "lihtenstayn", "switzerland", "isvicre", "busingen", "heligoland",
           "livigno", "ceuta", "melilla")
}

#' CN koduna gore varsayilan emisyon yogunlugu
#'
#' Kurallar (Rehber No. 3 s.113-114):
#'   - 4 ya da 6 haneli kod, o onekle baslayan tum 8 haneli kodlari kapsar:
#'     en uzun onek eslesmesi aranir (72081000 -> 72081000, 720810, 7208).
#'   - Mal ulke sayfasinda yoksa ya da alani "-" ise "Other countries and
#'     territories" tablosu kullanilir. "-" satirlari tabloda bos degerle
#'     durur; arama orada durur ve Other'a gecer (daha genel bir satira
#'     degil).
#'   - Tablo 10 haneli TARIC kodu kullaniyorsa (beyaz/gri klinker gibi) ve
#'     8 haneli kod birden fazlasina denk geliyorsa sessizce secilmez: hata
#'     mesaji secenekleri listeler.
#'
#' @param cn_kodu CN ya da TARIC kodu.
#' @param ulke Mense ulke (bkz. \code{cbam_ulke()}); varsayilan "Turkiye".
#' @return Bulunursa liste, hicbir tabloda yoksa \code{NULL}. \code{yedek}
#'   TRUE ise deger "Other countries and territories" tablosundan gelmistir.
cbam_default_intensity <- function(cn_kodu, ulke = "Turkiye") {
  cn <- gsub("[^0-9]", "", as.character(cn_kodu))
  if (!nzchar(cn)) return(NULL)
  ulke <- cbam_ulke(ulke)
  dv <- cbam_default_intensities()

  ara <- function(tablo) {
    t <- dv[dv$ulke == tablo, ]
    for (n in seq(nchar(cn), 2)) {
      i <- match(substr(cn, 1, n), t$cn_kodu)
      if (!is.na(i)) return(t[i, ])
    }
    # Sorulan kod tablodakinden kisa olabilir (8 hane sorulup 10 haneli
    # TARIC kodu tutuluyorsa).
    uzun <- t[startsWith(t$cn_kodu, cn), ]
    if (nrow(uzun) == 1) return(uzun)
    if (nrow(uzun) > 1) {
      stop(sprintf(paste0(
        "CN %s varsayilan deger tablosunda birden fazla TARIC koduna ayriliyor:\n%s\n",
        "  10 haneli kodu verin (ornek: %s)."),
        cn, paste(sprintf("    %s  %s", uzun$cn_kodu, uzun$aciklama), collapse = "\n"),
        uzun$cn_kodu[1]))
    }
    NULL
  }

  r <- ara(ulke)
  yedek <- FALSE
  if ((is.null(r) || is.na(r$dogrudan)) && ulke != CBAM_DIGER_ULKELER) {
    r <- ara(CBAM_DIGER_ULKELER)
    yedek <- TRUE
  }
  if (is.null(r) || is.na(r$dogrudan)) return(NULL)
  list(
    cn_kodu   = r$cn_kodu,
    eslesme   = if (identical(r$cn_kodu, cn)) "tam" else "onek",
    ulke      = r$ulke,
    mense     = ulke,
    yedek     = yedek,
    sektor    = r$sektor,
    aciklama  = r$aciklama,
    dogrudan  = r$dogrudan,
    dolayli   = r$dolayli,
    toplam    = r$toplam,
    rota      = r$rota,
    kaynak    = cbam_kaynak_metni(r$kaynak_belge, r$kaynak_yeri),
    durum     = trimws(r$durum)
  )
}

#' Varsayilan degerin mark-up orani
#'
#' Kaynak: Rehber No. 3, s.113-114 (Default Values Act, CIR (EU) 2025/2621);
#' ornek: Rehber No. 4, Tablo 2-4 (temel 3,000 -> 3,300 / 3,600 / 3,900).
#'
#' Varsayilan degerler kesin donemde yila gore artirilir:
#'   %10 (2026), %20 (2027), %30 (2028 ve sonrasi); gubrede %1 (2026+).
#' Komisyon'un XLSX dosyasi TEMEL degeri verir; mark-up kullanici tarafindan
#' eklenmelidir. Mark-up yalnizca VARSAYILAN degere uygulanir - tesisin
#' kendi olculmus degerine asla.
#'
#' @param year Yil (2026 ve sonrasi).
#' @param sektor Sektor adi.
#' @return Oran (0,10 = %10).
cbam_default_markup <- function(year, sektor = NULL) {
  gecerli_yil(year)
  if (any(year < 2026)) {
    stop("Varsayilan deger mark-up'i kesin donem icin tanimli (2026 ve sonrasi).")
  }
  if (!is.null(sektor) && tolower(trimws(sektor)) %in% c("fertilisers", "gubre")) {
    return(rep(0.01, length(year)))
  }
  c(0.10, 0.20, 0.30)[pmin(year, 2028) - 2025]
}

#' Varsayilan gomulu emisyon (SEE) - hesapta kullanilacak tek deger
#'
#' Varsayilan yogunlugu hesaba hazir hale getiren TEK yer. Komut satirinin
#' \code{--cn} ve \code{--urun} yollari ikisi de buradan beslenir; iki ayri
#' yolun ayni mal icin farkli sonuc vermesi (v1.0.0'da sinterde oluyordu)
#' boylece imkansiz.
#'
#' Kurallar:
#'   - Dolayli emisyonun kapsamda oldugu mallarda (Komisyon dolayli deger
#'     yayimlamissa) TOPLAM, digerlerinde DOGRUDAN deger kullanilir (D6).
#'   - Yil verilirse mark-up eklenir (bkz. \code{cbam_default_markup()}).
#'
#' @param cn_kodu CN kodu.
#' @param yil Yil; NULL ise mark-up eklenmez (yalnizca temel deger).
#' @param ulke Ulke sayfasi.
#' @return Liste ya da kayit yoksa NULL: \code{temel}, \code{markup},
#'   \code{deger}, \code{dolayli_var}, \code{etiket}, \code{rota}, \code{dv}.
cbam_default_see <- function(cn_kodu, yil = NULL, ulke = "Turkiye") {
  dv <- cbam_default_intensity(cn_kodu, ulke)
  if (is.null(dv)) return(NULL)
  dolayli_var <- !is.na(dv$dolayli)
  temel <- if (dolayli_var) dv$toplam else dv$dogrudan
  mu <- if (is.null(yil)) 0 else cbam_default_markup(yil, dv$sektor)
  list(
    temel       = temel,
    markup      = mu,
    deger       = temel * (1 + mu),
    dolayli_var = dolayli_var,
    etiket      = paste0(if (dolayli_var) "dogrudan + dolayli" else "dogrudan",
                         if (mu > 0) sprintf(", varsayilan + %%%s mark-up",
                                             fmt_num(100 * mu, 0)) else ""),
    rota        = dv$rota,
    dv          = dv
  )
}

#' Sektorun fonksiyonel birimi
#'
#' Cimento ve gubrede operatorun emisyonu IZLEYIP RAPORLADIGI birim ton urun
#' degildir: cimentoda ton klinker, gubrede kg azot (Rehber No. 3, s.20).
#'
#' ANCAK yukumluluk hesabi ton urun uzerinden yapilir. Rehber No. 1, s.15:
#'   "SEE values must be expressed per tonne ... while the value per
#'    functional unit (where different from tonnes of good) is to be
#'    transformed in value per tonne of good applying the formulas for
#'    specific compositions in Annex III of the Methodology Act."
#'
#' Nitekim hem benchmark tablosu hem varsayilan deger tablosu ton basina
#' degerler tasir. Dolayisiyla bu araca miktar TON URUN olarak girilir;
#' fonksiyonel birim, kendi emisyon verisi fonksiyonel birim cinsinden olan
#' kullaniciyi donusturme yukumlulugu konusunda uyarmak icin tutulur.
#'
#' @param sektor Benchmark tablosundaki sektor adi.
#' @return Liste: \code{birim} (izleme birimi) ve \code{standart} (mantiksal;
#'   izleme birimi ton urun ise TRUE).
cbam_fonksiyonel_birim <- function(sektor) {
  s <- tolower(trimws(as.character(sektor)))
  if (identical(s, "cement")) {
    return(list(birim = "ton klinker", standart = FALSE))
  }
  if (identical(s, "fertilisers")) {
    return(list(birim = "kg azot", standart = FALSE))
  }
  list(birim = "ton urun", standart = TRUE)
}

#' Tek bir urunun tum referans bilgisi
#'
#' Urun katalogunu ve benchmark tablosunu birlestirir.
#'
#' @param urun_kodu Urun kodu (ornek: "alu-ham").
#' @param sutun Benchmark sutunu: \code{"B"} tum uretim zinciri (varsayilan),
#'   \code{"A"} tek uretim sureci.
#' @param yil Yil; varsayilan degerin mark-up'i ve yila bagli benchmark
#'   buna gore secilir. NULL ise mark-up eklenmez.
#' @return Tek satirlik liste: yogunluk, benchmark, kapsam ve kaynaklar.
cbam_product <- function(urun_kodu, sutun = "B", yil = NULL) {
  urunler <- cbam_products()
  i <- match(urun_kodu, urunler$urun_kodu)
  if (is.na(i)) {
    stop(sprintf("Bilinmeyen urun kodu '%s'. Mevcut kodlar: %s",
                 urun_kodu, paste(urunler$urun_kodu, collapse = ", ")))
  }
  u <- urunler[i, ]

  # Yogunluk artik urun tablosunda tutulmuyor; mevzuatin varsayilan deger
  # tablosundan gelir. Kendi tahminimizi tasimak, resmi bir deger varken
  # savunulamazdi.
  see <- cbam_default_see(u$cn_kodu, yil)
  b <- cbam_benchmark_by_cn(u$cn_kodu, sutun, yil = yil,
                            rota = if (is.null(see)) NULL else see$rota)
  if (is.null(see)) {
    stop(sprintf(paste0(
      "'%s' (CN %s) icin varsayilan yogunluk tablosunda kayit yok.\n",
      "  Benchmark resmi tablodan geliyor (%s), ama yogunluk yok.\n",
      "  --yogunluk ile kendi tesis verinizi verin."),
      urun_kodu, u$cn_kodu, fmt_num(b$benchmark, 3)))
  }
  dv <- see$dv

  list(
    urun_kodu           = u$urun_kodu,
    urun_adi            = u$urun_adi,
    sektor              = u$sektor,
    cn_kodu             = b$cn_kodu,
    cn_aciklama         = b$aciklama,
    benchmark_sutun     = b$sutun,
    dolayli_kapsamda    = tolower(trimws(u$dolayli_kapsamda)) %in%
                            c("evet", "yes", "true"),
    varsayilan_yogunluk = see$deger,
    varsayilan_temel    = see$temel,
    varsayilan_markup   = see$markup,
    yogunluk_etiketi    = see$etiket,
    varsayilan_sacilim  = u$varsayilan_sacilim,
    benchmark           = b$benchmark,
    yogunluk_kaynak     = sprintf("%s, CN %s%s", dv$kaynak, dv$cn_kodu,
                                  if (see$markup > 0) sprintf(
                                    " | temel %s + %%%s mark-up (Rehber No. 3 s.113)",
                                    fmt_num(see$temel, 3),
                                    fmt_num(100 * see$markup, 0)) else ""),
    benchmark_kaynak    = sprintf("%s, CN %s, Column %s%s",
                                  b$kaynak, b$cn_kodu, b$sutun,
                                  if (nzchar(b$rota)) paste0(" ", b$rota) else ""),
    benchmark_gecerlilik = "",
    benchmark_not       = b$not,
    # Benchmark artik resmi ve dogrulanmis; yogunluk hala sektor tahmini.
    # Bu yuzden satir bazinda degil, alan bazinda durum tutuluyor.
    benchmark_dogrulandi = identical(b$durum, "dogrulandi"),
    yogunluk_dogrulandi  = identical(dv$durum, "dogrulandi"),
    dogrulandi          = identical(dv$durum, "dogrulandi") &&
                            identical(b$durum, "dogrulandi"),
    urun_durum          = trimws(u$durum),
    benchmark_durum     = b$durum,
    not                 = u$not,
    veri_surumu         = cbam_data_version()
  )
}

#' Kaynak referansini tek satirlik metne cevir
#'
#' @param belge Kaynak belge kimligi.
#' @param yer Belge icindeki yer (madde, ek, satir).
#' @return Okunabilir kaynak metni; kaynak yoksa acik uyari.
cbam_kaynak_metni <- function(belge, yer) {
  belge <- trimws(as.character(belge))
  yer   <- trimws(as.character(yer))
  if (is.na(belge) || belge == "") {
    return("KAYNAK GIRILMEDI")
  }
  if (is.na(yer) || yer == "") {
    return(belge)
  }
  paste0(belge, ", ", yer)
}

#' Gecerlilik araligini metne cevir
#'
#' @param baslangic Baslangic tarihi.
#' @param bitis Bitis tarihi.
#' @return Okunabilir aralik metni ya da bos karakter.
cbam_gecerlilik_metni <- function(baslangic, bitis) {
  baslangic <- trimws(as.character(baslangic))
  bitis     <- trimws(as.character(bitis))
  if (is.na(baslangic) || baslangic == "") return("")
  if (is.na(bitis) || bitis == "") return(baslangic)
  paste(baslangic, "-", bitis)
}

#' Dogrulanmamis veri uyarisi
#'
#' Yer tutucu degerlerin resmi deger sanilmasini onler.
#'
#' @param p \code{cbam_product()} ciktisi.
#' @return Yazdirilacak uyari satirlari; veri dogrulanmissa NULL.
cbam_dogrulama_uyarisi <- function(p) {
  if (isTRUE(p$dogrulandi)) return(NULL)
  satir <- "!! DIKKAT: Bu hesapta DOGRULANMAMIS deger kullanildi."
  if (isTRUE(p$benchmark_dogrulandi) && !isTRUE(p$yogunluk_dogrulandi)) {
    # En sik durum: benchmark resmi, yogunluk hala sektor tahmini.
    return(c(
      satir,
      "   Benchmark  : resmi AB tablosundan, DOGRULANDI.",
      "   Yogunluk   : sektor tahmini, DOGRULANMADI.",
      "   Kendi tesis verinizi --yogunluk ile verin; sonuc o zaman",
      "   tamamen resmi kaynaklara dayanir."
    ))
  }
  c(
    satir,
    sprintf("   Urun kaydi     : %s", p$urun_durum),
    sprintf("   Benchmark kaydi: %s", p$benchmark_durum),
    "   Degerler sektor tahminidir, resmi AB degeri DEGILDIR.",
    "   Resmi degerler icin bkz. data-raw/mevzuat/KAYNAKLAR.md",
    "   Bu ciktiyi beyan veya yatirim karari icin kullanmayin."
  )
}
