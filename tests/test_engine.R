#  stochastic-cbam-engine — Copyright (C) 2026 Selahattin İlhan
#  SPDX-License-Identifier: AGPL-3.0-or-later
#
#  Bu dosya GNU Affero General Public License v3 (ya da sonraki bir surum)
#  kosullariyla dagitilir; HICBIR GARANTI VERILMEZ. Ayrintilar: LICENSE
#  EK SART (AGPL 7(b)): yazar atiflari ve telif bildirimleri korunmalidir.
#  Bkz. NOTICE ve LICENSE-ADDITIONAL-TERMS.md

#  Motor Testleri (base R - harici test paketi gerektirmez)
#
#  Calistirma:  Rscript tests/test_engine.R   (proje kokunden)

if (!file.exists("load_all.R")) {
  stop("Testler proje kokunden calistirilmali: Rscript tests/test_engine.R")
}
source("load_all.R")

passed <- 0L
failed <- 0L

expect <- function(label, condition) {
  ok <- isTRUE(tryCatch(condition, error = function(e) FALSE))
  if (ok) {
    passed <<- passed + 1L
    cat(sprintf("  [GECTI] %s\n", label))
  } else {
    failed <<- failed + 1L
    cat(sprintf("  [KALDI] %s\n", label))
  }
}

expect_error <- function(label, expr) {
  threw <- inherits(try(force(expr), silent = TRUE), "try-error")
  expect(label, threw)
}

cat("\n== emissions.R ==\n")
expect("theta = 1 sektor ortalamasini korur",
       firm_emission_intensity(2.0, 1.0) == 2.0)
expect("theta olceklemesi dogrusal",
       firm_emission_intensity(2.0, 1.5) == 3.0)
expect_error("negatif ei_sector reddedilir",
             firm_emission_intensity(-1, 1))
expect_error("sifir theta reddedilir",
             firm_emission_intensity(1, 0))
expect("gomulu emisyon = miktar * yogunluk",
       embedded_emissions(1000, 1.9) == 1900)
expect("dolayli emisyon varsayilan olarak haric",
       embedded_emissions(1000, 1.9, ei_indirect = 0.5) == 1900)
expect("dolayli emisyon istege bagli dahil",
       embedded_emissions(1000, 1.9, 0.5, include_indirect = TRUE) == 2400)
expect("sample_theta pozitif ve dogru uzunlukta",
       { s <- sample_theta(500); length(s) == 500 && all(s > 0) })

cat("\n== cbam.R ==\n")
expect("2025 oncesi mali yukumluluk yok",
       cbam_phase_in_factor(2025) == 0)
expect("2026 faktoru %2,5",
       abs(cbam_phase_in_factor(2026) - 0.025) < 1e-12)
expect("2030 faktoru %48,5",
       cbam_phase_in_factor(2030) == 0.485)
expect("2034 ve sonrasi tam yukumluluk",
       cbam_phase_in_factor(2034) == 1 && cbam_phase_in_factor(2040) == 1)

# --- D1: resmi CBAM faktoru tablosu -----------------------------------------
# Kaynak: Free Allocation Adjustment Act (CIR (EU) 2025/2620),
#         Guidance No. 4 Tablo 2-1.
# Mevzuatin "CBAM factor" dedigi deger UCRETSIZ TAHSISAT payidir; bizim
# yukumluluk payimiz onun tumleyenidir. 2031-2033 degerleri onceden yanlisti.
expect("resmi CBAM faktoru tablosu mevzuatla ayni",
       all(abs(cbam_factor_official(2026:2034) -
                 c(0.975, 0.950, 0.900, 0.775, 0.515,
                   0.390, 0.265, 0.140, 0.000)) < 1e-12))
expect("yukumluluk payi resmi faktorun tumleyeni",
       all(abs(cbam_phase_in_factor(2026:2034) +
                 cbam_factor_official(2026:2034) - 1) < 1e-12))
expect("2031-2033 duzeltilmis degerler",
       all(abs(cbam_phase_in_factor(2031:2033) -
                 c(0.610, 0.735, 0.860)) < 1e-12))
expect("2026 oncesi tahsisat tam, yukumluluk sifir",
       cbam_factor_official(2025) == 1 && cbam_phase_in_factor(2025) == 0)
expect_error("resmi faktor gecersiz yili reddeder",
             cbam_factor_official(2030.5))

# --- CSCF ---
expect("cscf su an tum yillarda 1",
       all(cbam_cscf(2026:2034) == 1))
expect("cscf ucretsiz tahsisati olcekler",
       { tam <- certificates_due(1900, 1000, 1.288, 0.025, cscf = 1)
         yari <- certificates_due(1900, 1000, 1.288, 0.025, cscf = 0.5)
         yari > tam })
expect_error("negatif cscf reddedilir",
             certificates_due(1900, 1000, 1.288, 0.5, cscf = -1))
expect("faktor vektorlestirilmis",
       length(cbam_phase_in_factor(c(2026, 2030, 2034))) == 3)
expect("vektor sonuclari tek tek cagriyla ayni",
       all(abs(cbam_phase_in_factor(c(2025, 2028, 2031, 2040)) -
                 c(0, 0.100, 0.610, 1)) < 1e-12))
# K3: gecersiz yil sessizce NA uretiyordu; hata tum hesaba yayiliyordu.
expect_error("tam sayi olmayan yil reddedilir", cbam_phase_in_factor(2026.5))
expect_error("NA yil reddedilir", cbam_phase_in_factor(NA_real_))
expect_error("metin yil reddedilir", cbam_phase_in_factor("2030"))
expect_error("bos yil reddedilir", cbam_phase_in_factor(numeric(0)))

expect("tam faktorde ucretsiz tahsisat kalmaz",
       certificates_due(1900, 1000, 1.288, 1.0) == 1900)
expect("dusuk faktorde muafiyet buyuk",
       certificates_due(1900, 1000, 1.288, 0.025) < 700)
expect("sertifika negatif olamaz",
       certificates_due(100, 1000, 1.288, 0.025) == 0)
expect_error("gecersiz cbam_factor reddedilir",
             certificates_due(1900, 1000, 1.288, 1.5))

# --- D3: mensede odenen karbon bir FIYATTIR, miktar degil -----------------
# Kaynak: Rehber No. 1 s.14, Denklem; CBAM Tuzugu Md. 9.
#   CBAM Obligation = max[0 ; SEE - SEFA - SECPP/RP_CBAM] * M
# Onceki surumde parametre dogrudan tCO2e olarak dusuluyordu - birim yanlisti.
expect("odenen karbon referans fiyatina bolunerek dusulur",
       { # 1000 ton, 32 EUR/ton odenmis, sertifika referansi 80 EUR/tCO2e
         # -> dusum = 1000 * 32 / 80 = 400 tCO2e
         certificates_due(1900, 1000, 1.288, 1.0,
                          carbon_price_paid = 32,
                          cbam_reference_price = 80) == 1500 })
expect("yuksek referans fiyati dusumu kucultur",
       { az <- certificates_due(1900, 1000, 1.288, 1.0,
                                carbon_price_paid = 32,
                                cbam_reference_price = 160)
         cok <- certificates_due(1900, 1000, 1.288, 1.0,
                                 carbon_price_paid = 32,
                                 cbam_reference_price = 80)
         az > cok })
expect("odenen karbon sifirsa referans fiyati gerekmez",
       certificates_due(1900, 1000, 1.288, 1.0) == 1900)
