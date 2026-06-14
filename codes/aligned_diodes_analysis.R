# =============================================================================
# aligned_diodes_analysis.R
# Stokes Matrix Averaging, Outlier Mapping, and Time-Series Trajectory Pipeline
# =============================================================================

library(tidyverse)
library(janitor)
library(writexl)
library(corrr)
library(rstatix)

# =============================================================================
# ── LEUZE LOCAL DIRECTORY CONFIGURATION (FILL IN BEFORE RUNNING) ─────────────
# =============================================================================

# Set the working directory to the folder containing your aligned diode run data
# Example: setwd("C:/Leuze/Projects/Polarization/data")
setwd("")

# =============================================================================
# ── DATA INGESTION & DATA CLEANING ───────────────────────────────────────────
# =============================================================================

# Load short-measurement baseline datasets (Skipping standard 7-line polarimeter headers)
d24 <- read_delim("", skip = 7, delim = ",")
d24 <- d24 %>% clean_names()

# Load individual benchmarking arrays for the production batch sequence
d22 <- read_delim("", skip = 7, delim = ";") %>% clean_names()
d23 <- read_delim("", skip = 7, delim = ";") %>% clean_names()
d25 <- read_delim("", skip = 7, delim = ";") %>% clean_names()
d26 <- read_delim("", skip = 7, delim = ";") %>% clean_names()
d27 <- read_delim("", skip = 7, delim = ";") %>% clean_names()
d28 <- read_delim("", skip = 7, delim = ";") %>% clean_names()
d29 <- read_delim("", skip = 7, delim = ";") %>% clean_names()
d30 <- read_delim("", skip = 7, delim = ";") %>% clean_names()

# =============================================================================
# ── EXPLORATORY DATA ANALYSIS (EDA): OUTLIER DETECTION ───────────────────────
# =============================================================================

# Visual distribution screening via boxplots to assess data variance boundaries
d24 %>% ggplot(aes(normalized_s_1)) + geom_boxplot() + labs(title = "S1 Distribution")
d24 %>% ggplot(aes(normalized_s_2)) + geom_boxplot() + labs(title = "S2 Distribution")
d24 %>% ggplot(aes(normalized_s_3)) + geom_boxplot() + labs(title = "S3 Distribution")
d24 %>% ggplot(aes(power_m_w)) + geom_boxplot() + labs(title = "Optical Power Distribution")

# Note: Preliminary visual audit indicates minimal outlier pollution across standard steps.

# =============================================================================
# ── EXPLORATORY DATA ANALYSIS (EDA): TIME-SERIES TRAJECTORY ──────────────────
# =============================================================================

# Evaluate polarization coordinate drift over consecutive runtime loops
d24 %>% ggplot(aes(x = time_date_hh_mm_ss, y = normalized_s_1)) + geom_line() + labs(x = "Timestamp", y = "Normalized S1")
d24 %>% ggplot(aes(x = time_date_hh_mm_ss, y = normalized_s_2)) + geom_line() + labs(x = "Timestamp", y = "Normalized S2")
d24 %>% ggplot(aes(x = time_date_hh_mm_ss, y = normalized_s_3)) + geom_line() + labs(x = "Timestamp", y = "Normalized S3")
d24 %>% ggplot(aes(x = time_date_hh_mm_ss, y = power_m_w)) + geom_line() + labs(x = "Timestamp", y = "Power (mW)")
d24 %>% ggplot(aes(x = time_date_hh_mm_ss, y = dop_percent)) + geom_line() + labs(x = "Timestamp", y = "DOP (%)")

# =============================================================================
# ── BATCH AGGREGATION & PARAMETRIC MATRIX COMPUTATION ────────────────────────
# =============================================================================

# Extract parametric mean values across core Stokes vectors for alignment mapping
md22 <- d22 %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
md23 <- d23 %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
md24 <- d24 %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
md25 <- d25 %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
md26 <- d26 %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
md27 <- d27 %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
md28 <- d28 %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
md29 <- d29 %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))

# Merge summary matrices into a unified master production tracking dataframe
tot20s  <- rbind(md22, md23, md24, md25, md26, md27, md28, md29)
diodes  <- c(22, 23, 24, 25, 26, 27, 28, 29)
tot20s  <- tot20s %>% mutate(diode = diodes)

# Isolate critical evaluation metrics for final report output
rtot20s <- tot20s %>% select(diode, normalized_s_1, normalized_s_2, normalized_s_3, dop_percent, dolp_percent)

# Export processed summaries to Excel for presentation and filing
write_xlsx(tot20s, "Parametric_Means_Per_Diode.xlsx")
write_xlsx(rtot20s, "Aligned_Polarization_Summary.xlsx")

# =============================================================================
# ── DATA INTEGRITY VERIFICATION: DEVIATION INVESTIGATION (DIODE 23) ──────────
# =============================================================================

# ALERT: Polarization ellipse calculation returned anomalous results for Diode 23 
# under DOP = 1 conditions. Executing targeted data validation scripts below.

# Boxplot distribution audit for tracking anomaly boundaries
d23 %>% ggplot(aes(x = normalized_s_1)) + geom_boxplot() + labs(title = "Diode 23: S1 Validation")
d23 %>% ggplot(aes(x = normalized_s_2)) + geom_boxplot() + labs(title = "Diode 23: S2 Validation")
d23 %>% ggplot(aes(x = normalized_s_3)) + geom_boxplot() + labs(title = "Diode 23: S3 Validation")
d23 %>% ggplot(aes(x = power_m_w))      + geom_boxplot() + labs(title = "Diode 23: Power Validation")
d23 %>% ggplot(aes(x = dop_percent))    + geom_boxplot() + labs(title = "Diode 23: DOP Validation")

# Time-series drift tracking to locate step variations or tracking errors
d23 %>% ggplot(aes(x = time_date_hh_mm_ss, y = normalized_s_1)) + geom_line() + labs(title = "Diode 23: S1 Stability Profile")