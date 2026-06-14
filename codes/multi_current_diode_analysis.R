# =============================================================================
# multi_current_diode_analysis.R
# Cross-Diode Comparative Evaluation Across Low, Mid, and High Currents
# =============================================================================

library(tidyverse)
library(janitor)
library(writexl)

# =============================================================================
# ── LEUZE LOCAL DIRECTORY CONFIGURATION (FILL IN BEFORE RUNNING) ─────────────
# =============================================================================

# Set the working directory to the folder containing your multi-current batch files
# Example: setwd("C:/Leuze/Projects/Polarization/data/batch_200s")
setwd("")

# =============================================================================
# ── DATA INGESTION: LOW INJECTION CURRENT (22mA) RUNS ────────────────────────
# =============================================================================

# Load low-current telemetry profiles (Skipping standard 7-line polarimeter headers)
data_d205_low <- read_delim("", skip = 7)
data_d206_low <- read_delim("", skip = 7)
data_d207_low <- read_delim("", skip = 7)
data_d208_low <- read_delim("", skip = 7)

# Clean and standardize column names into snake_case format
data_d205_low <- data_d205_low %>% clean_names()
data_d206_low <- data_d206_low %>% clean_names()
data_d207_low <- data_d207_low %>% clean_names()
data_d208_low <- data_d208_low %>% clean_names()

# Merge separate metrics into a unified low-current matrix
master_low_current <- rbind(data_d205_low, data_d206_low, data_d207_low, data_d208_low)

# =============================================================================
# ── DATA INGESTION: NOMINAL INJECTION CURRENT (28mA) RUNS ────────────────────
# =============================================================================

# Load nominal/mid-current telemetry profiles
data_d205_mid <- read_delim("", skip = 7)
data_d206_mid <- read_delim("", skip = 7)
data_d207_mid <- read_delim("", skip = 7)
data_d208_mid <- read_delim("", skip = 7)

data_d205_mid <- data_d205_mid %>% clean_names()
data_d206_mid <- data_d206_mid %>% clean_names()
data_d207_mid <- data_d207_mid %>% clean_names()
data_d208_mid <- data_d208_mid %>% clean_names()

# Merge separate metrics into a unified mid-current matrix
master_mid_current <- rbind(data_d205_mid, data_d206_mid, data_d207_mid, data_d208_mid)

# =============================================================================
# ── DATA INGESTION: HIGH INJECTION CURRENT (34mA) RUNS ───────────────────────
# =============================================================================

# Load maximum-safe/high-current telemetry profiles
data_d205_high <- read_delim("", skip = 7)
data_d206_high <- read_delim("", skip = 7)
data_d207_high <- read_delim("", skip = 7)
data_d208_high <- read_delim("", skip = 7)

data_d205_high <- data_d205_high %>% clean_names()
data_d206_high <- data_d206_high %>% clean_names()
data_d207_high <- data_d207_high %>% clean_names()
data_d208_high <- data_d208_high %>% clean_names()

# Merge separate metrics into a unified high-current matrix
master_high_current <- rbind(data_d205_high, data_d206_high, data_d207_high, data_d208_high)

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
write_xlsx(polarization_matrix, "Batch_200s_Polarization_Metrics.xlsx")

# =============================================================================
# ── PARAMETRIC AVERAGING FOR BEAM POLARIZATION ELLIPSES ──────────────────────
# =============================================================================

# ── High Current Summary Profiles ────────────────────────────────────────────
mean_d205_high <- data_d205_high %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d206_high <- data_d206_high %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d207_high <- data_d207_high %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d208_high <- data_d208_high %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))

# ── Mid Current Summary Profiles ─────────────────────────────────────────────
mean_d205_mid  <- data_d205_mid  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d206_mid  <- data_d206_mid  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d207_mid  <- data_d207_mid  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d208_mid  <- data_d208_mid  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))

# ── Low Current Summary Profiles ─────────────────────────────────────────────
mean_d205_low  <- data_d205_low  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d206_low  <- data_d206_low  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d207_low  <- data_d207_low  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))
mean_d208_low  <- data_d208_low  %>% summarise(across(where(is.numeric), \(x) mean(x, na.rm = TRUE)))

# Consolidation step complete. Ready to output plotting vectors.