expect_error("referans fiyati olmadan odenen karbon reddedilir",
             certificates_due(1900, 1000, 1.288, 1.0, carbon_price_paid = 32))
expect_error("negatif odenen karbon reddedilir",
             certificates_due(1900, 1000, 1.288, 1.0, carbon_price_paid = -1,
                              cbam_reference_price = 80))
expect("odenen karbon yukumlulugu sifirin altina indiremez",
       certificates_due(1900, 1000, 1.288, 1.0,
                        carbon_price_paid = 500,
                        cbam_reference_price = 80) == 0)

expect("maliyet = sertifika * fiyat",
       cbam_cost(100, 80)$cost_eur == 8000)
expect("kur cevrimi uygulanir",
       cbam_cost(100, 80, fx_rate = 40)$cost_local == 320000)
# --- D4: de minimis esigi 50 ton NET KUTLE, emisyon degil -----------------
# Kaynak: CBAM Tuzugu Md. 2a ve Ek VII nokta 1; Rehber No. 1 s.23.
# Onceki surumde 50 tCO2e emisyon olarak uygulaniyordu - birim yanlisti.
expect("de minimis esigi 50 ton kutle",
       is_de_minimis(49) && !is_de_minimis(51))
expect("esik kutleye bakar, emisyona degil",
       { # 40 ton mal, cok yuksek yogunlukla bile muaf: kutle esigin altinda
         is_de_minimis(40) })
expect("buyuk kutle dusuk emisyonla bile muaf degil",
       !is_de_minimis(1000))
expect("hidrojen de minimis muafiyeti disinda",
       !is_de_minimis(10, sektor = "Hydrogen"))
expect("elektrik de minimis muafiyeti disinda",
       !is_de_minimis(10, sektor = "electricity"))
expect("demir-celik muafiyet kapsaminda",
       is_de_minimis(10, sektor = "Iron & Steel"))

cat("\n== stochastic.R ==\n")
set.seed(42)
expect("GBM pozitif degerler uretir",
       all(simulate_gbm(1000, 75, 0.05, 0.35) > 0))
expect("sifir volatilitede GBM deterministik",
       { v <- simulate_gbm(10, 100, 0.0, 0.0); all(abs(v - 100) < 1e-9) })
expect("korelasyon hedefe yakin",
       { z <- correlated_shocks(200000, 0.6); abs(cor(z[, 1], z[, 2]) - 0.6) < 0.02 })
expect_error("gecersiz rho reddedilir",
             correlated_shocks(100, 1.0))
expect("simulate_market dogru boyutta",
       { m <- simulate_market(1000, 75, fx_0 = 40)
         nrow(m) == 1000 && all(m$carbon_price > 0) && all(m$fx_rate > 0) })
expect("sifir ufukta belirsizlik yok",
       { m <- simulate_market(500, 80, fx_0 = 48, horizon = 0)
         all(abs(m$carbon_price - 80) < 1e-9) && all(abs(m$fx_rate - 48) < 1e-9) })
# --- K6: reel / nominal ayrimi ---------------------------------------------
# Onceki hali sabit fx_mu = 0.20 idi ve kaynaksizdi; sekiz yil bileşiklenince
# 2034 icin ~238 TRY/EUR ima ediyordu. Simdi enflasyon farkindan turetiliyor.
expect("kur suruklemesi enflasyon farkindan turetilir",
       { m <- simulate_market(200000, 80, fx_0 = 48, fx_sigma = 0,
                              inflation_tr = 0.25, inflation_eu = 0.02,
                              horizon = 1)
         beklenen <- 48 * (1.25 / 1.02)
         abs(median(m$fx_rate) - beklenen) / beklenen < 0.01 })
expect("enflasyon esitse kur sabit kalir",
       { m <- simulate_market(1000, 80, fx_0 = 48, fx_sigma = 0,
                              inflation_tr = 0.10, inflation_eu = 0.10,
                              horizon = 5)
         all(abs(m$fx_rate - 48) < 1e-6) })
expect("fx_mu elle verilirse enflasyonun onune gecer",
       { m <- simulate_market(1000, 80, fx_0 = 48, fx_mu = 0, fx_sigma = 0,
                              inflation_tr = 0.25, horizon = 3)
         all(abs(m$fx_rate - 48) < 1e-6) })
expect("deflator enflasyon ve ufuktan hesaplanir",
       { m <- simulate_market(10, 80, inflation_tr = 0.25, horizon = 4)
         abs(m$deflator_tr[1] - 1.25^4) < 1e-9 })

expect("ufuk buyudukce dagilim genisler",
       { set.seed(4)
         s1 <- sd(simulate_market(50000, 80, horizon = 1)$carbon_price)
         s8 <- sd(simulate_market(50000, 80, horizon = 8)$carbon_price)
         s8 > s1 })

cat("\n== mrio.R ==\n")
Z <- matrix(c(20, 30, 10, 40), nrow = 2)
x <- c(100, 200)
A <- technical_coefficients(Z, x)
expect("A = Z / cikti (sutun bazinda)",
       abs(A[1, 1] - 0.20) < 1e-12 && abs(A[1, 2] - 0.05) < 1e-12)
expect("sifir ciktili sektor sifir sutun verir",
       { A0 <- technical_coefficients(Z, c(100, 0)); all(A0[, 2] == 0) })
L <- leontief_inverse(A)
expect("L = (I - A)^-1 dogrulanir",
       max(abs((diag(2) - A) %*% L - diag(2))) < 1e-10)
expect("L kosegen elemanlari >= 1",
       all(diag(L) >= 1))
expect_error("tekil matris hata verir",
             leontief_inverse(matrix(c(1, 0, 0, 1), nrow = 2)))
expect("toplam yogunluk dogrudandan buyuk",
       { f <- c(0.5, 0.3); tot <- total_emission_intensity(f, L)
         all(tot >= f) })
expect("kapsam orani 0-1 arasinda",
       { g <- scope_gap(1900, 2500)
         abs(g$gap - 600) < 1e-9 && g$coverage_ratio > 0 && g$coverage_ratio < 1 })

cat("\n== monte_carlo.R ==\n")
sim <- run_cbam_mc(n_sims = 5000, quantity = 50000, ei_sector = 1.9,
                   benchmark = 1.288, year = 2030, carbon_price_0 = 75,
                   fx_0 = 40, seed = 123)
expect("cikti cbam_mc sinifinda", inherits(sim, "cbam_mc"))
expect("draws dogru satir sayisinda", nrow(sim$draws) == 5000)
expect("tum maliyetler negatif degil", all(sim$draws$cost_eur >= 0))
expect("yerel maliyet = EUR * kur",
       max(abs(sim$draws$cost_local -
               sim$draws$cost_eur * sim$draws$fx_rate)) < 1e-6)
expect("bugunku kur sutunu varsayim icermez",
       max(abs(sim$draws$cost_local_today -
               sim$draws$cost_eur * sim$inputs$fx_0)) < 1e-6)
expect("reel tutar nominalden kucuk (pozitif enflasyonda)",
       { s <- run_cbam_mc(2000, 50000, 1.9, benchmark = 1.288, year = 2034,
                          base_year = 2026, fx_0 = 48, seed = 9)
         median(s$draws$cost_local_real) < median(s$draws$cost_local) })
expect("risk_summary ucunu de raporlar",
       { rs <- risk_summary(sim)
         all(c("cost_local_today", "cost_local_real", "cost_local")
             %in% rownames(rs)) })
