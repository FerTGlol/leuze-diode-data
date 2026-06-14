# =============================================================================
# Malus_Law_Analysis.py
# Parametric Malus's Law Verification and Polarization Analysis Data Pipeline
# =============================================================================

import os
import glob
import re
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.optimize import curve_fit

# =============================================================================
# ── LEUZE LOCAL DIRECTORY CONFIGURATION (FILL IN BEFORE RUNNING) ─────────────
# =============================================================================

# Enter the absolute directory path where your raw experimental CSV files are saved.
# Example: r"C:\Leuze\Projects\Polarization\data"
DATA_DIRECTORY = r""

# Enter the absolute directory path where generated analysis plots and reports should be saved.
# Example: r"C:\Leuze\Projects\Polarization\output"
OUTPUT_DIRECTORY = r""

# =============================================================================
# ── MATHEMATICAL FITTING FUNCTIONS ───────────────────────────────────────────
# =============================================================================

def malus_law_ideal(theta_deg, i_max, theta_0):
    """
    Computes the standard, ideal formulation of Malus's Law.
    Args:
        theta_deg: Angular displacement array in degrees.
        i_max: Maximum transmitted optical peak intensity.
        theta_0: Angular offset phase shift parameter in degrees.
    """
    theta_rad = np.radians(theta_deg - theta_0)
    return i_max * (np.cos(theta_rad) ** 2)

def malus_law_with_offset(theta_deg, i_max, theta_0, leakage_offset):
    """
    Computes Malus's Law with an integrated baseline leakage offset component
    to accurately characterize non-ideal linear polarization extinction states.
    """
    theta_rad = np.radians(theta_deg - theta_0)
    return (i_max * (np.cos(theta_rad) ** 2)) + leakage_offset

# =============================================================================
# ── DATA EXTRACTION PIPELINE ─────────────────────────────────────────────────
# =============================================================================

def parse_experimental_csv(file_path):
    """
    Parses individual experimental telemetry files, handles text headers dynamically,
    and isolates calculation mean metrics.
    """
    try:
        df = pd.read_csv(file_path)
        # Ensure data columns match expected structure
        if 'angle_deg' in df.columns and 'mean_uW' in df.columns:
            return df[['angle_deg', 'mean_uW']].dropna()
        else:
            print(f"[Warning] Invalid layout format in file: {os.path.basename(file_path)}")
            return None
    except Exception as e:
        print(f"[Error] Failed to read resource {os.path.basename(file_path)}: {str(e)}")
        return None

# =============================================================================
# ── BATCH ANALYSIS & VISUALIZATION ENGINE ────────────────────────────────────
# =============================================================================

