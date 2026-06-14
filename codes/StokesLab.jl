# =============================================================================
# StokesLab.jl
# Stokes Polarimetry, 2D Gaussian Centroiding, and Spatial Trajectory Tracking Module
# =============================================================================

module StokesLab

using Images, FileIO, CairoMakie, LinearAlgebra, CSV, DataFrames, ColorTypes, Statistics, Optim

export plot_stokes_heatmap, videocool, averagepol

# ── Global Parameters (Configurable before running execution routines) ───────

const DEFAULT_CROP_SIZE     = (1325, 1373)  # (Height, Width) in pixels for region-of-interest crop
const DEFAULT_GRID_PTS      = 25            # Meshgrid evaluation points per axis
const DEFAULT_FRAMERATE     = 15            # Video export frame rate (FPS)
const DEFAULT_N_FRAMES      = 50            # Evaluation frames per 2π operational cycle
const DEFAULT_OMEGA         = 5.0           # Angular frequency coefficient for animations
const DEFAULT_ARROW_SCALE   = 0.7           # Length scale factor for 2D quiver arrows
const DEFAULT_ELLIPSE_SCALE = 50.0          # Multiplier factor for spatial ellipse and arrow sizing
const DEFAULT_ELLIPSE_PTS   = 100           # Coordinate points evaluated per polarization ellipse
const DEFAULT_COLORMAP      = :hot          # Primary intensity heatmap lookup profile
const DEFAULT_LINE_COLOR    = :lime         # Color vector assigned to polarization ellipses
const DEFAULT_LINEWIDTH     = 2             # Line thickness for trace renderings

# ── 2D Gaussian Fitting Centroid Engine (Two-Stage Optimization) ─────────────

"""
    _fit_gaussian_centroid(mat::Matrix{Float64}; patch_radius=400, downsample=6) -> (cy_fit, cx_fit)

Estimates the exact sub-pixel center coordinate of a laser beam profiling spot 
using a highly optimized two-stage 2D Gaussian regression model:

  1. **Coarse Seeding**: Downsamples the matrix by `downsample` using standard image interpolation, 
     then evaluates an intensity-squared weighted centroid within the reduced space to bypass full matrix scan costs.
  2. **Fine Optimization**: Extracts a localized region bounded by `patch_radius` around the coarse coordinate 
     and evaluates an explicit 2D Gaussian model using a Nelder-Mead simplex algorithm over the localized patch.

Provides sub-pixel accurate localization without needing fixed hard thresholds.
"""
function _fit_gaussian_centroid(mat::Matrix{Float64}; patch_radius=400, downsample=6)
    h, w = size(mat)

    # ── Stage 1: Coarse Seeding via Reduced Grid ─────────────────────────────
    small  = imresize(mat, (h ÷ downsample, w ÷ downsample))
    sh, sw = size(small)
    w2     = small .^ 2
    total  = sum(w2)
    cy0s   = sum(Float64(r) * w2[r,c] for r in 1:sh, c in 1:sw) / total
    cx0s   = sum(Float64(c) * w2[r,c] for r in 1:sh, c in 1:sw) / total
 
    # Scale coordinates back up to full raw image space dimensions
    cy0, cx0 = cy0s * downsample, cx0s * downsample

    # ── Stage 2: Fine 2D Gaussian Regression over Local Patch ────────────────
    r1 = clamp(round(Int, cy0) - patch_radius, 1, h)
    r2 = clamp(round(Int, cy0) + patch_radius, 1, h)
    c1 = clamp(round(Int, cx0) - patch_radius, 1, w)
    c2 = clamp(round(Int, cx0) + patch_radius, 1, w)
    patch = mat[r1:r2, c1:c2]
    ph, pw = size(patch)

    amplitude_init = maximum(patch) - minimum(patch)
    background_init = minimum(patch)
    sigma_init = patch_radius / 2.0
    
    # Pack parameter seeds: [Amplitude, Center_Y, Center_X, Sigma_Y, Sigma_X, Background]
    p0 = [amplitude_init, cy0 - r1 + 1, cx0 - c1 + 1, sigma_init, sigma_init, background_init]

    function cost(p)
        amplitude, cy, cx, sigmay, sigmax, background = p
        (amplitude < 0 || sigmay < 1.0 || sigmax < 1.0) && return Inf
        err = 0.0
        @inbounds for c in 1:pw, r in 1:ph
            pred = background + amplitude * exp(-0.5 * ((r - cy)^2 / sigmay^2 + (c - cx)^2 / sigmax^2))
            err += (patch[r,c] - pred)^2
        end
        return err
    end

    result = optimize(cost, p0, NelderMead(),
                      Optim.Options(iterations=1000, x_abstol=0.05, f_reltol=1e-7))
    cy_patch, cx_patch = result.minimizer[2], result.minimizer[3]

    # Map localized patch optimized values back to full global space coordinates
    cy_fit = cy_patch + r1 - 1
    cx_fit = cx_patch + c1 - 1

    # Fallback routine if regression calculation diverges beyond target bounds
    if cy_fit < 1 || cy_fit > h || cx_fit < 1 || cx_fit > w
        @warn "Gaussian regression model diverged. Falling back to weighted coarse center seed."
        return (cy0, cx0)
    end

    return (cy_fit, cx_fit)
