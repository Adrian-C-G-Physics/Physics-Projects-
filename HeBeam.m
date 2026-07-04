
function out = HeBeam(mode, pulse, tRequest, config, varargin)
%out = HeBeam('calc', 58121, 1179,'100_044_64','DataPath',¡Tu ruta de la carpeta con los datos shot!,'SaveCsv', true);%


% Transcrito de la versión original en Python. Hecho por: Adrián Cabero González 15-06-2026
%
% Modo de uso simple. Descargar los datos del array de señales de He, 16 señales x 3 líneas
% de emisión. Ejemplo de ficheros por shot: HE_667..., HE_706..., HE_728... y HELIO_HAZ-xxxxx.
% Guardar todas las señales del shot en una carpeta INDIVIDUAL.
%
% Llamar la función como:
%   out = hebeam_0(mode, pulse, tRequest, config, 'DataPath', rutaSenales)
%
%   mode      : 'calc' hace el cálculo completo
%               'ne' devuelve solo el perfil de densidad
%               'te' devuelve solo el de temperatura
%   pulse     : shot a analizar
%   config    : configuración magnética
%   tRequest  : tiempo aproximado en el que se dispara el haz de Helio
%
% Además de los plots, esta versión puede guardar un CSV con los puntos finales
% que sí se usan para el plot conjunto de salida (rhon, ne y te filtrados).
%
% OPCIONES ADICIONALES (Name-Value)
% ---------------------------------
%   'DataPath'        : carpeta donde están los TXT de señales descargados.
%   'TraceReader'     : lector externo compatible con la interfaz esperada.
%   'z0'              : si vale 0 se busca automáticamente en hebeam_z0.csv.
%   'PlotResults'     : si true y mode='calc', dibuja perfiles de ne y Te.
%   'PlotBeamPreview' : si true y mode='calc', dibuja HELIO_HAZ interpolado.
%   'SaveCsv'         : si true y mode='calc', guarda un CSV final con columnas:
%                       rhon, ne, te. Por defecto: true.
%   'CsvPath'         : carpeta donde guardar el CSV. Por defecto: DataPath.
%
% NOTA IMPORTANTE
% ---------------
% Los archivos auxiliares estáticos se buscan siempre junto al propio código:
%   - hebeam_rhon.json
%   - hebeam_z0.csv
%   - ratios.txt
%
% La ruta 'DataPath' solo se usa para encontrar los TXT de señales.

    %--------------------------------------------------------------
    % 0) Validación mínima de argumentos obligatorios.
    %--------------------------------------------------------------
    if nargin < 4
        error('hebeam:NotEnoughInputs', [ ...
            'Uso correcto: hebeam_0(''calc''|''ne''|''te'', pulse, tRequest, config, ...\n', ...
            '                     ''DataPath'', rutaSenales, ''TraceReader'', @miLector, ''z0'', valor)']);
    end

    if ~(ischar(mode) || isstring(mode))
        error('hebeam:BadModeType', 'mode debe ser char o string.');
    end
    if ~(isnumeric(pulse) && isscalar(pulse))
        error('hebeam:BadPulseType', 'pulse debe ser numérico escalar.');
    end
    if ~(isnumeric(tRequest) && isscalar(tRequest))
        error('hebeam:BadTimeType', 'tRequest debe ser numérico escalar.');
    end
    if ~(ischar(config) || isstring(config))
        error('hebeam:BadConfigType', 'config debe ser char o string.');
    end

    mode = lower(char(mode));
    config = char(config);

    %--------------------------------------------------------------
    % 1) Rutas y opciones por defecto.
    %--------------------------------------------------------------
    staticDataPath = fileparts(mfilename('fullpath'));
    signalDataPath = staticDataPath;
    csvPath = signalDataPath;

    traceReader = [];
    z0User = 0;
    plotResults = true;
    plotBeamPreview = true;
    saveCsv = true;

    %--------------------------------------------------------------
    % 2) Parseo manual de pares Name-Value.
    %--------------------------------------------------------------
    if mod(numel(varargin), 2) ~= 0
        error('hebeam:BadOptionalArgs', ...
            'Los argumentos opcionales deben ir en pares Name-Value.');
    end

    k = 1;
    while k <= numel(varargin)
        name = varargin{k};
        value = varargin{k+1};

        if ~(ischar(name) || isstring(name))
            error('hebeam:BadOptionName', ...
                'El nombre de cada opción debe ser texto.');
        end

        switch lower(char(name))
            case 'datapath'
                if ~(ischar(value) || isstring(value))
                    error('hebeam:BadDataPath', 'DataPath debe ser char o string.');
                end
                signalDataPath = char(value);
                csvPath = signalDataPath;

            case 'tracereader'
                if ~(isempty(value) || isa(value, 'function_handle'))
                    error('hebeam:BadTraceReader', ...
                        'TraceReader debe ser [] o un function handle.');
                end
                traceReader = value;

            case 'z0'
                if ~(isnumeric(value) && isscalar(value))
                    error('hebeam:BadZ0', 'z0 debe ser numérico escalar.');
                end
                z0User = value;

            case 'plotresults'
                if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                    error('hebeam:BadPlotResults', 'PlotResults debe ser lógico escalar.');
                end
                plotResults = logical(value);

            case 'plotbeampreview'
                if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                    error('hebeam:BadPlotBeamPreview', 'PlotBeamPreview debe ser lógico escalar.');
                end
                plotBeamPreview = logical(value);

            case 'savecsv'
                if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                    error('hebeam:BadSaveCsv', 'SaveCsv debe ser lógico escalar.');
                end
                saveCsv = logical(value);

            case 'csvpath'
                if ~(ischar(value) || isstring(value))
                    error('hebeam:BadCsvPath', 'CsvPath debe ser char o string.');
                end
                csvPath = char(value);

            otherwise
                error('hebeam:UnknownOption', ...
                    'Opción no reconocida: %s', char(name));
        end

        k = k + 2;
    end

    %--------------------------------------------------------------
    % 3) Si no se ofrece TraceReader, usar lector automático de TXT.
    %--------------------------------------------------------------
    if isempty(traceReader)
        traceReader = @(p, s) HeBeamSupport.readDownDataTrace(signalDataPath, p, s);
    end

    %--------------------------------------------------------------
    % 4) Estructura base equivalente a LocalDiag.
    %--------------------------------------------------------------
    diag = HeBeamSupport.makeLocalDiag();
    diag.z0 = z0User;
    diag.trueysigma = false;
    diag.color = 'C4';

    %--------------------------------------------------------------
    % 5) Lógica principal según el modo solicitado.
    %--------------------------------------------------------------
    switch mode
        case 'calc'
            if plotBeamPreview
                try
                    hebeamPlotBeamPreview(traceReader, pulse, tRequest);
                catch ME
                    warning('hebeam:BeamPreviewFailed', ...
                        'No se pudo generar el plot previo del haz: %s', ME.message);
                end
            end

            out = HeBeamSupport.calcHeBeam(pulse, tRequest, config, staticDataPath, traceReader, z0User);

            if ~isempty(out)
                if plotResults
                    hebeamPlotResults(out, pulse, tRequest, config);
                end
                if saveCsv
                    hebeamSaveCsv(out, pulse, csvPath);
                end
            end

        case 'ne'
            ret = HeBeamSupport.calcHeBeam(pulse, tRequest, config, staticDataPath, traceReader, z0User);
            if isempty(ret)
                out = [];
                return;
            end
            dataStruct = HeBeamSupport.packLocalData(ret.rhon, ret.ne, 0.005);
            if isempty(dataStruct)
                out = [];
                return;
            end
            diag.time = ret.time;
            diag.data = dataStruct;
            out = diag;

        case 'te'
            ret = HeBeamSupport.calcHeBeam(pulse, tRequest, config, staticDataPath, traceReader, z0User);
            if isempty(ret)
                out = [];
                return;
            end
            dataStruct = HeBeamSupport.packLocalData(ret.rhon, ret.te, 0.02);
            if isempty(dataStruct)
                out = [];
                return;
            end
            diag.time = ret.time;
            diag.data = dataStruct;
            out = diag;

        otherwise
            error('hebeam:InvalidMode', ...
                'Modo no reconocido. Use ''calc'', ''ne'' o ''te''.');
    end
