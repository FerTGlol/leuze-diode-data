# Laser Diode Polarization Characterization Project 🔴〰️✨

This repository contains the software, raw experimental data, and final technical reporting for the AlGaInP laser diode polarization characterization study conducted for Leuze Electronic. The primary objective of this project was to investigate systemic deviations from ideal linear polarization states and map out microstructural and electro-thermal root causes.

* **Reminder:** When referring to diodes, the "20s" batch corresponds to the ADL-65075TL model, while the "200s" batch corresponds to the ADL-65074TR model. 
---

## 📂 Repository Structure

<p align="center">
  <a href="https://skillicons.dev">
    <img src="https://skillicons.dev/icons?i=julia,latex,matlab,py,r,vscode" />
  </a>
</p>

The project environment is organized into three core directories:

### 1. `codes/`
This folder contains all custom scripts and development pipelines used throughout the experimental phases of the project.
* **Motor Control Automation:** Scripts used to automate and synchronize the rotation motors for the linear polarizers and quarter-wave plates during Malus's Law and Stokes polarimetry testing.
* **Data Visualization & Analytics:** Python, MATLAB, and Julia scripts designed to parse raw data streams, compute pixel-by-pixel Stokes parameters, and automatically generate polarization ellipses and 2D spatial beam maps.

### 2. `result_data/`
This folder serves as the central data warehouse containing all diagnostic data gathered from the multi-level characterization process.
* **CSV Data:** Organized datasets detailing the parametric power sweeps, polarization extinction ratios (PER), and Degree of Polarization (DOP) metrics under varied injection currents and temperatures.
* **Imaging:** High-resolution camera captures of the 2D spatial profiles, optical microscopy alignment checks, and high-magnification Scanning Electron Microscopy (SEM) surface faceting/EDS data.

### 3. `report/`
This folder contains the complete, comprehensive technical documentation for the project.
* **`Final_Report.pdf`:** A full technical laboratory report detailing the state-of-the-art literature review, mathematical matrix formalisms, multi-tiered methodology, engineering infrastructure modifications, and data interpretations. It serves as a complete reference guide for reproducing the experimental setup and analyzing the manufacturing anomalies discovered.
* **`Final_Presentation.pdf`:** The presentation that was shown at the final meeting on Thursday, June 11th (2026). 

---

## 🛠️ Operating Conditions & Frameworks
The codes within this repository interface with hardware configured to meet the following parameters:
* **Max Driving Current:** 35 mA (regulated via a precision Thorlabs driver).
* **Thermal Regulation:** Active Thermoelectric Cooling (TEC) stability down to $\pm 0.01^\circ\text{C}$.
* **Core Environments:** Python, R, MATLAB, and Julia.

---

**Note:** The results presented in `result_data` correspond solely to measurements taken with the temperature-controlled Thorlabs driver, which yielded the most stable and accurate data. Earlier datasets generated from the initial circuit and alternative commercial driver iterations are available in this Google Drive folder: [https://drive.google.com/drive/folders/12O2cU34RhlK5tQI1mi2K6_B3G2k5RMJt?usp=sharing]. This folder also hosts the full set of videos and high-resolution imagery that could not be uploaded directly due to GitHub's 25 MB file size restriction.

---
*For any questions regarding hardware integration or data structures, please consult the technical lab report located within the `report/` directory. Feel free to contact the team for further inquiries!*
