% --- 1. CONFIGURACION Y CAPTURA DE OBJETOS ---
try
cam = videoinput('winvideo', 1);

% Forzar que el espacio de color sea RGB.
cam.ReturnedColorSpace = 'rgb';
catch
    error('No se pudo conectar a la cámara. Revisa la conexión.');
end



disp('Pon un texto u objeto ante la camara. Capturando en 3s...');
pause(3);
img_cam = double(rgb2gray(getsnapshot(cam))) / 255;
% clear cam; % Liberamos la camara

delete(cam);
clear cam;
disp('Cámara liberada.');


% Redimensionar para calculos rapidos en Fourier (potencia de 2)
N = 512;
Obj1 = imresize(img_cam, [N, N]);

% Crear Objeto 2: Texto virtual
Obj2 = zeros(N, N);
Obj2 = insertText(Obj2, [N/4, N/2], 'FISICA', 'FontSize', 60, 'BoxOpacity', 0, 'TextColor', 'white');
Obj2 = double(rgb2gray(Obj2));

% --- 2. PARAMETROS FISICOS (Unidades SI) ---
lambda = 633e-9;    % He-Ne laser (633 nm)
dpix = 5e-6;        % Tamano del pixel (5 micras)
L = N * dpix;       % Tamano del sensor

% Vector de frecuencias espaciales
df = 1 / L;
[u, v] = meshgrid(-N/2 : N/2-1, -N/2 : N/2-1);
u = u * df; v = v * df;

% --- 3. CREACION DEL HOLOGRAMA SINTETICO ---
z1 = 0.05;  % Objeto 1 (Camara) situado a 5 cm
z2 = 0.15;  % Objeto 2 (Texto) situado a 15 cm

% Propagadores (Simulando que la luz viaja desde el objeto al sensor)
H_z1 = exp(-1i * pi * lambda * z1 * (u.^2 + v.^2));
H_z2 = exp(-1i * pi * lambda * z2 * (u.^2 + v.^2));

% Propagacion de los objetos al plano del sensor (z=0)
Campo1 = ifft2(ifftshift( fftshift(fft2(Obj1)) .* H_z1 ));
Campo2 = ifft2(ifftshift( fftshift(fft2(Obj2)) .* H_z2 ));

% Holograma complejo total en el sensor
Holo = Campo1 + Campo2; 

% --- 4. BUCLE DE RECONSTRUCCION NUMERICA ---
hFig = figure('Name', 'Propagacion Numerica', 'Position', [100, 100, 1000, 500]);
disp('Propagando... Observa los planos de enfoque.');

% Barrido de distancia de reconstruccion desde 0 cm hasta 20 cm
z_vec = linspace(0, 0.20, 200); 

for i = 1:length(z_vec)
    if ~ishandle(hFig), break; end
    
    z_rec = z_vec(i);
    
    % Propagador inverso para reconstruir
    H_rec = exp(1i * pi * lambda * z_rec * (u.^2 + v.^2));
    
    % Reconstruccion del campo
    Campo_rec = ifft2(ifftshift( fftshift(fft2(Holo)) .* H_rec ));
    Intensidad = abs(Campo_rec).^2; % Lo que veria un ojo/camara
    
    % Visualizacion
    subplot(2,2,1); 
    imagesc(abs(Holo)); colormap gray; axis square off;
    title('Amplitud del Holograma (Sensor)');
    
    subplot(2,2,2);
    imagesc(Intensidad); colormap gray; axis square off;
    title(sprintf('Plano reconstruido a Z = %.1f cm', z_rec * 100));
    
    drawnow;
    pause(0.001); % Controlar la velocidad de la animacion  
end

    
% Propagador inverso para reconstruir
H_rec = exp(1i * pi * lambda * z_vec(51) * (u.^2 + v.^2));

% Reconstruccion del campo
Campo_rec = ifft2(ifftshift( fftshift(fft2(Holo)) .* H_rec ));
Intensidad = abs(Campo_rec).^2; % Lo que veria un ojo/camara

% Visualizacion
subplot(2,2,3);
imagesc(Intensidad); colormap gray; axis square off;
title(sprintf('Plano reconstruido a Z = %.1f cm', z_vec(51) * 100));

% Propagador inverso para reconstruir
H_rec = exp(1i * pi * lambda * z_vec(150) * (u.^2 + v.^2));

% Reconstruccion del campo
Campo_rec = ifft2(ifftshift( fftshift(fft2(Holo)) .* H_rec ));
Intensidad = abs(Campo_rec).^2; % Lo que veria un ojo/camara

% Visualizacion
subplot(2,2,4);
imagesc(Intensidad); colormap gray; axis square off;
title(sprintf('Plano reconstruido a Z = %.1f cm', z_vec(150) * 100));

carpeta = 'C:\Users\Laboratorio\Desktop\Práctica Procesado de Imagenes\códigos actualizados 20-04-26';
nombre = 'Martos.pdf';
ruta=fullfile(carpeta,nombre);
saveas(gcf, ruta)