expect("ayni tohum ayni sonucu verir",
       { s2 <- run_cbam_mc(n_sims = 5000, quantity = 50000, ei_sector = 1.9,
                           benchmark = 1.288, year = 2030,
                           carbon_price_0 = 75, fx_0 = 40, seed = 123)
         identical(sim$draws$cost_eur, s2$draws$cost_eur) })
expect("sifir heterojenlikte theta sabit",
       { s3 <- run_cbam_mc(n_sims = 100, quantity = 1000, ei_sector = 1.9,
                           theta_sdlog = 0, benchmark = 1.288, seed = 1)
         length(unique(s3$draws$theta)) == 1 })
expect("2034 maliyeti 2026'dan yuksek",
       { a <- run_cbam_mc(2000, 50000, 1.9, benchmark = 1.288,
                          year = 2026, seed = 7)
         b <- run_cbam_mc(2000, 50000, 1.9, benchmark = 1.288,
                          year = 2034, seed = 7)
         median(b$draws$cost_eur) > median(a$draws$cost_eur) })
expect("risk_summary tum metrikleri dondurur",
       { rs <- risk_summary(sim); nrow(rs) == 6 && "5%" %in% colnames(rs) })
expect("VaR medyandan buyuk",
       cbam_var(sim, 0.95) > median(sim$draws$cost_eur))
expect_error("risk_summary yanlis girdiyi reddeder",
             risk_summary(data.frame(a = 1)))

# --- K1: horizon, yukumluluk yilindan turetilmeli --------------------------
# Onceki davranis: year = 2034 verildiginde bile horizon = 1 kaliyordu ve
# dokuz yillik belirsizlik tek yil gibi modellenerek risk eksik gosteriliyordu.
expect("horizon year - base_year olarak turetilir",
       { s <- run_cbam_mc(500, 50000, 1.9, benchmark = 1.288,
                          year = 2034, base_year = 2026, seed = 11)
         s$inputs$horizon == 8 })
expect("uzak yil daha genis fiyat dagilimi uretir",
       { near <- run_cbam_mc(20000, 50000, 1.9, benchmark = 1.288,
                             year = 2027, base_year = 2026,
                             carbon_price_0 = 80, seed = 11)
         far <- run_cbam_mc(20000, 50000, 1.9, benchmark = 1.288,
                            year = 2034, base_year = 2026,
                            carbon_price_0 = 80, seed = 11)
         sd(far$draws$carbon_price) > 3 * sd(near$draws$carbon_price) })
expect("year = base_year -> ufuk sifir, fiyat sabit",
       { s <- run_cbam_mc(500, 50000, 1.9, benchmark = 1.288,
                          year = 2026, base_year = 2026,
                          carbon_price_0 = 80, fx_0 = 48, seed = 3)
         s$inputs$horizon == 0 &&
           all(abs(s$draws$carbon_price - 80) < 1e-9) &&
           all(abs(s$draws$fx_rate - 48) < 1e-9) })
expect("horizon elle gecersiz kilinabilir",
       { s <- run_cbam_mc(500, 50000, 1.9, benchmark = 1.288,
                          year = 2034, horizon = 2, seed = 11)
         s$inputs$horizon == 2 })
expect_error("birden fazla yil reddedilir",
             run_cbam_mc(100, 1000, 1.9, benchmark = 1.288, year = c(2026, 2030)))

# --- K2: seed cagiranin RNG durumunu kirletmemeli --------------------------
expect("seed global RNG durumunu kirletmez",
       { set.seed(999)
         before <- runif(1)
         set.seed(999)
         invisible(run_cbam_mc(100, 1000, 1.9, benchmark = 1.288, seed = 5))
         identical(before, runif(1)) })
expect("provenans alanlari inputs icinde kayitli",
       { s <- run_cbam_mc(100, 1000, 1.9, benchmark = 1.288, seed = 5)
         all(c("seed", "horizon", "base_year", "theta_sdlog") %in%
               names(s$inputs)) })

cat("\n== bagimlilik disiplini ==\n")
# "Sifir bagimlilik" bir iddia degil, korunmasi gereken bir kural olmali.
# Motor ve sunum katmani yalnizca R'in temel paketlerini kullanabilir.
kaynak_dosyalar <- c(list.files("R", pattern = "\\.R$", full.names = TRUE),
                     "hesapla.R", "load_all.R")
kaynak_metin <- unlist(lapply(kaynak_dosyalar, readLines, warn = FALSE))
kod_satirlari <- kaynak_metin[!grepl("^\\s*#", kaynak_metin)]

expect("motor library()/require() cagirmiyor",
       !any(grepl("\\b(library|require|requireNamespace)\\s*\\(", kod_satirlari)))
expect("yalnizca temel paket ad alanlari kullaniliyor",
       { ns <- regmatches(kod_satirlari,
                          gregexpr("[A-Za-z][A-Za-z0-9.]*(?=::)", kod_satirlari,
                                   perl = TRUE))
         ns <- unique(unlist(ns))
         length(ns) == 0 || all(ns %in% c("stats", "utils", "graphics",
                                          "grDevices", "methods", "base",
                                          "tools"))
       })
expect("motor katmani ag erisimi yapmiyor",
       !any(grepl("url\\(|download\\.file|curl|httr|readLines\\s*\\(\\s*\"http",
                  kod_satirlari)))

cat("\n== reference.R (Katman 0 veri butunlugu) ==\n")
urunler <- cbam_products()
benchmarks <- cbam_benchmarks()

expect("urun katalogu bos degil", nrow(urunler) > 0)
expect("veri surumu tanimli", nchar(cbam_data_version()) > 0)
expect("urun kodlari benzersiz",
       !any(duplicated(urunler$urun_kodu)))
# Bir CN kodunun rota/yil gostergesine gore birden fazla satiri olabilir;
# benzersiz olmasi gereken (CN, gosterge) ciftidir.
expect("CN + gosterge ciftleri benzersiz",
       !any(duplicated(paste(benchmarks$cn_kodu, benchmarks$rota_b))))
expect("benchmark tablosu 570 CN kodunu tasiyor",
       length(unique(benchmarks$cn_kodu)) == 570)
expect("resmi tablonun tum deger satirlari tasiniyor (1804)",
       nrow(benchmarks) == 1804)
# Urun 10 haneli TARIC koduyla tanimli olabilir (gri klinker); benchmark
# 8 hanede tutulur.
expect("her urunun CN kodu benchmark tablosunda var",
       all(substr(urunler$cn_kodu, 1, 8) %in% benchmarks$cn_kodu))
expect("benchmark tablosu resmi buyuklukte (500+ CN kodu)",
       nrow(benchmarks) > 500)
expect("benchmark tablosunun tamami dogrulandi",
       all(trimws(benchmarks$durum) == "dogrulandi"))
expect("her benchmark satirinin kaynagi var",
       all(nzchar(trimws(benchmarks$kaynak_belge))))
expect("girilmis yogunluk degerleri pozitif",
       { v <- urunler$varsayilan_yogunluk
         all(v[!is.na(v)] > 0) })
expect("benchmark degerleri negatif degil",
       { all(benchmarks$bm_column_a[!is.na(benchmarks$bm_column_a)] >= 0) &&
           all(benchmarks$bm_column_b[!is.na(benchmarks$bm_column_b)] >= 0) })
# Column B tum uretim zinciri, Column A tek surec: B >= A olmali.
expect("Column B her zaman Column A'dan kucuk degil",
       { a <- benchmarks$bm_column_a
         b <- benchmarks$bm_column_b
         ok <- !is.na(a) & !is.na(b)
         all(b[ok] >= a[ok] - 1e-9) })
