% =============================================================================
% polarization_ellipse_analysis_200s.m
% Stokes Vectors Analysis and Parametric Polarization Ellipse Plotting Pipeline
% =============================================================================

clearvars;

% =============================================================================
% ── LEUZE DATA SOURCE CONFIGURATION (FILL IN FILE NAMES BEFORE RUNNING) ──────
% =============================================================================

% Enter the file path or filename for your main polarization metrics summary spreadsheet.
% Example: "200sdops_copy.xlsx"
POLARIZATION_DATA_FILE = "";

% Enter the file path or filename for your Stokes parameters spreadsheet.
% Example: "ell200s_copy.xlsx"
STOKES_DATA_FILE = "";

% =============================================================================
% ── DATA INGESTION & DECONVOLUTION ───────────────────────────────────────────
% =============================================================================

if isempty(POLARIZATION_DATA_FILE) || isempty(STOKES_DATA_FILE)
    error('File configurations are empty. Please define POLARIZATION_DATA_FILE and STOKES_DATA_FILE.');
end

% Load Degree of Polarization (DOP), DOLP, and DOCP matrices
s200 = readmatrix(POLARIZATION_DATA_FILE);

% Isolate Degree of Polarization (DOP) arrays per current threshold
ldop = s200(:,1); % Low current DOP
mdop = s200(:,2); % Nominal/Operating current DOP
hdop = s200(:,3); % High current DOP

% Isolate Degree of Linear Polarization (DOLP) arrays per current threshold
ldolp = s200(:,4); % Low current DOLP
mdolp = s200(:,5); % Nominal/Operating current DOLP
hdolp = s200(:,6); % High current DOLP

% Isolate Degree of Circular Polarization (DOCP) arrays per current threshold
ldocp = s200(:,7); % Low current DOCP
mdocp = s200(:,8); % Nominal/Operating current DOCP
hdocp = s200(:,9); % High current DOCP

% =============================================================================
% ── TIME-SERIES PARAMETRIC ANALYSIS ──────────────────────────────────────────
% =============================================================================

%% 1. Degree of Polarization (DOP) Stability Plot
figure;
plot(ldop, 'Color', '#3E1CC8', 'LineWidth', 1.5)
hold on
plot(mdop, 'Color', '#1CC83F', 'LineWidth', 1.5)
plot(hdop, 'Color', '#C83E1C', 'LineWidth', 1.5)
hold off
set(gca, 'FontSize', 12)
xlabel('Sample Index')
ylabel('DOP [%]')
title('Parametric DOP Profile Across Injection Currents')
legend('Low Current', 'Operating Current', 'High Current', 'Location', 'bestoutside')
grid on

%% 2. Degree of Linear Polarization (DOLP) Stability Plot
figure;
plot(ldolp, 'Color', '#3E1CC8', 'LineWidth', 1.5)
hold on
plot(mdolp, 'Color', '#1CC83F', 'LineWidth', 1.5)
plot(hdolp, 'Color', '#C83E1C', 'LineWidth', 1.5)
hold off
set(gca, 'FontSize', 12)
xlabel('Sample Index')
ylabel('DOLP [%]')
title('Parametric DOLP Profile Across Injection Currents')
legend('Low Current', 'Operating Current', 'High Current', 'Location', 'bestoutside')
grid on

%% 3. Degree of Circular Polarization (DOCP) Stability Plot
figure;
plot(ldocp, 'Color', '#3E1CC8', 'LineWidth', 1.5)
hold on
plot(mdocp, 'Color', '#1CC83F', 'LineWidth', 1.5)
plot(hdocp, 'Color', '#C83E1C', 'LineWidth', 1.5)
hold off
set(gca, 'FontSize', 12)
xlabel('Sample Index')
ylabel('DOCP [%]')
title('Parametric DOCP Profile Across Injection Currents')
legend('Low Current', 'Operating Current', 'High Current', 'Location', 'bestoutside')
grid on

% =============================================================================
% ── POLARIZATION ELLIPSE GENERATION PIPELINE ─────────────────────────────────
% =============================================================================

% Load Stokes parameters file for multi-current profile modeling
m200s = readmatrix(STOKES_DATA_FILE);
t = linspace(0, 2*pi, 1000);

% Pre-allocate coordinate tracking arrays for velocity optimization
davexl = zeros(size(m200s, 1), length(t));
daveyl = davexl;
davexm = davexl;
daveym = davexl;
davexh = davexl;
daveyh = davexl;