def analyze_and_plot_batch(diode_ids, batch_label="Batch Analysis"):
    """
    Processes a list of laser diode identifiers, fits experimental power profiles
    to Malus's Law, extracts parametric statistics, and saves high-resolution reports.
    """
    if not DATA_DIRECTORY or not OUTPUT_DIRECTORY:
        raise ValueError("Directories are unconfigured. Please define DATA_DIRECTORY and OUTPUT_DIRECTORY.")

    print("=" * 60)
    print(f" Executing Pipeline: {batch_label}")
    print("=" * 60)

    fitted_angles = []
    valid_ids = []

    # Initialize figure canvas configuration
    fig, ax = plt.subplots(figsize=(9, 6))
    
    for current_id in diode_ids:
        # Search for files matching the standard Diode_{ID}_*.csv nomenclature pattern
        search_pattern = os.path.join(DATA_DIRECTORY, f"Diode_{current_id}_*.csv")
        matching_files = glob.glob(search_pattern)
        
        if not matching_files:
            continue
            
        # Target the first valid instance found matching the identifier
        target_file = matching_files[0]
        data = parse_experimental_csv(target_file)
        
        if data is None:
            continue

        x_data = data['angle_deg'].values
        y_data = data['mean_uW'].values

        # Set foundational seed values for regression tracking bounds
        # i_max seed = max observed value, theta_0 seed = position of max observed value
        initial_guess = [np.max(y_data), x_data[np.argmax(y_data)], np.min(y_data)]
        
        try:
            popt, _ = curve_fit(malus_law_with_offset, x_data, y_data, p0=initial_guess)
            i_max_fit, theta_0_fit, offset_fit = popt
            
            # Normalize calculated parameters to a standardized 0-180 degree window coordinate system
            normalized_theta = theta_0_fit % 180
            fitted_angles.append(normalized_theta)
            valid_ids.append(current_id)
            
            # Generate high-density angular sweep resolution path for plotting fit curve accuracy
            fit_x_fine = np.linspace(np.min(x_data), np.max(x_data), 500)
            fit_y_fine = malus_law_with_offset(fit_x_fine, *popt)

            ax.plot(fit_x_fine, fit_y_fine, alpha=0.7, label=f"Diode {current_id} ({normalized_theta:.1f}°)")
            ax.scatter(x_data, y_data, s=10, alpha=0.4)
            
        except RuntimeError as fit_error:
            print(f"[Fit Failure] Convergence failed for Diode {current_id}: {str(fit_error)}")
            continue

    if not fitted_angles:
        print("[Execution Alert] Zero matching records successfully parsed and fitted.")
        plt.close(fig)
        return None

    # Calculate summary statistical matrices
    theta_mean = np.mean(fitted_angles)
    theta_std = np.std(fitted_angles)

    # Apply clean chart canvas formatting elements
    ax.set_title(f"Malus's Law Polarization Profiling: {batch_label}", fontsize=12, fontweight='bold')
    ax.set_xlabel("Polarizer Rotation Angle (degrees)", fontsize=11)
    ax.set_ylabel("Emitted Optical Transmitted Power (µW)", fontsize=11)
    
    # Place descriptive statistical parameters directly on the chart summary field
    stats_annotation = f"Batch Mean $\\theta_0$: {theta_mean:.2f}°\nStd Dev $\\sigma$: {theta_std:.2f}°"
    ax.text(0.05, 0.05, stats_annotation, transform=ax.transAxes, fontsize=10,
            bbox=dict(facecolor='white', alpha=0.8, edgecolor='lightgray', boxstyle='round,pad=0.5'))
    
    ax.legend(loc='upper right', bbox_to_anchor=(1.25, 1.0), fontsize=9)
    ax.grid(True, linestyle='--', alpha=0.5)
    ax.tick_params(axis='both', which='major', labelsize=10, direction='in')

    for spine in ax.spines.values():
        spine.set_linewidth(1.0)

    fig.tight_layout()
    
    # Save the vector graphic directly to the specified target directory
    output_filename = f"Polarization_Profile_{batch_label.replace(' ', '_')}.png"
    save_path = os.path.join(OUTPUT_DIRECTORY, output_filename)
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    print(f"[Output] Diagnostics visualization chart exported to:\n{save_path}")
    
    plt.show()

    return {
        "batch_label": batch_label,
        "processed_count": len(valid_ids),
        "theta_polarization_mean": theta_mean,
        "theta_polarization_std": theta_std,
        "calculated_angles_map": dict(zip(valid_ids, fitted_angles))
    }

# =============================================================================
# ── TARGET HARDWARE TEST BATCH RUNNER ────────────────────────────────────────
# =============================================================================

if __name__ == "__main__":
    # Example operational definitions matching standard experimental array steps
    batch_20s_ids = list(range(21, 31))
    batch_200s_ids = list(range(203, 211))

    print("Pipeline standing by. Please fill in local workstation paths to run processing loops.")
    # To run, populate local directories above and uncomment the lines below:
    # results_20s = analyze_and_plot_batch(batch_20s_ids, batch_label="Batch 20s (Standard)")
    # results_200s = analyze_and_plot_batch(batch_200s_ids, batch_label="Batch 200s (High Power)")