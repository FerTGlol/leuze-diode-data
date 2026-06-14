# =============================================================================
# polarimeter_data_analysis.R
# Stokes Polarimetry and Long-Distance Stability Analysis Pipeline
# =============================================================================

library(tidyverse)
library(janitor)
library(writexl)

# =============================================================================
# ── LEUZE LOCAL DIRECTORY CONFIGURATION (FILL IN BEFORE RUNNING) ─────────────
# =============================================================================

# Set the working directory to the folder containing your raw polarimeter CSV exports
# Example: setwd("C:/Leuze/Projects/Polarization/data")
setwd("")

# =============================================================================
# ── DATA INGESTION & PIPELINE INITIALIZATION ─────────────────────────────────
# =============================================================================

# Load experimental batches (Skipping the standard 8-line Thorlabs polarimeter header)
df21 <- read_delim("", skip = 8, delim = ";")
df22 <- read_delim("", skip = 8, delim = ";")
df23 <- read_delim("", skip = 8, delim = ";")
df24 <- read_delim("", skip = 8, delim = ";")
df25 <- read_delim("", skip = 8, delim = ";")
df26 <- read_delim("", skip = 8, delim = ";")
df27 <- read_delim("", skip = 8, delim = ";")
df28 <- read_delim("", skip = 8, delim = ";")
df29 <- read_delim("", skip = 8, delim = ";")
df30 <- read_delim("", skip = 8, delim = ";")

# =============================================================================
# ── DATA CLEANING & NORMALIZE HEADERS ────────────────────────────────────────
# =============================================================================

# Clean and standardize column names into snake_case format
df21 <- df21 %>% clean_names()
df22 <- df22 %>% clean_names()
df23 <- df23 %>% clean_names()
df24 <- df24 %>% clean_names()
df25 <- df25 %>% clean_names()
df26 <- df26 %>% clean_names()
df27 <- df27 %>% clean_names()
df28 <- df28 %>% clean_names()
df29 <- df29 %>% clean_names()
df30 <- df30 %>% clean_names()

# Add metadata columns for downstream aggregation
df21$diode <- 21
df22$diode <- 22
df23$diode <- 23
df24$diode <- 24
df25$diode <- 25
df26$diode <- 26
df27$diode <- 27
df28$diode <- 28
df29$diode <- 29
df30$diode <- 30

# Combine individual datasets into a unified master telemetry dataframe
master_df <- rbind(df21, df22, df23, df24, df25, df26, df27, df28, df29, df30)

# =============================================================================
# ── PARAMETRIC ANALYSIS & STATISTICS ─────────────────────────────────────────
# =============================================================================

# Extract summary statistics grouped by unique diode hardware
summary_stats <- master_df %>% 
  group_index(diode) %>% 
  summarise(
    mean_dop       = mean(dop_percent, na.rm = TRUE),
    mean_azimuth   = mean(azimuth_deg, na.rm = TRUE),
    mean_elliptity = mean(ellipticity_deg, na.rm = TRUE),
    mean_power_mw  = mean(power_m_w, na.rm = TRUE)
  )

# Export calculated statistics to Excel for documentation and reporting
write_xlsx(summary_stats, "Polarization_Summary_Statistics.xlsx")

# =============================================================================
# ── LONG-DISTANCE TRANSVERSE DIAGNOSTICS (DIODE 24 CASE STUDY) ───────────────
# =============================================================================

# Ingest long-distance operational parameters (No collimator attached)
d24l <- read_delim("", skip = 7, delim = ";")
d24l <- d24l %>% clean_names()

# Time-series analysis: Degree of Polarization (DOP) over runtime
d24l %>% 
  filter(dop_percent < 100) %>% 
  ggplot(aes(y = dop_percent, x = time_date_hh_mm_ss)) + 
  geom_line() +
  labs(title = "DOP Stability Over Time (No Collimator)", x = "Timestamp", y = "DOP (%)")

# Time-series analysis: Optical Power Emitted (mW) over runtime
d24l %>% 
  ggplot(aes(y = power_m_w, x = time_date_hh_mm_ss)) + 
  geom_line() +
  labs(title = "Optical Power Stability Over Time", x = "Timestamp", y = "Power (mW)")

# Phase space analysis: Normalized S1 Stokes parameter vs. Degree of Polarization
d24l %>% 
  ggplot(aes(y = normalized_s_1, x = dop_percent)) + 
  geom_point(alpha = 0.5) +
  labs(title = "Stokes S1 Behavior vs. Total DOP", x = "DOP (%)", y = "Normalized S1")

# Time-series analysis: Normalized S2 Stokes parameter over runtime
d24l %>% 
  ggplot(aes(y = normalized_s_2, x = time_date_hh_mm_ss)) + 
  geom_line() +
  labs(title = "Stokes S2 Behavior Over Time", x = "Timestamp", y = "Normalized S2")

# =============================================================================
# ── REPLICATION SCAN: ADVANCED TESTING DISTANCE ──────────────────────────────
# =============================================================================

# Ingest secondary long-distance run data
d24l2 <- read_delim("", skip = 7, delim = ";")
d24l2 <- d24l2 %>% clean_names()

# Verify stability correlation on replication scan
d24l2 %>% 
  filter(dop_percent < 100) %>% 
  ggplot(aes(y = dop_percent, x = time_date_hh_mm_ss)) + 
  geom_line() +
  labs(title = "Replication Run: DOP Stability Profile", x = "Timestamp", y = "DOP (%)")

# =============================================================================
# ── MANUAL NOISE FILTERING & OUTLIER REMOVAL ─────────────────────────────────
# =============================================================================

# Compute raw historical baseline before filtering artifacts
raw_dop_mean <- mean(d24l2$dop_percent, na.rm = TRUE)

# Filter out anomalous system noise or non-physical data artifacts
filtered_d24l2 <- d24l2 %>% 
  filter(dop_percent > 30 & dop_percent < 90)

# Re-evaluate clean data baseline profile
clean_dop_mean <- mean(filtered_d24l2$dop_percent, na.rm = TRUE)
print(paste("Cleaned Baseline DOP Mean:", round(clean_dop_mean, 2), "%"))