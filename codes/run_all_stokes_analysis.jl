# =============================================================================
# run_all_stokes_analysis.jl
# Batch Processing Driver Script for Stokes Vector Polarimetry Pipeline
# =============================================================================

include("StokesModule.jl")
using .StokesLab

# =============================================================================
# ── LEUZE LOCAL DIRECTORY CONFIGURATION (FILL IN BEFORE RUNNING) ─────────────
# =============================================================================

# Path to the input directory containing raw unedited polarimetry frame captures
# Example: INPUT_DIRECTORY = "C:/Leuze/Projects/Polarization/data/Stokes_Unedit"
INPUT_DIRECTORY = ""

# Paths to the output directories for saving generated data visualizations
# Set to an empty string "" to temporarily skip saving a specific file type
AVERAGE_POL_OUTPUT_DIR = ""
HEATMAP_OUTPUT_DIR     = ""
DOP_OUTPUT_DIR         = ""
VIDEO_OUTPUT_DIR       = ""

# =============================================================================
# ── BATCH PROCESSING UTILITY FUNCTIONS ───────────────────────────────────────
# =============================================================================

"""
    group_files(directory_path::String, group_size::Int=6) -> Vector{Vector{String}}

Reads all files from the specified directory, sorts them alphabetically, 
and partitions them into sequential groups of a fixed size (default is 6 frames 
per standard full Stokes parameter measurement cycle).
"""
function group_files(directory_path::String, group_size::Int=6)
    if isempty(directory_path)
        error("Input directory path is empty. Please configure INPUT_DIRECTORY before executing.")
    end
    
    files = sort(readdir(directory_path))
    paths = joinpath.(directory_path, files)

    return [paths[i:min(i + group_size - 1, end)]
            for i in 1:group_size:length(paths)]
end

"""
    find_indices_in_a(a, b) -> Vector{Int}

Constructs a fast lookup dictionary to find the corresponding indices 
of elements from collection `b` within collection `a`. Returns -1 for missing elements.
"""
function find_indices_in_a(a, b)
    lookup_dict = Dict(element => idx for (idx, element) in enumerate(a))
    return [get(lookup_dict, element, -1) for element in b]
end

# =============================================================================
# ── AUTOMATED BATCH RUN EXECUTION LOOP ───────────────────────────────────────
# =============================================================================

# Array listing the explicit serial/diode numbers under test
diodes = ["209", "208", "207", "205", "206", "204", "203", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "aux", "210"]

# Partition the unedited raw frames into separate measurement groups
file_groups = group_files(INPUT_DIRECTORY)

for (i, images) in enumerate(file_groups)
    # Array bounds check to prevent indices mismatch errors
    if i > length(diodes)
        @warn "More file groups found than defined diode ID tracking codes. Truncating loop sequence."
        break
    end
    
    current_diode = diodes[i]
    println("Processing telemetry analysis for Diode S/N: ", current_diode)

    # 1. Evaluate and export space-averaged Stokes polarization ellipses
    if !isempty(AVERAGE_POL_OUTPUT_DIR)
        avg_pol_path = joinpath(AVERAGE_POL_OUTPUT_DIR, "Diode_\$(current_diode).png")
        StokesLab.averagepol(images, save_path=avg_pol_path)
    end

    # 2. Evaluate and export full spatial Stokes grid intensity heatmaps
    if !isempty(HEATMAP_OUTPUT_DIR)
        heatmap_path = joinpath(HEATMAP_OUTPUT_DIR, "Polarization_Stokes_\$(current_diode).png")
        StokesLab.plot_stokes_heatmap(images, save_path=heatmap_path)
    end

    # 3. Evaluate and export Degree of Polarization (DOP) profile heatmaps
    if !isempty(DOP_OUTPUT_DIR)
        dop_path = joinpath(DOP_OUTPUT_DIR, "Jones_\$(current_diode).png")
        StokesLab.plot_stokes_heatmap(images, save_path=dop_path, DOP=true)
    end

    # 4. Compile and export animated polarization vector propagation videos
    if !isempty(VIDEO_OUTPUT_DIR)
        video_path = joinpath(VIDEO_OUTPUT_DIR, "Polarization_Stokes_\$(current_diode).mp4")
        StokesLab.videocool(images, title=video_path)
    end
end

println("✓ Automation sequence execution loop complete.")