expect("girilmis sacilim degerleri makul araliktan",
       { v <- urunler$varsayilan_sacilim
         all(v[!is.na(v)] >= 0 & v[!is.na(v)] < 2) })
expect("benchmark tablosu tum CBAM sektorlerini kapsiyor",
       all(c("Cement", "Fertilisers", "Iron & Steel", "Aluminium", "Hydrogen")
           %in% unique(benchmarks$sektor)))

# --- D7/D8: CN kodu ile benchmark cozumleme -------------------------------
expect("CN kodu ile benchmark bulunur",
       { b <- cbam_benchmark_by_cn("72081000")
         abs(b$benchmark - 1.370) < 1e-9 && b$sutun == "B" })
expect("Column A tek uretim sureci degerini verir",
       { b <- cbam_benchmark_by_cn("72081000", "A")
         abs(b$benchmark - 0.044) < 1e-9 })
expect("birincil aluminyum resmi degeri 1,423",
       abs(cbam_benchmark_by_cn("76011090")$benchmark - 1.423) < 1e-9)
expect("hidrojen resmi degeri 5,089",
       abs(cbam_benchmark_by_cn("28041000")$benchmark - 5.089) < 1e-9)
expect("CN kodundaki bosluk ve nokta temizlenir",
       { abs(cbam_benchmark_by_cn(" 7208 10 00 ")$benchmark - 1.370) < 1e-9 })
expect("benchmark kaynagi ciktida tasinir",
       nzchar(cbam_benchmark_by_cn("72081000")$kaynak))
expect_error("kapsam disi CN kodu net hata verir",
             cbam_benchmark_by_cn("99999999"))
expect_error("bos CN kodu reddedilir", cbam_benchmark_by_cn(""))
expect_error("gecersiz sutun reddedilir",
             cbam_benchmark_by_cn("72081000", "C"))

# --- Varsayilan emisyon yogunluklari (Default Values Act) -----------------
dv_tablo <- cbam_default_intensities()
expect("varsayilan deger tablosu yuklendi", nrow(dv_tablo) > 200)
expect("tablonun tamami dogrulandi",
       all(trimws(dv_tablo$durum) == "dogrulandi"))
expect("her satirin kaynagi var",
       all(nzchar(trimws(dv_tablo$kaynak_belge))))
# Resmi tabloda tek sifir deger var: Mali, hidrojen (0,000) - Komisyon boyle
# yayimlamis, degistirilmez.
expect("girilmis degerler negatif degil",
       { v <- dv_tablo$dogrudan
         all(v[!is.na(v)] >= 0) })
expect("uyari uretmeden yukleniyor",
       { u <- withCallingHandlers(
           { cbam_default_intensities(); TRUE },
           warning = function(w) stop("uyari uretti"))
         isTRUE(u) })

# Turkiye, CN 7208: resmi varsayilan 2,428 (dogrudan).
# Bizim onceki tahminimiz 1,95 idi - yanlisti.
expect("CN 7208 icin resmi Turkiye varsayilani 2,428",
       { d <- cbam_default_intensity("7208")
         abs(d$dogrudan - 2.428) < 1e-9 })
expect("8 haneli kod 4 haneli kayitla onek eslesir",
       { d <- cbam_default_intensity("72081000")
         d$cn_kodu == "7208" && d$eslesme == "onek" })
expect("celikte dolayli deger yok (D6 ile tutarli)",
       is.na(cbam_default_intensity("7208")$dolayli))

# D6, varsayilan deger tablosunda da gorunur: Komisyon dolayli emisyonun
# sayilmadigi bir mal icin dolayli varsayilan yayimlamaz. Bu, dolayli
# kapsamini ayri bir listeden degil verinin kendisinden okumayi mumkun kilar.
expect("gubrede dolayli deger var (kapsamda)",
       { d <- cbam_default_intensity("28141000")
         !is.na(d$dolayli) && d$dolayli > 0 })
expect("gubrede toplam = dogrudan + dolayli",
       { d <- cbam_default_intensity("28141000")
         abs(d$toplam - (d$dogrudan + d$dolayli)) < 1e-9 })
expect("gubre satirlarinin cogunda dolayli var, celikte neredeyse hicbirinde",
       { dv <- cbam_default_intensities()
         g <- dv[dv$sektor == "Fertilisers", ]
         s <- dv[dv$sektor == "Iron and steel", ]
         mean(!is.na(g$dolayli)) > 0.8 && mean(!is.na(s$dolayli)) < 0.05 })
expect("varsayilan deger benchmark'tan buyuk (aksi halde yukumluluk cikmaz)",
       { d <- cbam_default_intensity("7208")
         b <- cbam_benchmark_by_cn("72081000")
         d$dogrudan > b$benchmark })
expect("kaynak metni ciktida tasiniyor",
       nzchar(cbam_default_intensity("7208")$kaynak))
expect("bilinmeyen CN icin NULL doner",
       is.null(cbam_default_intensity("99999999")))
expect("bos CN icin NULL doner", is.null(cbam_default_intensity("")))

# --- Fonksiyonel birim: sessizce yanlis sonucu onleyen kontrol ------------
# Rehber No. 3 s.20: cimentoda ton klinker, gubrede kg azot.
expect("celikte birim ton urun",
       isTRUE(cbam_benchmark_by_cn("72081000")$birim$standart))
expect("cimentoda birim ton klinker",
       { b <- cbam_benchmark_by_cn("25231000")$birim
         !b$standart && b$birim == "ton klinker" })
expect("aluminyumda birim ton urun",
       isTRUE(cbam_benchmark_by_cn("76011090")$birim$standart))
expect("gubre sektorunde birim kg azot",
       { g <- benchmarks$cn_kodu[benchmarks$sektor == "Fertilisers"][1]
         b <- cbam_benchmark_by_cn(g)$birim
         !b$standart && b$birim == "kg azot" })
expect("standart disi birim hesapta uyari uretir",
       { e <- cbam_estimate(100000, 0.9, 0.666, year = 2030,
                            uncertainty = FALSE,
                            functional_unit = cbam_fonksiyonel_birim("Cement"))
         cikti <- capture.output(print(e))
         any(grepl("BIRIM NOTU", cikti, fixed = TRUE)) })
expect("standart birimde uyari cikmaz",
       { e <- cbam_estimate(250000, 1.95, 1.37, year = 2030,
                            uncertainty = FALSE)
         cikti <- capture.output(print(e))
         !any(grepl("BIRIM NOTU", cikti, fixed = TRUE)) })
expect("durum degerleri gecerli",
       all(trimws(c(urunler$durum, benchmarks$durum)) %in%
             c("dogrulandi", "dogrulanmadi", "kismen")))

# Kritik kural: bir satir "dogrulandi" diyorsa kaynagini gostermek ZORUNDA.
# Bu test olmadan biri kaynaksiz bir degeri resmi gibi isaretleyebilir.
expect("dogrulanmis urun satirlarinin kaynagi var",
       { d <- urunler[urunler$durum == "dogrulandi", ]
         nrow(d) == 0 || all(nzchar(trimws(d$kaynak_belge))) })
expect("dogrulanmis benchmark satirlarinin kaynagi var",
       { d <- benchmarks[benchmarks$durum == "dogrulandi", ]
         nrow(d) == 0 || all(nzchar(trimws(d$kaynak_belge))) })

