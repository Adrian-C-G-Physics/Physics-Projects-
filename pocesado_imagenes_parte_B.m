% =========================================================================
% PARTE 2: Banco Óptico 4f y Filtrado de Fourier en Tiempo Real
% =========================================================================

clear; close all; clc;

% 1. Inicialización de la cámara y la interfaz
try
cam = videoinput('winvideo', 1);

% Forzar que el espacio de color sea RGB.
cam.ReturnedColorSpace = 'rgb';
catch
    error('No se pudo conectar a la cámara. Revisa la conexión.');
end

% Crear figura y botón de parada
hFig = figure('Name', 'Banco Óptico 4f - Espacio de Fourier', 'Position', [100, 100, 1200, 450]);
stopButton = uicontrol('Style', 'togglebutton', 'String', 'DETENER', ...
                       'Position', [20, 20, 120, 40], 'FontSize', 12);

disp('Iniciando banco óptico... Pulsa el botón DETENER en la ventana para salir.');

% =========================================================================
% PARÁMETROS DEL FILTRO (¡Modifica esto para experimentar!)
% 1 = Paso-Bajo (Difumina/Desenfoque)
% 2 = Paso-Alto (Extrae bordes/Contornos)
% 3 = Rendija Vertical (Anisotropía)
tipo_filtro = 1; 

r0 = 40; % Radio de corte en píxeles (para filtros 1 y 2)
w  = 5; % Anchura de la rendija en píxeles (para filtro 3)
% =========================================================================

while stopButton.Value == 0
    % 2. Adquisición y preprocesado
    img_rgb = getsnapshot(cam);
    img_gray = double(rgb2gray(img_rgb)) / 255; % Normalizar entre 0 y 1
    [filas, columnas] = size(img_gray);
    
    % 3. Paso al dominio de frecuencias (Primer tramo del sistema 4f)
    F = fftshift(fft2(img_gray));
    Espectro_Visual = log(1 + abs(F)); % Escala logarítmica para poder verlo
    
    % 4. Construcción del sistema de coordenadas espaciales
    [X, Y] = meshgrid(1:columnas, 1:filas);
    X = X - (columnas/2); % Centramos X en 0
    Y = Y - (filas/2);    % Centramos Y en 0
    R2 = X.^2 + Y.^2;     % Distancia radial al cuadrado
    
    % 5. Creación de la Máscara H(u,v)
    if tipo_filtro == 1
        H = R2 <= r0^2;          % Círculo central de unos (Paso-Bajo)
        titulo_filtro = 'Paso-Bajo';
    elseif tipo_filtro == 2
        H = R2 > r0^2;           % Todo unos excepto el centro (Paso-Alto)
        titulo_filtro = 'Paso-Alto';
    elseif tipo_filtro == 3
        H = abs(X) < w;          % Franja vertical de unos (Rendija)
        titulo_filtro = 'Rendija Vertical';
    end
    
    % 6. Filtrado Espacial (Multiplicación en el plano de Fourier)
    G = F .* H;
    
    % 7. Reconstrucción de la imagen (Segundo tramo del sistema 4f)
    img_filtrada = abs(ifft2(ifftshift(G)));
    
    % 8. Visualización
    if ~ishandle(hFig)
        break; % Salir si el usuario cierra la ventana de golpe
    end
    
    subplot(1,3,1);
    imshow(img_gray);
    title('Objeto Original $f(x,y)$', 'Interpreter', 'latex', 'FontSize', 14);
    
    subplot(1,3,2);
    % Multiplicamos el espectro visual por la máscara para ver qué dejamos pasar
    imagesc(Espectro_Visual .* H); 
    colormap(gca, 'jet'); axis image off;
    title(['Espectro Filtrado: ', titulo_filtro], 'FontSize', 14);
    
    subplot(1,3,3);
    % Ajustamos el contraste dinámicamente según el filtro
    if tipo_filtro == 2
        imshow(img_filtrada, []); % Autocontraste para el paso-alto (muy oscuro)
    else
        imshow(img_filtrada);
    end
    title('Imagen Reconstruida $g(x,y)$', 'Interpreter', 'latex', 'FontSize', 14);
    
    drawnow;
end


% Limpieza al terminar
delete(cam);
clear cam;
disp('Cámara liberada. Bucle finalizado.');