end

# ── Image Loading, Alignment, and Centered Cropping Engine ────────────────────

"""
    _load_and_center_images(paths; crop_size) -> (img_mat, centroids)

Loads the primary tracking frames from raw disk paths, runs the sub-pixel 2D Gaussian 
regression model to align optical centers across sequential runs, and normalizes them into a unified crop matrix.
"""
function _load_and_center_images(
    paths::AbstractVector{<:AbstractString};
    crop_size = DEFAULT_CROP_SIZE
)
    n = length(paths)

    # 1. Ingest raw camera captures from disk
    println("Ingesting $(n) raw measurement frames...")
    raw_images = Vector{Matrix{Float64}}(undef, n)
    for k in 1:n
        raw_images[k] = Float64.(Gray.(load(paths[k])))
    end
    img_h, img_w = size(raw_images[1])

    # 2. Extract sub-pixel beam center profiles
    println("Running sub-pixel 2D Gaussian localization...")
    centroids = Vector{Tuple{Float64,Float64}}(undef, n)
    for k in 1:n
        centroids[k] = _fit_gaussian_centroid(raw_images[k])
        println("  Frame $(k)/$(n) → Axis Coordinates: (Y: $(round(centroids[k][1], digits=2)), X: $(round(centroids[k][2], digits=2)))")
    end

    # 3. Dynamic out-of-bounds anomaly filtering via Median Absolute Deviation (3x MAD)
    med_cy = median(c[1] for c in centroids)
    med_cx = median(c[2] for c in centroids)
    dists  = [sqrt((c[1] - med_cy)^2 + (c[2] - med_cx)^2) for c in centroids]
    mad    = median(dists)
    tol    = max(5.0, 3.0 * mad)
    outliers = findall(d -> d > tol, dists)
    if !isempty(outliers)
        @warn "System spatial variance alerts encountered for indexing instances: $(outliers) (Spatial deviation exceeded threshold limit of > $(round(tol, digits=1)) px)"
        for k in outliers
            println("  ⚠ Outlier Instance $(k): Tracked Centroid = $(round.(centroids[k], digits=1)), Net Shift Dev = $(round(dists[k], digits=1)) px")
        end
    end

    # 4. Automated region-of-interest sizing evaluation
    if crop_size === nothing
        half_h = minimum(min(c[1] - 1, img_h - c[1]) for c in centroids)
        half_w = minimum(min(c[2] - 1, img_w - c[2]) for c in centroids)
        half   = floor(Int, min(half_h, half_w))
        crop_size = (2half, 2half)
        println("Automated runtime crop configuration calculated: $(crop_size)")
    end
    ch, cw = crop_size

    # 5. Execute centered bounding extraction across frames
    img_mat = Array{Float64,3}(undef, ch, cw, n)
    for k in 1:n
        cy, cx = centroids[k]
        r0 = clamp(round(Int, cy) - ch ÷ 2, 1, img_h - ch + 1)
        c0 = clamp(round(Int, cx) - cw ÷ 2, 1, img_w - cw + 1)
        img_mat[:, :, k] = raw_images[k][r0:r0+ch-1, c0:c0+cw-1]
    end

    println("✓ Final Aligned Image Tensor Generated: Size dimensions = $(size(img_mat))")
    return img_mat, centroids
