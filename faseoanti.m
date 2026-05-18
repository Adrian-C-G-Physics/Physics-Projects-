%% LIMPIEZA
clear; clc; close all;

%% 1) IMPORTAR DATOS
opts = delimitedTextImportOptions("NumVariables", 3, "Encoding", "UTF-8");

opts.DataLines = [4, Inf];
opts.Delimiter = ";";

opts.VariableNames = ["t", "U1", "U2"];
opts.VariableTypes = ["double", "double", "double"];

opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

opts = setvaropts(opts, ["t","U1","U2"], "TrimNonNumeric", true);
opts = setvaropts(opts, ["t","U1","U2"], "ThousandsSeparator", ",");

data = readtable("979925r2u4m.csv", opts);
A = table2array(data);

%% 2) EXTRAER VARIABLES
t  = A(:,1) / 1000;   % ms → s
y1 = A(:,2);          % péndulo 1
y2 = A(:,3);          % péndulo 2

%% 3) LIMPIEZA
validos = isfinite(t) & isfinite(y1) & isfinite(y2);
t = t(validos);
y1 = y1(validos);
y2 = y2(validos);

[t, idx] = sort(t);
y1 = y1(idx);
y2 = y2(idx);

%% 4) SUAVIZADO SUAVE
ventana = 5;
y1 = movmean(y1, ventana);
y2 = movmean(y2, ventana);



figure('Color','w');
plot(t, y1, 'b', 'LineWidth', 1.2); hold on;
plot(t, y2, 'r', 'LineWidth', 1.2);

grid on;
xlabel('Tiempo (s)');
ylabel('Voltaje (V)');
title('Oscilación de los dos péndulos');
legend('Péndulo 1', 'Péndulo 2');


corr_val = corr(y1, y2);

fprintf('Correlación = %.3f\n', corr_val);

if corr_val > 0
    fprintf('Modo: EN FASE\n');
else
    fprintf('Modo: ANTIFASE\n');
end



y = detrend(y1);   % usar un solo péndulo (más estable)


[pks, locs] = findpeaks(y, t, ...
    'MinPeakDistance', 0.5, ...
    'MinPeakProminence', 0.01);



periodos = diff(locs);

T = mean(periodos);
f0 = 1/T;
omega0 = 2*pi*f0;

% error estadístico
error_T = std(periodos) / sqrt(length(periodos));
error_omega = 2*pi * error_T / T^2;



fprintf('\n--- RESULTADOS ---\n');
fprintf('Periodo T = %.4f ± %.4f s\n', T, error_T);
fprintf('Frecuencia f = %.4f Hz\n', f0);
fprintf('Frecuencia angular ω = %.4f ± %.4f rad/s\n', omega0, error_omega);



figure('Color','w');
plot(t, y, 'k'); hold on;
plot(locs, pks, 'ro');

grid on;
xlabel('Tiempo (s)');
ylabel('Señal');
title('Detección de picos');
legend('Señal', 'Picos');