expect("degeri girilmis urunler icin cbam_product calisir",
       { hazir <- urunler$urun_kodu[!is.na(urunler$varsayilan_yogunluk)]
         length(hazir) > 0 &&
           all(vapply(hazir, function(k) {
             p <- cbam_product(k)
             is.numeric(p$benchmark) && p$benchmark > 0 &&
               is.numeric(p$varsayilan_yogunluk) &&
               isTRUE(p$benchmark_dogrulandi)
           }, logical(1))) })
expect("urun benchmark'i CN kodu uzerinden resmi tablodan gelir",
       { p <- cbam_product("celik-hrc")
         b <- cbam_benchmark_by_cn(p$cn_kodu)
         abs(p$benchmark - b$benchmark) < 1e-12 })
expect("sutun secimi urun cozumlemesine de gecer",
       { pa <- cbam_product("celik-hrc", "A")
         pb <- cbam_product("celik-hrc", "B")
         pb$benchmark > pa$benchmark })
# Iskelet satirlar sessizce NA ile hesaba girmemeli.
expect("degeri girilmemis urun net hata verir",
       { bos <- urunler$urun_kodu[is.na(urunler$varsayilan_yogunluk)]
         length(bos) == 0 ||
           all(vapply(bos, function(k) {
             inherits(try(cbam_product(k), silent = TRUE), "try-error")
           }, logical(1))) })
expect("dogrulanmamis urun uyari uretir",
       { p <- cbam_product(urunler$urun_kodu[1])
         if (p$dogrulandi) is.null(cbam_dogrulama_uyarisi(p))
         else length(cbam_dogrulama_uyarisi(p)) > 0 })
expect("kaynaksiz deger acikca isaretlenir",
       cbam_kaynak_metni("", "") == "KAYNAK GIRILMEDI")
expect("kaynak metni belge ve yeri birlestirir",
       cbam_kaynak_metni("REG-2023-956", "Ek II") == "REG-2023-956, Ek II")
expect_error("bilinmeyen urun kodu reddedilir", cbam_product("yok-boyle-urun"))

cat("\n== calculator.R ==\n")
est <- cbam_estimate(quantity = 1000, ei_direct = 1.9, benchmark = 1.288,
                     year = 2034, carbon_price = 80, fx_rate = 48,
                     uncertainty = FALSE)
expect("cikti cbam_estimate sinifinda", inherits(est, "cbam_estimate"))
expect("2034'te ucretsiz tahsisat sifir",
       est$deterministic$free_allocation == 0)
expect("2034'te tum gomulu emisyon vergilenir",
       est$deterministic$certificates == 1900)
expect("maliyet = sertifika * fiyat",
       est$deterministic$cost_eur == 1900 * 80)
expect("yerel maliyet kur ile cevrilir",
       est$deterministic$cost_local == 1900 * 80 * 48)
expect("ton basina yuk dogru",
       abs(est$deterministic$cost_per_tonne - 152) < 1e-9)
expect("vergilenen oran 2034'te %100",
       abs(est$deterministic$taxed_share - 1) < 1e-12)
expect("uncertainty = FALSE simulasyon uretmez",
       is.null(est$simulation))

est26 <- cbam_estimate(1000, 1.9, 1.288, year = 2026, carbon_price = 80,
                       uncertainty = FALSE)
expect("2026 ucretsiz tahsisati benchmark uzerinden",
       abs(est26$deterministic$free_allocation - 1.288 * 1000 * 0.975) < 1e-9)
expect("2026'da benchmark ustu firma yine de oder",
       abs(est26$deterministic$certificates - (1900 - 1255.8)) < 1e-9)
expect("2026'da emisyonun ucte birinden fazlasi vergilenir",
       est26$deterministic$taxed_share > 0.33)

expect("mensede odenen karbon fiyat olarak dusulur",
       { e <- cbam_estimate(1000, 1.9, 1.288, year = 2034,
                            carbon_price_paid = 32,
                            cbam_reference_price = 80, uncertainty = FALSE)
         e$deterministic$certificates == 1500 })
expect("hesap makinesi referans fiyati olmadan reddeder",
       inherits(try(cbam_estimate(1000, 1.9, 1.288, year = 2034,
                                  carbon_price_paid = 32,
                                  uncertainty = FALSE), silent = TRUE),
                "try-error"))
expect("de minimis esigi altinda yukumluluk yok",
       { e <- cbam_estimate(20, 1.9, 1.288, year = 2034, uncertainty = FALSE)
         e$deterministic$de_minimis &&
           e$deterministic$certificates == 0 &&
           e$deterministic$cost_eur == 0 })
expect("dolayli emisyon istege bagli dahil",
       { e <- cbam_estimate(1000, 1.9, 1.288, year = 2034, ei_indirect = 0.5,
                            include_indirect = TRUE, uncertainty = FALSE)
         e$deterministic$embedded == 2400 })
expect("belirsizlik istendiginde simulasyon uretilir",
       { e <- cbam_estimate(1000, 1.9, 1.288, year = 2030, n_sims = 2000,
                            seed = 1)
         inherits(e$simulation, "cbam_mc") && nrow(e$simulation$draws) == 2000 })
expect("deterministik sonuc simulasyon medyanina yakin duruyor",
       { e <- cbam_estimate(1000, 1.9, 1.288, year = 2026, carbon_price = 80,
                            n_sims = 20000, seed = 1)
         d <- e$deterministic$cost_eur
         m <- median(e$simulation$draws$cost_eur)
         abs(m - d) / d < 0.25 })
expect_error("negatif miktar reddedilir",
             cbam_estimate(-5, 1.9, 1.288, uncertainty = FALSE))
expect_error("negatif karbon fiyati reddedilir",
             cbam_estimate(1000, 1.9, 1.288, carbon_price = -1,
                           uncertainty = FALSE))
expect_error("sifir kur reddedilir",
             cbam_estimate(1000, 1.9, 1.288, fx_rate = 0, uncertainty = FALSE))
expect_error("vektor girdi reddedilir",
             cbam_estimate(c(1000, 2000), 1.9, 1.288, uncertainty = FALSE))

cat("\n== report.R ==\n")
expect("html_kacis ozel karakterleri kacirir",
       html_kacis("<a href=\"x\">A&B</a>") ==
         "&lt;a href=&quot;x&quot;&gt;A&amp;B&lt;/a&gt;")

rapor_dosya <- file.path(tempdir(), "cbam_test_rapor.html")
if (file.exists(rapor_dosya)) file.remove(rapor_dosya)
est_rapor <- cbam_estimate(250000, 1.95, 1.288, year = 2030,
                           carbon_price = 80, fx_rate = 48,
                           n_sims = 3000, seed = 2026,
                           reference = cbam_product("celik-hrc"))
cbam_rapor(est_rapor, rapor_dosya, firma = "Test A.S.")
rapor_html <- paste(readLines(rapor_dosya, warn = FALSE), collapse = "\n")

expect("rapor dosyasi olusturuldu", file.exists(rapor_dosya))
# Rapor tek dosya olmali: internet olmadan acilmali, e-postayla gonderilmeli.
expect("rapor disaridan hicbir sey yuklemiyor",
       !grepl("src=|href=\"http|@import|fetch\\(", rapor_html))
expect("rapor gecerli HTML iskeletiyle basliyor",
       grepl("^<!doctype html>", rapor_html) &&
         grepl("</html>$", trimws(rapor_html)))
expect("rapor firma adini tasiyor", grepl("Test A.S.", rapor_html, fixed = TRUE))
expect("rapor hesap adimlarini gosteriyor",
       grepl("Gomulu emisyon", rapor_html, fixed = TRUE) &&
         grepl("Ucretsiz tahsisat", rapor_html, fixed = TRUE))
