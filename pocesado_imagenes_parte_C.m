% =========================================================================
% PARTE 3: Radiometría y Temperatura de Color (CCT)
% =========================================================================

clear; close all; clc;

% 1. Cargar la imagen (Asegúrate de haber ejecutado generador_blancos.m antes)
% Para este ejemplo, cargamos una imagen de prueba del workspace o archivo
% img_rgb = imread('foto_prueba.jpg'); 
% (Si usas el generador de blancos, asume que la variable se llama 'img_rgb')

% --- SIMULACIÓN RÁPIDA (Borrar si usas el generador_blancos real) ---
% img_rgb = uint8(cat(3, 255*ones(200,200), 200*ones(200,200), 150*ones(200,200))); 
% --------------------------------------------------------------------
img_rgb = imread("blanco_x.png");
% Asegurarse de que la imagen cargada no esté vacía
if isempty(img_rgb)
    error('La imagen no se ha cargado correctamente. Verifica el archivo.');
end

% Mostrar la imagen y pedir al usuario que seleccione un punto
figure('Name', 'Pirómetro Digital', 'Position', [200, 200, 600, 500]);
imshow(img_rgb);
title('Haz clic en la zona que deseas medir');
disp('Esperando a que selecciones un punto en la imagen...');

% ginput(1) recoge las coordenadas X e Y de un clic del ratón
[cx, cy] = ginput(1);
cx = round(cx);
cy = round(cy);

% 2. Extraer el ROI (Región de Interés) de 10x10 píxeles
% Tomamos 5 píxeles hacia cada lado del punto central
roi = img_rgb(cy-4:cy+5, cx-4:cx+5, :);

% Dibujar un rectángulo rojo en la imagen para mostrar dónde se midió
hold on;
rectangle('Position', [cx-5, cy-5, 10, 10], 'EdgeColor', 'r', 'LineWidth', 2);
hold off;

% 3. Cálculos Radiométricos
% Promediar los canales RGB en el ROI y normalizar de 0 a 1
mean_rgb = double(squeeze(mean(mean(roi))))' / 255; 

% Linealización (Deshacer la corrección Gamma)
rgb_lin = mean_rgb .^ 2.2;

% Matriz de conversión CIE 1931 (sRGB a XYZ)
M_RGB2XYZ = [0.4124, 0.3576, 0.1805; 
             0.2126, 0.7152, 0.0722; 
             0.0193, 0.1192, 0.9505];

% Multiplicación matricial para obtener XYZ
XYZ = (M_RGB2XYZ * rgb_lin')';

% 4. Coordenadas de Cromaticidad
suma_XYZ = sum(XYZ);
if suma_XYZ > 0
    x = XYZ(1) / suma_XYZ;
    y = XYZ(2) / suma_XYZ;
else
    x = 0; y = 0;
    disp('Error: Zona completamente negra, no se puede calcular CCT.');
end

% 5. Aproximación de McCamy para la Temperatura de Color (CCT)
n = (x - 0.3320) / (0.1858 - y);
CCT = 449*n^3 + 3525*n^2 + 6823.3*n + 5520.33;

% Mostrar resultados en consola y en el título de la imagen
fprintf('\n--- RESULTADOS DE LA MEDIDA ---\n');
fprintf('Valores RGB (normalizados): R=%.3f, G=%.3f, B=%.3f\n', mean_rgb(1), mean_rgb(2), mean_rgb(3));
fprintf('Coordenadas (x, y): x=%.3f, y=%.3f\n', x, y);
fprintf('Temperatura de Color (CCT): %.0f K\n', CCT);

title(sprintf('Temperatura de Color Estimada: %.0f K', CCT), 'FontSize', 14);