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

data = readtable("kfz024a8dep.csv", opts);
A = table2array(data);

%% 2) EXTRAER VARIABLES
t  = A(:,1) / 1000;   % ms a s
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
title('Latidos: ambos péndulos');
legend('Péndulo 1', 'Péndulo 2');



env1 = abs(hilbert(y1));
env2 = abs(hilbert(y2));

figure('Color','w');
plot(t, env1, 'b', 'LineWidth', 1.5); hold on;
plot(t, env2, 'r', 'LineWidth', 1.5);

grid on;
xlabel('Tiempo (s)');
ylabel('Amplitud');
title('Envolventes (latidos)');
legend('Péndulo 1', 'Péndulo 2');


y_fast = detrend(y1);

[pks_fast, locs_fast] = findpeaks(y_fast, t, ...
    'MinPeakDistance', 0.5, ...
    'MinPeakProminence', 0.01);

T_fast = mean(diff(locs_fast));
f_fast = 1/T_fast;
omega_plus = 2*pi*f_fast;

error_T_fast = std(diff(locs_fast))/sqrt(length(locs_fast));
error_omega_plus = 2*pi*error_T_fast / T_fast^2;



[pks_env, locs_env] = findpeaks(env1, t, ...
    'MinPeakDistance', 5);   

T_env = mean(diff(locs_env));
f_env = 1/T_env;
omega_minus = 2*pi*f_env;

error_T_env = std(diff(locs_env))/sqrt(length(locs_env));
error_omega_minus = 2*pi*error_T_env / T_env^2;



fprintf('\n==== RESULTADOS ====\n');

fprintf('\nFrecuencia rápida (ω+):\n');
fprintf('T = %.4f ± %.4f s\n', T_fast, error_T_fast);
fprintf('ω+ = %.4f ± %.4f rad/s\n', omega_plus, error_omega_plus);

fprintf('\nFrecuencia de latido (ω−):\n');
fprintf('T = %.4f ± %.4f s\n', T_env, error_T_env);
fprintf('ω− = %.4f ± %.4f rad/s\n', omega_minus, error_omega_minus);



figure('Color','w');
plot(t, y_fast, 'k'); hold on;
plot(locs_fast, pks_fast, 'ro');

title('Picos oscilación rápida (ω+)');
xlabel('Tiempo'); ylabel('Señal');

figure('Color','w');
plot(t, env1, 'b'); hold on;
plot(locs_env, pks_env, 'ro');

title('Picos de envolvente (ω−)');
xlabel('Tiempo'); ylabel('Amplitud');