expect("rapor dagilim grafigi iceriyor",
       grepl("<svg", rapor_html, fixed = TRUE) &&
         length(gregexpr("<rect", rapor_html)[[1]]) > 5)
# Veri surumu her ciktida gorunmeli - referans tablolari habersiz revize
# ediliyor ve kullanici hangi tarihli veriyle hesap yaptigini gormeli.
expect("veri surumu referanssiz hesapta da basiliyor",
       { e <- cbam_estimate(1000, 1.9, 1.288, year = 2030,
                            uncertainty = FALSE)
         cikti <- capture.output(print(e))
         any(grepl("Referans veri paketi", cikti, fixed = TRUE)) })
expect("veri surumu kaynak tarihlerini tasiyor",
       grepl("2026", cbam_data_version(), fixed = TRUE))

expect("rapor provenans bloku iceriyor",
       grepl("Rastgele tohum", rapor_html, fixed = TRUE) &&
         grepl("2026", rapor_html, fixed = TRUE))
# AGPL 7(b) atif sarti: kunye her raporda gomulu gelmeli.
expect("rapor kunyeyi tasiyor",
       grepl("0009-0007-4824-752X", rapor_html, fixed = TRUE) &&
         grepl("AGPL", rapor_html, fixed = TRUE))
# Referans degerlerin tamami (benchmark + varsayilan yogunluk) resmi
# kaynaktan geldigi icin artik uyari CIKMAMALI. Bu test o durumu kilitler:
# biri kaynaksiz bir deger eklerse uyari geri gelir ve test kirilir.
expect("tamamen dogrulanmis referansta uyari cikmaz",
       !grepl("DOGRULANMAMIS", rapor_html, fixed = TRUE))
expect("celik-hrc referansi tamamen dogrulanmis sayilir",
       isTRUE(cbam_product("celik-hrc")$dogrulandi))
expect("dogrulama uyarisi dogrulanmis urun icin NULL",
       is.null(cbam_dogrulama_uyarisi(cbam_product("celik-hrc"))))
expect("referanssiz raporda dogrulama uyarisi cikmaz",
       { f3 <- file.path(tempdir(), "cbam_test_rapor3.html")
         e3 <- cbam_estimate(1000, 1.9, 1.288, year = 2030,
                             uncertainty = FALSE)
         cbam_rapor(e3, f3)
         h3 <- paste(readLines(f3, warn = FALSE), collapse = "\n")
         !grepl("DOGRULANMAMIS", h3, fixed = TRUE) &&
           grepl("kullanici girdisi", h3, fixed = TRUE) })
expect("kesin modda rapor belirsizlik bolumu icermez",
       { f2 <- file.path(tempdir(), "cbam_test_rapor2.html")
         e2 <- cbam_estimate(1000, 1.9, 1.288, year = 2030, uncertainty = FALSE)
         cbam_rapor(e2, f2)
         h2 <- paste(readLines(f2, warn = FALSE), collapse = "\n")
         !grepl("Belirsizlik", h2, fixed = TRUE) })
expect_error("rapor yanlis girdi tipini reddeder",
             cbam_rapor(data.frame(a = 1), file.path(tempdir(), "x.html")))

# --- 2026-10-21 bagimsiz dogrulamasinda bulunan hatalar (B1-B6) ----------
# Her test, v1.0.0'da KALAN ve duzeltmeyle GECEN davranisi kilitler.
cat("\n== dogrulama bulgulari (B1-B6) ==\n")

# B1 - Varsayilan degere mark-up (Rehber No. 3 s.113; Rehber No. 4 Tablo 2-4)
expect("B1 mark-up 2026 %10, 2027 %20, 2028+ %30",
       all(abs(cbam_default_markup(c(2026, 2027, 2028, 2034)) -
                 c(.10, .20, .30, .30)) < 1e-12))
expect("B1 gubrede mark-up %1",
       all(abs(cbam_default_markup(c(2026, 2030), "Fertilisers") - .01) < 1e-12))
expect("B1 Rehber 4 Tablo 2-4: 3,000 -> 3,300 / 3,600 / 3,900",
       all(abs(3 * (1 + cbam_default_markup(2026:2028)) - c(3.3, 3.6, 3.9)) < 1e-12))
expect_error("B1 2026 oncesi mark-up tanimsiz", cbam_default_markup(2025))
expect("B1 CN 7208 2030: 2,428 x 1,30 = 3,1564",
       abs(cbam_default_see("72081000", 2030)$deger - 2.428 * 1.3) < 1e-12)
expect("B1 yil verilmezse temel deger (mark-up yok)",
       { s <- cbam_default_see("72081000"); s$markup == 0 && s$deger == 2.428 })
expect("B1 amonyak 2030: 2,270 x 1,01 = 2,293 (piyasadaki rakam)",
       abs(round(cbam_default_see("28141000", 2030)$deger, 3) - 2.293) < 1e-12)
expect("B1 CLI: CN 72081000, 250.000 t, 2030 -> 49.017.000 EUR",
       { o <- system2("Rscript", c("hesapla.R", "--cn", "72081000", "--miktar",
                                   "250000", "--yil", "2030", "--kesin"),
                      stdout = TRUE, stderr = TRUE)
         any(grepl("49.017.000 EUR", o, fixed = TRUE)) })
expect("B1 kendi yogunlugunda mark-up uygulanmaz",
       { o <- system2("Rscript", c("hesapla.R", "--cn", "72081000", "--yogunluk",
                                   "1.95", "--miktar", "1000", "--yil", "2030",
                                   "--kesin"), stdout = TRUE, stderr = TRUE)
         any(grepl("1,950 tCO2e/ton", o, fixed = TRUE)) &&
           !any(grepl("mark-up", o, fixed = TRUE)) })

# B2 - Rota ve yila gore benchmark (Rehber No. 4 Tablo 2-2, 2-3)
expect("B2 dusuk alasimli celik 2027 -> (F)(1) 1,673",
       abs(cbam_benchmark_by_cn("72255020", yil = 2027, rota = "F")$benchmark - 1.673) < 1e-9)
expect("B2 dusuk alasimli celik 2028 -> (F)(2) 1,499",
       abs(cbam_benchmark_by_cn("72255020", yil = 2028, rota = "F")$benchmark - 1.499) < 1e-9)
expect("B2 (C)/(F) bilesik gostergesi kodda olani secer",
       cbam_benchmark_by_cn("72255020", yil = 2028, rota = "(C)/(F)")$rota == "(F)(2)")
expect("B2 Tablo 2-3 ham celik rotalari: C 1,364 / D 0,475 / E 0,066",
       all(abs(vapply(c("C", "D", "E"), function(r)
         cbam_benchmark_by_cn("72071111", rota = r)$benchmark, 0) -
           c(1.364, 0.475, 0.066)) < 1e-9))
expect("B2 rota belirsizse ilk satir + aciklayici not",
       { b <- cbam_benchmark_by_cn("72071111")
         b$rota == "(C)" && grepl("--rota", b$not, fixed = TRUE) })
expect("B2 2031+ icin 2028-30 degeri ve not",
       { b <- cbam_benchmark_by_cn("25233000", yil = 2032)
         abs(b$benchmark - 0.686) < 1e-9 && grepl("2031", b$not, fixed = TRUE) })