end

# ── Internal Mathematical Engine: Stokes Vectors and Jones Calculus ─────────

function _build_stokes(img_mat)
    S0 = img_mat[:,:,1] .+ img_mat[:,:,2] # Horizontal + Vertical Components
    S1 = img_mat[:,:,1] .- img_mat[:,:,2] # Horizontal - Vertical Components
    S2 = img_mat[:,:,3] .- img_mat[:,:,4] # Diagonal +45° - Diagonal -45° Components
    S3 = img_mat[:,:,5] .- img_mat[:,:,6] # Right Circular - Left Circular Components
    return S0, S1, S2, S3
end

function _build_jones(S0, S1, S2, S3, nx, ny)
    theta = 0.5 .* atan.(S2, S1)
    psi   = 0.5 .* asin.(clamp.(S3 ./ S0, -1, 1))
    Jones = [ComplexF64[] for _ in 1:nx, _ in 1:ny]
    for i in 1:nx, j in 1:ny
        Jones[i,j] = (1 / sqrt(1 + psi[i,j]^2)) .* [
            cos(theta[i,j]) + im * psi[i,j] * sin(theta[i,j]);
            sin(theta[i,j]) - im * psi[i,j] * cos(theta[i,j])
        ]
    end
    return Jones
end

function _jones_ellipse(J; nt=100)
    t = range(0, 2π, length=nt)
    E = [J .* cis(tt) for tt in t]
    return [real(e[1]) for e in E], [real(e[2]) for e in E]
end

function _prepare_data(
    paths::AbstractVector{<:AbstractString};
    crop_size     = DEFAULT_CROP_SIZE,
    grid_pts      = DEFAULT_GRID_PTS,
    ellipse_scale = DEFAULT_ELLIPSE_SCALE,
)
    img_mat, centroids = _load_and_center_images(paths; crop_size=crop_size)

    resx, resy = size(img_mat, 1), size(img_mat, 2)
    n = length(paths)

    windowx = round.(Int, range(1, stop=resx, length=grid_pts))
    windowy = round.(Int, range(1, stop=resy, length=grid_pts))

    img_matcut = zeros(length(windowx), length(windowy), n)
    for i in 1:n
        img_matcut[:,:,i] = img_mat[windowx, windowy, i]
    end

    S0, S1, S2, S3 = _build_stokes(img_matcut)
    Jones = _build_jones(S0, S1, S2, S3, length(windowx), length(windowy))

    max_idx = argmax(img_matcut[Int(round(length(windowy)/2)), Int(round(length(windowx)/2)), :])

    scale_factor = ellipse_scale .* img_matcut[:,:,max_idx]
    Stokes = zeros(length(windowx), length(windowy), 4)
    Stokes[:,:,1] = S0
    Stokes[:,:,2] = S1
    Stokes[:,:,3] = S2
    Stokes[:,:,4] = S3
    return img_mat, windowx, windowy, Jones, scale_factor, Stokes
end

# ── Exported Visualization and Reporting Functions ──────────────────────────

