% =========================================================
%  White Light Spectra — 3000 K to 6000 K
%  One full-screen solid-colour figure per temperature,
%  designed for camera colour-temperature measurement.
%
%  Usage:
%    Run the script. Each figure fills the screen with the
%    computed sRGB colour for that CCT. Point your camera
%    at the screen, set exposure manually, and read the
%    colour temperature from the camera's white-balance
%    meter or via a colorimeter / RAW histogram.
%
%  Tip: disable f.lux / Night Shift / True Tone before
%  measuring — they shift the display's white point.
% =========================================================

clear; clc; close all;

% --- Constants ---
h  = 6.626e-34;   % Planck constant  [J·s]
c  = 2.998e8;     % Speed of light   [m/s]
kB = 1.381e-23;   % Boltzmann        [J/K]

% --- Wavelength range (visible: 380–780 nm) ---
lambda_nm = (380:1:780)';
lambda_m  = lambda_nm * 1e-9;

% --- Color temperatures ---
temperatures = 3000:500:6000;   % [K]
nT = numel(temperatures);

% --- CIE 1931 2° CMFs (analytic Gaussian approximation) ---
cmf_x = xbar_fn(lambda_nm);
cmf_y = ybar_fn(lambda_nm);
cmf_z = zbar_fn(lambda_nm);

% --- XYZ → linear sRGB matrix (D65) ---
M_xyz2rgb = [ 3.2406  -1.5372  -0.4986;
             -0.9689   1.8758   0.0415;
              0.0557  -0.2040   1.0570];

% --- Planck spectral radiance ---
planck = @(lam, T) (2*h*c^2) ./ (lam.^5) ./ (exp(h*c./(lam*kB*T)) - 1);

% =========================================================
%  Pre-compute sRGB for all temperatures
% =========================================================
rgb_values = zeros(nT, 3);

for i = 1:nT
    T = temperatures(i);
    B      = planck(lambda_m, T);
    B_norm = B / max(B);

    X = trapz(lambda_nm, B_norm .* cmf_x);
    Y = trapz(lambda_nm, B_norm .* cmf_y);
    Z = trapz(lambda_nm, B_norm .* cmf_z);

    rgb_lin = M_xyz2rgb * [X; Y; Z];
    rgb_lin = max(rgb_lin, 0);
    rgb_lin = rgb_lin / max(rgb_lin);           % normalise luminance

    rgb_gamma = min(rgb_lin .^ (1/2.2), 1);    % sRGB gamma
    rgb_values(i,:) = rgb_gamma';
end

% =========================================================
%  Console summary
% =========================================================
fprintf('\n%-10s  %-8s  %-8s  %-8s  %-7s  %-7s  %-7s  %s\n', ...
        'Temp (K)', 'R', 'G', 'B', 'R(255)', 'G(255)', 'B(255)', 'Description');
fprintf('%s\n', repmat('-', 1, 78));
for i = 1:nT
    r = rgb_values(i,1); g = rgb_values(i,2); b = rgb_values(i,3);
    fprintf('%-10d  %-8.4f  %-8.4f  %-8.4f  %-7d  %-7d  %-7d  %s\n', ...
        temperatures(i), r, g, b, ...
        round(r*255), round(g*255), round(b*255), ...
        cct_name(temperatures(i)));
end
fprintf('\n');

% =========================================================
%  One full-screen figure per temperature
% =========================================================
screen = get(0, 'ScreenSize');   % [left bottom width height]
sw = screen(3);
sh = screen(4);

