# =============================================================================
# diode_stability_analysis.R
# Short vs. Long Distance Comparative Stokes Polarimetry Pipeline
# =============================================================================

library(tidyverse)
library(janitor)
library(writexl)
library(corrr)
library(rstatix)

# =============================================================================
# ── LEUZE LOCAL DIRECTORY CONFIGURATION (FILL IN BEFORE RUNNING) ─────────────
# =============================================================================

# Set the working directory to the folder containing your comparative distance data
# Example: setwd("C:/Leuze/Projects/Polarization/data")
setwd("")

# =============================================================================
# ── DATA INGESTION ───────────────────────────────────────────────────────────
# =============================================================================

# Load short-distance telemetry file (Skipping the standard 7-line Thorlabs header)
d24l <- read_delim("", skip = 7, delim = ";")

# Load long-distance telemetry file (No collimator attached)
d24l2 <- read_delim("", skip = 7, delim = ";")

# =============================================================================
# ── DATA CLEANING & NORMALIZE HEADERS ────────────────────────────────────────
# =============================================================================

# Clean and standardize column names into snake_case format
d24l  <- d24l %>% clean_names()
d24l2 <- d24l2 %>% clean_names()

# ── Missing Value / NaN Filtering (Short Distance Dataset) ───────────────────
d24l <- d24l %>% filter(
  !is.nan(dop_percent),      !is.nan(normalized_s_1),
  !is.nan(normalized_s_2),    !is.nan(normalized_s_3),
  !is.nan(s_0_m_w),           !is.nan(s_1_m_w),
  !is.nan(s_2_m_w),           !is.nan(s_3_m_w), 
  !is.nan(azimuth),           !is.nan(ellipticity),
  !is.nan(docp_percent),     !is.nan(dolp_percent),
  !is.nan(power_m_w),         !is.nan(pol_power_m_w),
  !is.nan(unpol_power_m_w),   !is.nan(power_split_ratio),
  !is.nan(phase_difference)
)

# ── Missing Value / NaN Filtering (Long Distance Dataset) ────────────────────
d24l2 <- d24l2 %>% filter(
  !is.nan(dop_percent),      !is.nan(normalized_s_1),
  !is.nan(normalized_s_2),    !is.nan(normalized_s_3),
  !is.nan(s_0_m_w),           !is.nan(s_1_m_w),
  !is.nan(s_2_m_w),           !is.nan(s_3_m_w), 
  !is.nan(azimuth),           !is.nan(ellipticity),
  !is.nan(docp_percent),     !is.nan(dolp_percent),
  !is.nan(power_m_w),         !is.nan(pol_power_m_w),
  !is.nan(unpol_power_m_w),   !is.nan(power_split_ratio),
  !is.nan(phase_difference)
)

# =============================================================================
# ── ADVANCED OUTLIER FILTERING ENGINE (INTERQUARTILE RANGE METHOD) ───────────
# =============================================================================

# ── Outlier Removal: Degree of Polarization (DOP) ───────────────────────────
d24l2 <- d24l2 %>% filter(
  dop_percent >= quantile(dop_percent, 0.25, na.rm = TRUE) - 1.5 * IQR(dop_percent, na.rm = TRUE) &
  dop_percent <= quantile(dop_percent, 0.75, na.rm = TRUE) + 1.5 * IQR(dop_percent, na.rm = TRUE)
)

d24l2 %>% ggplot(aes(y = dop_percent, x = time_date_hh_mm_ss)) + 
  geom_line() +
  labs(title = "DOP Stability Profile (Outliers Removed)", x = "Timestamp", y = "DOP (%)")

# ── Outlier Removal: Normalized S1 Stokes Parameter ─────────────────────────
d24l2 <- d24l2 %>% filter(
  normalized_s_1 >= quantile(normalized_s_1, 0.25, na.rm = TRUE) - 1.5 * IQR(normalized_s_1, na.rm = TRUE) &
  normalized_s_1 <= quantile(normalized_s_1, 0.75, na.rm = TRUE) + 1.5 * IQR(normalized_s_1, na.rm = TRUE)
)

d24l2 %>% ggplot(aes(y = normalized_s_1, x = time_date_hh_mm_ss)) + 
  geom_line() +
  labs(title = "Normalized S1 Stokes Vector Stability", x = "Timestamp", y = "Normalized S1")

# ── Outlier Removal: Normalized S2 Stokes Parameter ─────────────────────────
d24l2 <- d24l2 %>% filter(
  normalized_s_2 >= quantile(normalized_s_2, 0.25, na.rm = TRUE) - 1.5 * IQR(normalized_s_2, na.rm = TRUE) &
  normalized_s_2 <= quantile(normalized_s_2, 0.75, na.rm = TRUE) + 1.5 * IQR(normalized_s_2, na.rm = TRUE)
)

d24l2 %>% ggplot(aes(y = normalized_s_2, x = time_date_hh_mm_ss)) + 
  geom_line() +
  labs(title = "Normalized S2 Stokes Vector Stability", x = "Timestamp", y = "Normalized S2")

# ── Outlier Removal: Normalized S3 Stokes Parameter ─────────────────────────
d24l2 <- d24l2 %>% filter(
  normalized_s_3 >= quantile(normalized_s_3, 0.25, na.rm = TRUE) - 1.5 * IQR(normalized_s_3, na.rm = TRUE) &
  normalized_s_3 <= quantile(normalized_s_3, 0.75, na.rm = TRUE) + 1.5 * IQR(normalized_s_3, na.rm = TRUE)
)

d24l2 %>% ggplot(aes(y = normalized_s_3, x = time_date_hh_mm_ss)) + 
  geom_line() +
  labs(title = "Normalized S3 Stokes Vector Stability", x = "Timestamp", y = "Normalized S3")