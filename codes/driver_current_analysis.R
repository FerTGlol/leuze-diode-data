# =============================================================================
# driver_current_analysis.R
# Parametric Injection Current Sweep and Polarization Stability Pipeline
# =============================================================================

library(tidyverse)
library(janitor)
library(writexl)
library(corrr)
library(rstatix)

# =============================================================================
# ── LEUZE LOCAL DIRECTORY CONFIGURATION (FILL IN BEFORE RUNNING) ─────────────
# =============================================================================

# Set the working directory to the folder containing your injection current sweep data
# Example: setwd("C:/Leuze/Projects/Polarization/data")
setwd("")

# =============================================================================
# ── DATA INGESTION ───────────────────────────────────────────────────────────
# =============================================================================

# Load sweep telemetry files representing different current injection thresholds
# (Skipping standard 7-line polarimeter headers)
data_low_current  <- read_delim("", skip = 7) # Low Threshold Run (e.g., 20.5mA)
data_mid_current  <- read_delim("", skip = 7) # Nominal Operating Run (e.g., 26.9mA)
data_high_current <- read_delim("", skip = 7) # Maximum Power Run (e.g., 32.9mA)

# Load the short-distance 5-minute reference baseline data for Diode 26
data_baseline_d26 <- read_delim("", skip = 7)

# =============================================================================
# ── DATA CLEANING & NORMALIZE HEADERS ────────────────────────────────────────
# =============================================================================

# Clean and standardize column names into snake_case format
data_low_current  <- data_low_current %>% clean_names()
data_mid_current  <- data_mid_current %>% clean_names()
data_high_current <- data_high_current %>% clean_names()
data_baseline_d26 <- data_baseline_d26 %>% clean_names()

# =============================================================================
# ── TIME-SERIES PARAMETRIC TRACKING: DEGREE OF POLARIZATION (DOP) ────────────
# =============================================================================

# Evaluate DOP stability across low, mid, and high current configurations over runtime
data_low_current %>% 
  ggplot(aes(x = time_date_hh_mm_ss, y = dop_percent)) + 
  geom_line() +
  labs(title = "Low Injection Current (20.5mA): DOP Stability Profile", x = "Timestamp", y = "DOP (%)")

data_mid_current %>% 
  ggplot(aes(x = time_date_hh_mm_ss, y = dop_percent)) + 
  geom_line() +
  labs(title = "Nominal Injection Current (26.9mA): DOP Stability Profile", x = "Timestamp", y = "DOP (%)")

data_high_current %>% 
  ggplot(aes(x = time_date_hh_mm_ss, y = dop_percent)) + 
  geom_line() +
  labs(title = "High Injection Current (32.9mA): DOP Stability Profile", x = "Timestamp", y = "DOP (%)")

# TODO: Generate combined probability density / distribution plots to compare DOP variance profiles.

# =============================================================================
# ── TIME-SERIES PARAMETRIC TRACKING: EMITTED OPTICAL POWER ───────────────────
# =============================================================================

# Monitor for optical power degradation or fluctuations over runtime
data_low_current %>% 
  ggplot(aes(x = time_date_hh_mm_ss, y = power_m_w)) + 
  geom_line() +
  labs(title = "Low Injection Current (20.5mA): Power Stability Profile", x = "Timestamp", y = "Power (mW)")

data_mid_current %>% 
  ggplot(aes(x = time_date_hh_mm_ss, y = power_m_w)) + 
  geom_line() +
  labs(title = "Nominal Injection Current (26.9mA): Power Stability Profile", x = "Timestamp", y = "Power (mW)")

data_high_current %>% 
  ggplot(aes(x = time_date_hh_mm_ss, y = power_m_w)) + 
  geom_line() +
  labs(title = "High Injection Current (32.9mA): Power Stability Profile", x = "Timestamp", y = "Power (mW)")