for i = 1:nT
    T   = temperatures(i);
    rgb = rgb_values(i,:);
    lum = 0.299*rgb(1) + 0.587*rgb(2) + 0.114*rgb(3);

    % Label colour that contrasts with background
    if lum > 0.45
        txt_col  = [0.05 0.05 0.05];
        info_col = [0.20 0.20 0.20];
    else
        txt_col  = [0.95 0.95 0.95];
        info_col = [0.75 0.75 0.75];
    end

    % ---- Create figure ----
    fig = figure( ...
        'Name',        sprintf('%d K  —  %s', T, cct_name(T)), ...
        'NumberTitle', 'off', ...
        'Color',       rgb, ...
        'MenuBar',     'none', ...
        'ToolBar',     'none', ...
        'Position',    [0, 0, sw, sh], ...
        'WindowState', 'maximized');

    % Full-window invisible axes
    ax = axes('Parent',   fig, ...
              'Position', [0 0 1 1], ...
              'Color',    rgb, ...
              'XColor',   'none', ...
              'YColor',   'none', ...
              'XLim',     [0 1], ...
              'YLim',     [0 1]);
    hold(ax, 'on');

    % ---- Temperature label (large, centred) ----
    text(0.5, 0.56, sprintf('%d K', T), ...
         'Parent',              ax, ...
         'HorizontalAlignment', 'center', ...
         'VerticalAlignment',   'middle', ...
         'FontSize',            96, ...
         'FontWeight',          'bold', ...
         'Color',               txt_col);

    % ---- Description ----
    text(0.5, 0.42, cct_name(T), ...
         'Parent',              ax, ...
         'HorizontalAlignment', 'center', ...
         'VerticalAlignment',   'middle', ...
         'FontSize',            26, ...
         'Color',               info_col);

    % ---- sRGB values and hex code ----
    hex_str = sprintf('#%02X%02X%02X', ...
        round(rgb(1)*255), round(rgb(2)*255), round(rgb(3)*255));
    rgb_str = sprintf('sRGB  %d  %d  %d    %s', ...
        round(rgb(1)*255), round(rgb(2)*255), round(rgb(3)*255), hex_str);

    text(0.5, 0.20, rgb_str, ...
         'Parent',              ax, ...
         'HorizontalAlignment', 'center', ...
         'VerticalAlignment',   'middle', ...
         'FontSize',            15, ...
         'FontName',            'Courier New', ...
         'Color',               info_col);

    % ---- Progress indicator ----
    text(0.97, 0.03, sprintf('%d / %d', i, nT), ...
         'Parent',              ax, ...
         'HorizontalAlignment', 'right', ...
         'VerticalAlignment',   'bottom', ...
         'FontSize',            12, ...
         'Color',               info_col);

    drawnow;
end

fprintf('All %d colour-temperature figures are open.\n', nT);

% =========================================================
%  HELPER FUNCTIONS
% =========================================================

function y = gauss(x, mu, sig1, sig2)
    y = zeros(size(x));
    lo = x < mu;
    y( lo) = exp(-0.5*((x( lo)-mu)/sig1).^2);
    y(~lo) = exp(-0.5*((x(~lo)-mu)/sig2).^2);
end

function v = xbar_fn(l)
    v = 1.056*gauss(l,599.8,37.9,31.0) ...
      + 0.362*gauss(l,442.0,16.0,26.7) ...
      - 0.065*gauss(l,501.1,20.4,26.2);
end

function v = ybar_fn(l)
    v = 0.821*gauss(l,568.8,46.9,40.5) ...
      + 0.286*gauss(l,530.9,16.3,31.1);
end

function v = zbar_fn(l)
    v = 1.217*gauss(l,437.0,11.8,36.0) ...
      + 0.681*gauss(l,459.0,26.0,13.8);
end

function name = cct_name(T)
    if     T <= 3000, name = 'Warm white — candle / halogen';
    elseif T <= 3500, name = 'Warm white — tungsten lamp';
    elseif T <= 4000, name = 'Warm neutral white';
    elseif T <= 4500, name = 'Neutral white';
    elseif T <= 5000, name = 'Cool white';
    elseif T <= 5500, name = 'Bright cool white';
    else,             name = 'Daylight (D65 approx.)';
    end
end