% Unpack low current Stokes vectors
s_0l = m200s(:,1);
s_1l = m200s(:,2);
s_2l = m200s(:,3);
s_3l = m200s(:,4);

% Unpack middle/nominal current Stokes vectors
s_0m = m200s(:,5);
s_1m = m200s(:,6);
s_2m = m200s(:,7);
s_3m = m200s(:,8);

% Unpack high current Stokes vectors
s_0h = m200s(:,9);
s_1h = m200s(:,10);
s_2h = m200s(:,11);
s_3h = m200s(:,12);

% Combine variables into stacked arrays for algorithmic processing loop
s0 = [s_0l, s_0m, s_0h];
s1 = [s_1l, s_1m, s_1h];
s2 = [s_2l, s_2m, s_2h];
s3 = [s_3l, s_3m, s_3h];

% Execute geometric transformation equations for ellipse orientations
for n = 1:3
    for i = 1:size(m200s, 1)
        chi = asin(s3(i,n) / s0(i,n)) / 2;
        psi = atan2(s2(i,n), s1(i,n)) / 2; % Optimized to atan2 for robust quadrant resolution

        a = abs(cos(chi));
        b = abs(sin(chi));
        x = a * cos(t);
        y = b * sin(t);
        
        % Rotate coordinate coordinates by the orientation angle (psi)
        x_r = x * cos(psi) - y * sin(psi);
        y_r = x * sin(psi) + y * cos(psi);
        
        if n == 1
            davexl(i,:) = x_r;
            daveyl(i,:) = y_r;
        elseif n == 2
            davexm(i,:) = x_r;
            daveym(i,:) = y_r;
        else
            davexh(i,:) = x_r;
            daveyh(i,:) = y_r;
        end
    end
end

% Compute spatial average trajectories across all sample profiles
meanlx = mean(davexl, 1);
meanly = mean(daveyl, 1);
meanmx = mean(davexm, 1);
meanmy = mean(daveym, 1);
meanhx = mean(davexh, 1);
meanhy = mean(daveyh, 1);

% =============================================================================
# ── HIGH-RESOLUTION ELLIPSE PLOTTING VISUALIZATIONS ──────────────────────────
% =============================================================================

%% 4. Low Current Ellipse Profile
figure;
for m = 1:size(m200s, 1)
    hold on
    h = plot(davexl(m,:), daveyl(m,:) * -1, 'Color', '#808080', 'LineWidth', 3);
    h.Color(4) = 0.2; % Transparent alpha value overlay
end
plot(meanlx, meanly * -1, 'Color', 'r', 'LineWidth', 4)
set(gca, 'FontSize', 12)
yline(0, 'k--', 'LineWidth', 1.5);
xline(0, 'k--', 'LineWidth', 1.5);
hold off
xlabel('x [a.u.]')
ylabel('y [a.u.]')
title('Polarization Ellipse Variations: Low Current')
legend('Polarization Ellipses', 'Average Polarization Ellipse', 'Location', 'best')
grid on
axis equal

%% 5. Middle / Nominal Current Ellipse Profile
figure;
for m = 1:size(m200s, 1)
    hold on
    h = plot(davexm(m,:), daveym(m,:) * -1, 'Color', '#808080', 'LineWidth', 3);
    h.Color(4) = 0.2; % Transparent alpha value overlay
end
plot(meanmx, meanmy * -1, 'Color', 'r', 'LineWidth', 4)
set(gca, 'FontSize', 12)
yline(0, 'k--', 'LineWidth', 1.5);
xline(0, 'k--', 'LineWidth', 1.5);
hold off
xlabel('x [a.u.]')
ylabel('y [a.u.]')
title('Polarization Ellipse Variations: Nominal Operating Current')
legend('Polarization Ellipses', 'Average Polarization Ellipse', 'Location', 'best')
grid on
axis equal

%% 6. High Current Ellipse Profile
figure;
for m = 1:size(m200s, 1)
    hold on
    h = plot(davexh(m,:), daveyh(m,:) * -1, 'Color', '#808080', 'LineWidth', 3);
    h.Color(4) = 0.2; % Transparent alpha value overlay
end
plot(meanhx, meanhy * -1, 'Color', 'r', 'LineWidth', 4)
set(gca, 'FontSize', 12)
yline(0, 'k--', 'LineWidth', 1.5);
xline(0, 'k--', 'LineWidth', 1.5);
hold off
xlabel('x [a.u.]')
ylabel('y [a.u.]')
title('Polarization Ellipse Variations: High Current')
legend('Polarization Ellipses', 'Average Polarization Ellipse', 'Location', 'best')
grid on
axis equal