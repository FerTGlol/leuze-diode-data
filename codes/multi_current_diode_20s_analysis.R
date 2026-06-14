# =============================================================================
# multi_current_diode_20s_analysis.R
# Cross-Diode Comparative Evaluation Across Low, Mid, and High Currents (Batch 20s)
# =============================================================================

library(tidyverse)
library(janitor)
library(writexl)

# =============================================================================
# ── LEUZE LOCAL DIRECTORY CONFIGURATION (FILL IN BEFORE RUNNING) ─────────────
# =============================================================================

# Set the working directory to the folder containing your Batch 20s multi-current files
# Example: setwd("C:/Leuze/Projects/Polarization/data/batch_20s")
setwd("")

# =============================================================================
# ── DATA INGESTION: LOW INJECTION CURRENT (22mA) RUNS ────────────────────────
# =============================================================================

# Load low-current telemetry profiles (Skipping standard 7-line polarimeter headers)
data_d22_low <- read_delim("", skip = 7)
data_d23_low <- read_delim("", skip = 7)
data_d24_low <- read_delim("", skip = 7)
data_d25_low <- read_delim("", skip = 7)
data_d27_low <- read_delim("", skip = 7)
data_d29_low <- read_delim("", skip = 7)

# Clean and standardize column names into snake_case format
data_d22_low <- data_d22_low %>% clean_names()
data_d23_low <- data_d23_low %>% clean_names()
data_d24_low <- data_d24_low %>% clean_names()
data_d25_low <- data_d25_low %>% clean_names()
data_d27_low <- data_d27_low %>% clean_names()
data_d29_low <- data_d29_low %>% clean_names()

# Merge separate metrics into a unified low-current matrix
master_low_current <- rbind(data_d22_low, data_d23_low, data_d24_low, data_d25_low, data_d27_low, data_d29_low)

# =============================================================================
# ── DATA INGESTION: NOMINAL INJECTION CURRENT (28mA) RUNS ────────────────────
# =============================================================================

# Load nominal/mid-current telemetry profiles
data_d22_mid <- read_delim("", skip = 7)
data_d23_mid <- read_delim("", skip = 7)
data_d24_mid <- read_delim("", skip = 7)
data_d25_mid <- read_delim("", skip = 7)
data_d27_mid <- read_delim("", skip = 7)
data_d29_mid <- read_delim("", skip = 7)

data_d22_mid <- data_d22_mid %>% clean_names()
data_d23_mid <- data_d23_mid %>% clean_names()
data_d24_mid <- data_d24_mid %>% clean_names()
data_d25_mid <- data_d25_mid %>% clean_names()
data_d27_mid <- data_d27_mid %>% clean_names()
data_d29_mid <- data_d29_mid %>% clean_names()

# Merge separate metrics into a unified mid-current matrix
master_mid_current <- rbind(data_d22_mid, data_d23_mid, data_d24_mid, data_d25_mid, data_d27_mid, data_d29_mid)

# =============================================================================
# ── DATA INGESTION: HIGH INJECTION CURRENT (34mA) RUNS ───────────────────────
# =============================================================================

# Load maximum-safe/high-current telemetry profiles
data_d22_high <- read_delim("", skip = 7)
data_d23_high <- read_delim("", skip = 7)
data_d24_high <- read_delim("", skip = 7)
data_d25_high <- read_delim("", skip = 7)
data_d27_high <- read_delim("", skip = 7)
data_d29_high <- read_delim("", skip = 7)

data_d22_high <- data_d22_high %>% clean_names()
data_d23_high <- data_d23_high %>% clean_names()
data_d24_high <- data_d24_high %>% clean_names()
data_d25_high <- data_d25_high %>% clean_names()
data_d27_high <- data_d27_high %>% clean_names()
data_d29_high <- data_d29_high %>% clean_names()

# Merge separate metrics into a unified high-current matrix
master_high_current <- rbind(data_d22_high, data_d23_high, data_d24_high, data_d25_high, data_d27_high, data_d29_high)

# =============================================================================
# ── DEGREE OF POLARIZATION (DOP) COMPILATION ─────────────────────────────────
# =============================================================================

# Extract raw vector columns for global batch comparisons
dop_low_array  <- master_low_current$dop_percent
dop_mid_array  <- master_mid_current$dop_percent
dop_high_array <- master_high_current$dop_percent

dolp_low_array  <- master_low_current$dolp_percent
dolp_mid_array  <- master_mid_current$dolp_percent
dolp_high_array <- master_high_current$dolp_percent

docp_low_array  <- master_low_current$docp_percent
docp_mid_array  <- master_mid_current$docp_percent
docp_high_array <- master_high_current$docp_percent

# Combine categorical arrays into analytical data frames
dops  <- data.frame(dop_low_array, dop_mid_array, dop_high_array)
dolps <- data.frame(dolp_low_array, dolp_mid_array, dolp_high_array)
docps <- data.frame(docp_low_array, docp_mid_array, docp_high_array)

# Bind profiles into a final spreadsheet tracking structure
polarization_matrix <- cbind(dops, dolps, docps)

# Export structural matrix data to Excel format
write_xlsx(polarization_matrix, "Batch_20s_Polarization_Metrics.xlsx")

# =============================================================================
# ── PARAMETRIC AVERAGING FOR BEAM POLARIZATION ELLIPSES ──────────────────────
# =============================================================================

# ── High Current Summary Profiles ────────────────────────────────────────────
mean_d22_high <- data_d22_high %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d23_high <- data_d23_high %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d24_high <- data_d24_high %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d25_high <- data_d25_high %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d27_high <- data_d27_high %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d29_high <- data_d29_high %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))

# ── Mid Current Summary Profiles ─────────────────────────────────────────────
mean_d22_mid  <- data_d22_mid  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d23_mid  <- data_d23_mid  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d24_mid  <- data_d24_mid  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d25_mid  <- data_d25_mid  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d27_mid  <- data_d27_mid  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d29_mid  <- data_d29_mid  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))

# ── Low Current Summary Profiles ─────────────────────────────────────────────
mean_d22_low  <- data_d22_low  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d23_low  <- data_d23_low  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d24_low  <- data_d24_low  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d25_low  <- data_d25_low  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d27_low  <- data_d27_low  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d29_low  <- data_d29_low  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))

# Consolidation step complete. Ready to output plotting vectors.