end

function hebeamPlotBeamPreview(traceReader, pulse, tRequest)
    trBeam = traceReader(pulse, HeBeamSupport.BEAMNAME);
    trRef  = traceReader(pulse, HeBeamSupport.SIGNAL1{1});

    xBeam = trBeam.x(:);
    yBeam = trBeam.y(:);
    xRef  = trRef.x(:);

    if isempty(xBeam) || isempty(yBeam) || isempty(xRef)
        error('Señales vacías al intentar construir la previsualización del haz.');
    end

    beamInterp = interp1(xBeam, yBeam, xRef, 'linear', 'extrap');

    threshold = 4.0;
    active = (beamInterp >= threshold);
    idx = find(~active(1:end-1) & active(2:end));
    crossTimes = xRef(idx);

    figure('Name', 'HeBeam - Previsualización de HELIO_HAZ');
    plot(xRef, beamInterp, 'b-');
    hold on;
    grid on;
    xlabel('Tiempo');
    ylabel('HELIO_HAZ interpolado');
    title(sprintf('HELIO_HAZ | shot=%d | tRequest=%g', pulse, tRequest));

    yline(threshold, 'r--', 'Threshold = 4');
    xline(tRequest, 'k--', sprintf('tRequest = %g', tRequest));

    for i = 1:numel(crossTimes)
        xline(crossTimes(i), 'g--', sprintf('Cruce %d = %g', i, crossTimes(i)));
    end

    hold off;