"""
    plot_stokes_heatmap(paths; kwargs...)

Generates a spatial visualization mapping an intensity heatmap overlaid with local 
polarization ellipses evaluated across the grid mesh.

# Positional Arguments
- `paths`: Vector containing exactly 6 strings pointing to the raw calibration frames in standard [H, V, D, A, R, L] order.
"""
function plot_stokes_heatmap(
    paths::AbstractVector{<:AbstractString};
    crop_size     = DEFAULT_CROP_SIZE,
    grid_pts      = DEFAULT_GRID_PTS,
    ellipse_scale = DEFAULT_ELLIPSE_SCALE,
    ellipse_pts   = DEFAULT_ELLIPSE_PTS,
    colormap      = DEFAULT_COLORMAP,
    line_color    = DEFAULT_LINE_COLOR,
    linewidth     = DEFAULT_LINEWIDTH,
    save_path     = nothing, # Leave blank or map string file route for direct disk savings
    DOP           = false,
    azimuth       = false          
)
    img_mat, windowx, windowy, Jones, scale_factor, Stokes =
        _prepare_data(paths; crop_size=crop_size, grid_pts=grid_pts, ellipse_scale=ellipse_scale)

    resx, resy = size(img_mat, 1), size(img_mat, 2)

    fig = Figure(size=(resx, resy))
    ax  = CairoMakie.Axis(fig[1,1], aspect=DataAspect())
    heatmap!(ax, img_mat[:,:,1], colormap=colormap)
    hidespines!(ax)
    hidedecorations!(ax)

    for j in eachindex(windowy), i in eachindex(windowx)
        ex, ey = _jones_ellipse(Jones[i,j]; nt=ellipse_pts)
        lines!(ax,
            windowx[i] .+ scale_factor[i,j] .* ex,
            windowy[j] .+ scale_factor[i,j] .* ey,
            color=line_color, linewidth=linewidth)
    end

    if DOP
        S0 = Stokes[:,:,1]
        S1 = Stokes[:,:,2]
        S2 = Stokes[:,:,3]
        S3 = Stokes[:,:,4]
        DOP_tensor = (sqrt.(S1.^2 + S2.^2 + S3.^2)) ./ (S0)
        heatmap!(ax, windowx[:], windowy[:], DOP_tensor; colormap=:YlGnBu, alpha=0.5)
        Colorbar(fig[1,2], colormap=:YlGnBu, ticklabelsize=30)
    end

    if azimuth
        S0 = Stokes[:,:,1]
        S1 = Stokes[:,:,2]
        S2 = Stokes[:,:,3]
        S3 = Stokes[:,:,4]
        azimuth_deg = atand.(S2, S1)
        hm = heatmap!(ax, windowx[:], windowy[:], azimuth_deg; colormap=:roma, alpha=0.5, colorrange=(-90,90))
        Colorbar(fig[1,2], hm, ticklabelsize=30, label="Polarization Angle (Azimuth)", labelsize=30)
    end

    # ── LEUZE IMAGE FILE STORAGE (CONFIGURED VIA RUNTIME STRING PATH) ──────────
    if save_path !== nothing
        # Example: save("C:/Leuze/Outputs/stokes_spatial_heatmap.png", fig)
        save(save_path, fig)
    end

    display(fig)
    return Stokes
end

