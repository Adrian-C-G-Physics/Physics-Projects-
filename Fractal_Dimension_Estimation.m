% === SERIES EXPERIMENTALES ===
M1 = [1, 2, 4, 8, 16, 32, 64]';
D1 = [11.45 14.56 18.62 20.61 30.56 43.38 59.58]';

M2 = [1, 2, 4, 8, 16, 32, 64]';
D2 = [15.70 18.41 24.12 31.14 39.25 46.01 67.48]';

M3 = [1, 2, 4, 8, 16, 32, 64]';
D3 = [11.01 14.33 19.82 23.69 30.11 40.42 51.41]';

% === TRANSFORMACIÓN LOGARÍTMICA ===
logM1 = log(M1);  logD1 = log(D1);
logM2 = log(M2);  logD2 = log(D2);
logM3 = log(M3);  logD3 = log(D3);

% === AJUSTES LINEALES ===
mdl1 = fitlm(logM1, logD1);
mdl2 = fitlm(logM2, logD2);
mdl3 = fitlm(logM3, logD3);

% === RESULTADOS (pendiente, error, intercepto) ===
m1 = mdl1.Coefficients.Estimate(2);
dm1 = mdl1.Coefficients.SE(2);
n1 = mdl1.Coefficients.Estimate(1);

m2 = mdl2.Coefficients.Estimate(2);
dm2 = mdl2.Coefficients.SE(2);
n2 = mdl2.Coefficients.Estimate(1);

m3 = mdl3.Coefficients.Estimate(2);
dm3 = mdl3.Coefficients.SE(2);
n3 = mdl3.Coefficients.Estimate(1);

% === DIMENSIÓN FRACTAL ===
d1 = 1 / m1;
dd1 = (1 / m1^2) * dm1;

d2 = 1 / m2;
dd2 = (1 / m2^2) * dm2;

d3 = 1 / m3;
dd3 = (1 / m3^2) * dm3;

% === IMPRESIÓN DE RESULTADOS ===
fprintf("Serie 1: d = %.3f  +/- %.3f   K = %.3f\n", d1, dd1, exp(n1));
fprintf("Serie 2: d = %.3f  +/- %.3f   K = %.3f\n", d2, dd2, exp(n2));
fprintf("Serie 3: d = %.3f  +/- %.3f   K = %.3f\n", d3, dd3, exp(n3));

% === PLOT DEL AJUSTE (superpuestos) ===
figure(1);
hold on;

plot(logM1, logD1, 'or', "DisplayName","Serie 1");
plot(logM2, logD2, 'sb', "DisplayName","Serie 2");
plot(logM3, logD3, 'dg', "DisplayName","Serie 3");

plot(mdl1);   % línea roja
plot(mdl2);   % línea azul
plot(mdl3);   % línea verde

xlabel('ln(Masa)');
ylabel('ln(Diámetro)');
title('Ajuste Fractal de las Tres Series Experimentales');
legend;

% === ANÁLISIS DE RESIDUOS (opcional) ===
figure(2);
subplot(3,1,1)
plotResiduals(mdl1,'fitted'); title('Residuos Serie 1');

subplot(3,1,2)
plotResiduals(mdl2,'fitted'); title('Residuos Serie 2');

subplot(3,1,3)
plotResiduals(mdl3,'fitted'); title('Residuos Serie 3');