expect("B2 beyaz klinker (B) secilebilir",
       abs(cbam_benchmark_by_cn("25231000", rota = "B")$benchmark - 0.859) < 1e-9)

# B3 - De minimis: 50 tonu ASMAYAN miktar muaf
expect("B3 tam 50 ton muaf", is_de_minimis(50) && !is_de_minimis(50.001))

# B4 - 2026 oncesi mali yukumluluk yok
expect_error("B4 2025 yili hata verir (sahte maliyet yok)",
             cbam_estimate(1e5, 2, 1.37, year = 2025, uncertainty = FALSE))
expect("B4 CLI 2025 icin acik hata",
       { o <- suppressWarnings(system2("Rscript", c("hesapla.R", "--cn", "72081000",
                                   "--miktar", "1000", "--yil", "2025"),
                      stdout = TRUE, stderr = TRUE))
         any(grepl("2026 ya da sonrasi", o, fixed = TRUE)) })

# B5 - Odenen karbon simulasyonda da dusulur
expect("B5 deterministik 0 ise ufuk 0 simulasyonu da 0",
       { e <- cbam_estimate(1e5, 2, 1.37, year = 2026, carbon_price = 80,
                            carbon_price_paid = 500, cbam_reference_price = 80,
                            theta_sdlog = 0, n_sims = 2000)
         e$deterministic$cost_eur == 0 && all(e$simulation$draws$cost_eur == 0) })
expect("B5 ufuk 0'da simulasyon deterministikle ayni",
       { e <- cbam_estimate(1e5, 2, 1.37, year = 2026, carbon_price = 80,
                            carbon_price_paid = 20, cbam_reference_price = 80,
                            theta_sdlog = 0, n_sims = 500)
         all(abs(e$simulation$draws$cost_eur - e$deterministic$cost_eur) < 1e-6) })
expect("B5 odenen karbon simulasyon medyanini dusurur",
       { a <- cbam_estimate(1e5, 2.4, 1.37, year = 2030, n_sims = 5000, seed = 3)
         b <- cbam_estimate(1e5, 2.4, 1.37, year = 2030, n_sims = 5000, seed = 3,
                            carbon_price_paid = 50, cbam_reference_price = 80)
         median(b$simulation$draws$cost_eur) < median(a$simulation$draws$cost_eur) })

# B6 - --cn ve --urun ayni mal icin ayni sonucu verir (sinter: dolayli dahil)
expect("B6 sinter: --urun ve --cn ayni maliyet",
       { m <- function(...) { o <- system2("Rscript", c("hesapla.R", ..., "--miktar",
                               "100000", "--yil", "2030", "--kesin"),
                               stdout = TRUE, stderr = TRUE)
                              grep("CBAM MALIYETI", o, value = TRUE) }
         a <- m("--urun", "demir-sinter"); b <- m("--cn", "26011200")
         length(a) == 1 && identical(a, b) })
expect("B6 urun yogunlugu dolayli kapsamda TOPLAM degeri kullanir",
       { p <- cbam_product("demir-sinter", yil = 2030)
         abs(p$varsayilan_temel - cbam_default_intensity("26011200")$toplam) < 1e-12 })

# B7 - Raporda CN yolundaki resmi degerler "kullanici girdisi" gorunmemeli
expect("B7 CN yolunda rapor resmi kaynagi ve mark-up'i gosterir",
       { f <- file.path(tempdir(), "cbam_b7.html")
         o <- system2("Rscript", c("hesapla.R", "--cn", "72081000", "--miktar",
                                   "1000", "--yil", "2030", "--kesin",
                                   "--rapor", f), stdout = TRUE, stderr = TRUE)
         h <- paste(readLines(f, warn = FALSE), collapse = "\n")
         grepl("CBAM-DEFAULT-VALUES", h, fixed = TRUE) &&
           grepl("mark-up", h, fixed = TRUE) &&
           grepl("CBAM-BENCHMARKS", h, fixed = TRUE) })

# --- Tum ulkeler ve "Other countries and territories" (Rehber 3 s.114) ------
cat("\n== mense ulke ve diger ulkeler tablosu ==\n")
expect("varsayilan tablo 121 ulke + Other tasiyor",
       { u <- unique(dv_tablo$ulke)
         length(u) == 122 && CBAM_DIGER_ULKELER %in% u })
expect("Turkiye degerleri v1.0.0 ile ayni (CN 7208 = 2,428)",
       abs(cbam_default_intensity("72081000")$dogrudan - 2.428) < 1e-12)
expect("Cin CN 7208 = 3,187; Hindistan = 4,280; Other = 4,049",
       abs(cbam_default_intensity("72081000", "China")$dogrudan - 3.187) < 1e-12 &&
         abs(cbam_default_intensity("72081000", "India")$dogrudan - 4.280) < 1e-12 &&
         abs(cbam_default_intensity("72081000", "diger")$dogrudan - 4.049) < 1e-12)
expect("B8 Turkiye'de '-' olan gri klinker Other tablosuna duser (1,410)",
       { d <- cbam_default_intensity("2523100090")
         isTRUE(d$yedek) && d$ulke == CBAM_DIGER_ULKELER && abs(d$toplam - 1.41) < 1e-12 })
expect("B8 ulke degeri varken Other'a dusulmez",
       !isTRUE(cbam_default_intensity("72081000")$yedek))
expect("B8 '-' satiri daha genel onek satirina degil Other'a duser",
       { # Turkiye'de 2523100090 '-' ; 2523 onekli degerli bir Turkiye satiri olsa
         # bile secilmemeli - aramanin '-' satirinda durdugunu dogrula
         d <- cbam_default_intensity("2523100090"); d$cn_kodu == "2523100090" })
expect_error("8 haneli kod birden fazla TARIC'e ayriliyorsa hata (secim sessiz degil)",
             cbam_default_intensity("25231000"))
expect("10 haneli TARIC kodunda benchmark ilk 8 haneden, rota ile gri (A)",
       { b <- cbam_benchmark_by_cn("2523100090", rota = "(A)")
         abs(b$benchmark - 0.666) < 1e-12 })
expect("ulke adi buyuk/kucuk harf ve Turkce karakterden bagimsiz",
       cbam_ulke("türkiye") == "Turkiye" && cbam_ulke("CHINA") == "China")
expect_error("taninmayan ulke adi sessizce Other'a dusmez", cbam_ulke("Chna"))
expect_error("AB ETS ulkesi (Norvec) icin CBAM uygulanmaz", cbam_ulke("Norway"))
expect("Ek III bolgesi (Ceuta) muaf", cbam_muaf_ulke("Ceuta"))
# Rehber No. 4'te BASILI ornekler - Excel'den bagimsiz resmi kaynak.
expect("Rehber 4 Tablo 2-4: Cezayir 7318 15 = 3,000 (C), mark-up'li 3,3/3,6/3,9",
       { d <- cbam_default_intensity("73181520", "Algeria")
         m <- vapply(2026:2028, function(y)
           cbam_default_see("73181520", y, "Algeria")$deger, 0)
         abs(d$toplam - 3) < 1e-12 && d$rota == "(C)" &&
           all(abs(m - c(3.3, 3.6, 3.9)) < 1e-12) })
expect("Rehber 4 Tablo 2-4/2-3: Cezayir rotasiyla 73181520 benchmark 1,364",
       abs(cbam_benchmark_by_cn("73181520", yil = 2026, rota = "(C)")$benchmark - 1.364) < 1e-12)
