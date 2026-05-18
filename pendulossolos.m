%% Leer CSV y dibujar Canal C frente a Canal B
clear; clc; close all;

%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 2, "Encoding", "UTF-8");

% Specify range and delimiter
opts.DataLines = [4, Inf];
opts.Delimiter = ";";

% Specify column names and types
opts.VariableNames = ["t", "U"];
opts.VariableTypes = ["double", "double"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, ["t", "U"], "TrimNonNumeric", true);
opts = setvaropts(opts, ["t", "U"], "ThousandsSeparator", ",");

% Import the data
Parte2Measurement20264179 = readtable("G:\Mi unidad\Física\UCLM\Tercero\Segundo cuatri\Física Experimental III\7-14\penduleo\frecuencia_caracteristicaIDere", opts);

%% Convert to output type
Parte2Measurement20264179 = table2array(Parte2Measurement20264179);

%% Clear temporary variables
clear opts


%% 4) Elegir ejes
x = Parte2Measurement20264179(:,1);
y = Parte2Measurement20264179(:,2);

%% 5) Eliminar valores no válidos
validos = isfinite(x) & isfinite(y);
x = x(validos);
y = y(validos);

%% 6) Ordenar por X
[x, idx] = sort(x);
y = y(idx);

%% 7) Suavizado por promedio móvil
ventana = 40;
y_suave = movmean(y, ventana);



%% 10) Dibujar
figure('Color','w');
plot(x, y, 'Color', [0.82 0.82 0.82], 'LineWidth', 0.8); hold on;
plot(x, y_suave, 'r', 'LineWidth', 1.5);


grid on;
box on;
ylabel('Voltaje (V)', 'FontSize', 12);
xlabel('Tiempo (ms)', 'FontSize', 12);
title('Voltaje frente a tiempo', 'FontSize', 13);

t = x/1000;              
U = y;

U = detrend(U);

dt = mean(diff(t));
Fs = 1/dt;
N = length(U);

% FFT
Y = fft(U);

% Usar ventana 
w = hann(N);
Y = fft(U .* w);

P2 = abs(Y/N);
P1 = P2(1:floor(N/2)+1);
P1(2:end-1) = 2*P1(2:end-1);

f = Fs*(0:floor(N/2))/N;

% Buscar pico 
[~, idx_max] = max(P1);

f0 = f(idx_max);
omega0 = 2*pi*f0;
I = (0.95 * 9.81 * 1.1) / (omega0^2);

fprintf('f0 = %.4f Hz\n', f0);
fprintf('omega0 = %.4f rad/s\n', omega0);
fprintf('I = %.4f kg/m^2\nZ', I);