end

function hebeamPlotResults(out, pulse, tRequest, config)
    if isempty(out) || ~isstruct(out)
        return;
    end

    maskNe = isfinite(out.ne) & isfinite(out.rhon) & (out.rhon < 1.4);

    figure('Name', 'HeBeam - Perfil de densidad electrónica');
    plot(out.rhon(maskNe), out.ne(maskNe), 'o-');
    grid on;
    xlabel('rhon');
    ylabel('ne');
    title(sprintf('HeBeam ne | shot=%d | tReq=%g | tSel=%g | cfg=%s', ...
        pulse, tRequest, out.time, config));

    maskTe = isfinite(out.te) & isfinite(out.rhon) & (out.rhon < 1.4);

    figure('Name', 'HeBeam - Perfil de temperatura electrónica');
    plot(out.rhon(maskTe), out.te(maskTe), 'o-');
    grid on;
    xlabel('rhon');
    ylabel('Te [keV]');
    title(sprintf('HeBeam Te | shot=%d | tReq=%g | tSel=%g | cfg=%s', ...
        pulse, tRequest, out.time, config));
end

function hebeamSaveCsv(out, pulse, csvPath)
% HEBEAMSAVECSV  Guarda un CSV con los puntos finales usados para comparar
% resultados: rhon, ne y te.
%
% El CSV solo incluye los puntos donde:
%   - rhon es finito
%   - ne es finito
%   - te es finito
%   - rhon < 1.4
%
% Cabecera generada con el formato:
%   rhon,ne-<shot>-<time>ms,te-<shot>-<time>ms
%
% Ejemplo:
%   rhon,ne-58121-1178.99ms,te-58121-1178.99ms

    if isempty(out) || ~isstruct(out)
        return;
    end

    if exist(csvPath, 'dir') ~= 7
        error('hebeam:CsvPathNotFound', ...
            'La carpeta de salida para CSV no existe: %s', csvPath);
    end

    % Usar la intersección de puntos válidos para que cada fila tenga rhon, ne y te.
    mask = isfinite(out.rhon) & isfinite(out.ne) & isfinite(out.te) & (out.rhon < 1.4);

    rhon = out.rhon(mask);
    ne   = out.ne(mask);
    te   = out.te(mask);

    if isempty(rhon)
        warning('hebeam:CsvNoValidPoints', ...
            'No hay puntos válidos comunes de rhon, ne y te para guardar en CSV.');
        return;
    end

    % Nombre del archivo.
    fileName = sprintf('hebeam_profile_%d_%.2fms.csv', pulse, out.time);
    fileName = strrep(fileName, ' ', '');
    fullName = fullfile(csvPath, fileName);

    % Cabecera con el formato pedido.
    header = sprintf('rhon,ne-%d-%.2fms,te-%d-%.2fms', pulse, out.time, pulse, out.time);

    fid = fopen(fullName, 'w');
    if fid == -1
        error('hebeam:CsvOpenFailed', ...
            'No se pudo abrir el archivo CSV para escritura: %s', fullName);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, '%s\n', header);
    for i = 1:numel(rhon)
        fprintf(fid, '%.15g,%.15g,%.15g\n', rhon(i), ne(i), te(i));
    end

    fprintf('CSV guardado: %s\n', fullName);
end