expect("Rehber 4 Tablo 2-3: 73181535 yila bagli 1,154 (2026-27) / 1,116 (2028-30)",
       abs(cbam_benchmark_by_cn("73181535", yil = 2027)$benchmark - 1.154) < 1e-12 &&
         abs(cbam_benchmark_by_cn("73181535", yil = 2028)$benchmark - 1.116) < 1e-12)
expect("CLI gri klinker: 100.000 t, 2030 -> 11.920.080 EUR (Other + %30)",
       { o <- system2("Rscript", c("hesapla.R", "--cn", "2523100090", "--miktar",
                                   "100000", "--yil", "2030", "--kesin"),
                      stdout = TRUE, stderr = TRUE)
         any(grepl("11.920.080 EUR", o, fixed = TRUE)) &&
           any(grepl("Other countries and territories", o, fixed = TRUE)) })

# Rapor: de minimis nedeni ve esik asilirsa yuk gorunmeli; resmi tablo
# hesabi "DOGRULANMADI" gorunmemeli; kur girilmediyse 1 TRY/EUR yazmamali.
expect("rapor de minimis'i aciklar ve esik ustu yuku gosterir (10 t gri klinker)",
       { f <- file.path(tempdir(), "cbam_dm.html")
         system2("Rscript", c("hesapla.R", "--cn", "2523100090", "--miktar", "10",
                              "--yil", "2026", "--rapor", f), stdout = FALSE, stderr = FALSE)
         h <- paste(readLines(f, warn = FALSE), collapse = "\n")
         grepl("De minimis muafiyeti", h, fixed = TRUE) &&
           grepl("721,32 EUR", h, fixed = TRUE) &&
           !grepl("DOGRULANMADI", h, fixed = TRUE) &&
           grepl("yalnizca EUR raporlandi", h, fixed = TRUE) &&
           grepl("CN 2523100090", h, fixed = TRUE) })

expect("tam rapor 3 grafik, tablo gorunumu ve varsayimlar kutusu icerir",
       { f <- file.path(tempdir(), "cbam_tam.html")
         system2("Rscript", c("hesapla.R", "--cn", "2523100090", "--miktar", "100000",
                              "--yil", "2030", "--kur", "55", "--simulasyon", "2000",
                              "--rapor", f), stdout = FALSE, stderr = FALSE)
         h <- paste(readLines(f, warn = FALSE), collapse = "\n")
         length(gregexpr("<svg", h, fixed = TRUE)[[1]]) == 3 &&
           grepl("Yillara gore CBAM maliyeti", h, fixed = TRUE) &&
           grepl("Kendi olcumunuzle maliyet", h, fixed = TRUE) &&
           grepl("Tablo olarak goster", h, fixed = TRUE) &&
           grepl("Karbon fiyati 80 EUR/tCO2e: aracin varsayilani", h, fixed = TRUE) &&
           grepl("2030: 11.920.080 EUR", h, fixed = TRUE) })
expect("yillik yol: 2026 gri klinker 100.000 t = 7.213.200 EUR (mark-up %10, faktor %97,5)",
       { y <- cbam_yillik_yol(100000, "2523100090", carbon_price = 80)
         nrow(y) == 9 && abs(y$cost_eur[1] - 7213200) < 1e-6 })

# --- Gozden gecirmede bulunanlar (2026-10-22) -------------------------------
cat("\n== tutarlilik: yillik yol = manset, uc durumlar ==\n")
expect("yillik yol, kullanici yogunlugunda da ulke rotasini kullanir",
       { # Rota bilgisi yolda kaybolursa bu iki deger ayrisir.
         # Cezayir ham aluminyum: ulke rotasi (L) ikincil, tablonun ilk satiri (K).
         y <- cbam_yillik_yol(1000, "76011090", ulke = "Algeria", ei = 2,
                              yillar = 2030)
         r <- cbam_default_see("76011090", 2030, "Algeria")$rota
         b <- cbam_benchmark_by_cn("76011090", yil = 2030, rota = r)
         r == "(L)" && abs(y$benchmark - b$benchmark) < 1e-12 &&
           abs(y$benchmark - cbam_benchmark_by_cn("76011090", yil = 2030)$benchmark) > 1e-6 })
expect("yillik yol --dolayli-dahil ile manseti tutar",
       { e <- cbam_estimate(1000, 2, 1.37, year = 2030, ei_indirect = 0.5,
                            include_indirect = TRUE, uncertainty = FALSE)
         y <- cbam_yillik_yol(1000, ei = 2, benchmark = 1.37, ei_indirect = 0.5,
                              include_indirect = TRUE, yillar = 2030)
         abs(y$cost_eur - e$deterministic$cost_eur) < 1e-6 })
expect_error("run_cbam_mc de 2026 oncesini reddeder",
             run_cbam_mc(100, 1000, 2, benchmark = 1.37, year = 2025))
expect("karbon fiyati 0 + odenen karbon: simulasyon NaN uretmez",
       { e <- cbam_estimate(1000, 2, 1.37, year = 2030, carbon_price = 0,
                            carbon_price_paid = 5, cbam_reference_price = 80,
                            n_sims = 500)
         all(is.finite(e$simulation$draws$cost_eur)) })

# --- Web sayfasi girisi (index.html -> cbam_web_rapor) ---------------------
cat("\n== web girisi ==\n")
expect("web raporu komut satiriyla ayni sonucu verir (49.017.000 EUR)",
       { h <- cbam_web_rapor("72081000", 250000, 2030, n_sims = 500)
         grepl("49.017.000", h, fixed = TRUE) &&
           grepl("rota (C) kullanildi", h, fixed = TRUE) })
expect("web raporunda rotaya bagli esik grafigi yok",
       { h <- cbam_web_rapor("72081000", 250000, 2030, n_sims = 500)
         !grepl("Kendi olcumunuzle maliyet", h, fixed = TRUE) &&
           length(gregexpr("<svg", h, fixed = TRUE)[[1]]) == 2 })
expect("hesaplayici.js motorun tum R dosyalarini yukler",
       { s <- paste(readLines("hesaplayici.js", warn = FALSE, encoding = "UTF-8"), collapse = "\n")
         all(vapply(list.files("R", pattern = "\\.R$", full.names = TRUE),
                    function(f) grepl(paste0('"', f, '"'), s, fixed = TRUE), logical(1))) })
expect("web raporu de minimis'i aciklar",
       grepl("De minimis muafiyeti",
             cbam_web_rapor("2523100090", 10, 2026), fixed = TRUE))
expect_error("web girisi taninmayan kodu reddeder",
             cbam_web_rapor("99999999", 100, 2030, n_sims = 100))
expect("kendi degeri + rota yoksa komut satiri uyarir",
       { o <- system2("Rscript", c("hesapla.R", "--cn", "72081000", "--yogunluk",
                                   "0.5", "--miktar", "1000", "--yil", "2030",
                                   "--kesin"), stdout = TRUE, stderr = TRUE)
         any(grepl("--rota", o, fixed = TRUE)) })
expect("rota verilince uyari cikmaz",
       { o <- system2("Rscript", c("hesapla.R", "--cn", "72081000", "--yogunluk",
                                   "0.5", "--rota", "E", "--miktar", "1000",
                                   "--yil", "2030", "--kesin"),
                      stdout = TRUE, stderr = TRUE)
         !any(grepl("--rota", o, fixed = TRUE)) })

cat(sprintf("\n=====================================\n"))
cat(sprintf("Toplam: %d gecti, %d kaldi\n", passed, failed))
cat(sprintf("=====================================\n"))
if (failed > 0) quit(status = 1)