"""
    videocool(paths; kwargs...)

Compiles an animated video tracking the polarization vector wave propagation over time.
"""
function videocool(
    paths::AbstractVector{<:AbstractString};
    title         = "stokes_polarization_trajectory.mp4",
    crop_size     = DEFAULT_CROP_SIZE,
    grid_pts      = DEFAULT_GRID_PTS,
    ellipse_scale = DEFAULT_ELLIPSE_SCALE,
    colormap      = DEFAULT_COLORMAP,
    arrow_color   = DEFAULT_LINE_COLOR,
    arrow_scale   = DEFAULT_ARROW_SCALE,
    omega         = DEFAULT_OMEGA,
    n_frames      = DEFAULT_N_FRAMES,
    framerate     = DEFAULT_FRAMERATE
)
    img_mat, windowx, windowy, Jones, scale_factor =
        _prepare_data(paths; crop_size=crop_size, grid_pts=grid_pts, ellipse_scale=ellipse_scale)

    resx, resy = size(img_mat, 1), size(img_mat, 2)
    xs = vec(windowx' .* ones(Int, length(windowy)))
    ys = vec(ones(Int, length(windowx))' .* windowy)

    fig = Figure(size=(resx, resy))
    ax  = CairoMakie.Axis(fig[1,1], aspect=DataAspect())
    heatmap!(ax, img_mat[:,:,1], colormap=colormap)
    hidespines!(ax)
    hidedecorations!(ax)

    u_obs = Observable(zeros(length(xs)))
    v_obs = Observable(zeros(length(xs)))

    arrows2d!(ax, xs, ys, u_obs, v_obs, color=arrow_color, lengthscale=arrow_scale)

    xlims!(ax, minimum(xs), maximum(xs))
    ylims!(ax, minimum(ys), maximum(ys))

    # ── LEUZE ANIMATED VIDEO RECORDING EXPORT SETUP ──────────────────────────
    # Example Title Path: "C:/Leuze/Outputs/stokes_propagation.mp4"
    record(fig, title, range(0, 2π, length=n_frames); framerate=framerate) do t
        Ex_t = real.(getindex.(Jones, 1) .* cis(omega * t))
        Ey_t = real.(getindex.(Jones, 2) .* cis(omega * t))
        u_obs[] = vec(2 .* scale_factor .* Ex_t)
        v_obs[] = vec(2 .* scale_factor .* Ey_t)
    end

    return nothing
end

"""
    averagepol(paths; kwargs...)

Computes space-averaged Stokes metrics across the full beam aperture profile to calculate unified global properties.
"""
function averagepol(
    paths::AbstractVector{<:AbstractString};
    crop_size     = DEFAULT_CROP_SIZE,
    grid_pts      = DEFAULT_GRID_PTS,
    ellipse_scale = DEFAULT_ELLIPSE_SCALE,
    ellipse_pts   = DEFAULT_ELLIPSE_PTS,
    colormap      = DEFAULT_COLORMAP,
    line_color    = DEFAULT_LINE_COLOR,
    linewidth     = DEFAULT_LINEWIDTH,
    save_path     = nothing
)
    img_mat, __, _, ___, ___, _____ =
        _prepare_data(paths; crop_size=crop_size, grid_pts=grid_pts, ellipse_scale=ellipse_scale)
    x, y = crop_size[1], crop_size[2]
    stokes_total = zeros(x, y, 4)
    stokes_total[:,:,1], stokes_total[:,:,2], stokes_total[:,:,3], stokes_total[:,:,4] = _build_stokes(img_mat)
    
    stokes_avg = zeros(4)
    [stokes_avg[i] = mean(stokes_total[:,:,1] .* stokes_total[:,:,i]) for i in 1:4]
    stokes_avg = stokes_avg ./ stokes_avg[1]
    
    fig = Figure()
    ax = CairoMakie.Axis(fig[1,1], limits=(-1,1,-1,1))
    Jones = _build_jones(stokes_avg[1], stokes_avg[2], stokes_avg[3], stokes_avg[4], 1, 1)
    
    ex, ey = _jones_ellipse(Jones[1]; nt=ellipse_pts)
    theta = atan(stokes_avg[3], stokes_avg[2])
    psi = asin(clamp(stokes_avg[4] / stokes_avg[1], -1, 1))
    
    lines!(ax, ex, ey, color=line_color, linewidth=linewidth)
    
    text!(1, 1, text="S0="*string(round(stokes_avg[1], digits=4))*", S1="*string(round(stokes_avg[2], digits=4))*", S2="*string(round(stokes_avg[3], digits=4))*", S3="*string(round(stokes_avg[4], digits=4)), word_wrap_width=20, align=(:right, :top))
    text!(1, -1, text="Ellipticity="*string(round(psi, digits=4))*", Azimuth="*string(round(theta, digits=4)), align=(:right, :bottom))
    
    if save_path !== nothing
        save(save_path, fig)
    end
    
    display(fig)
    
    fig = Figure()
    ax = CairoMakie.Axis(fig[1,1])
    heatmap!(ax, img_mat[:,:,1], colormap=colormap)
    hidespines!(ax)
    hidedecorations!(ax)
    display(fig)
end

end # module StokesLab