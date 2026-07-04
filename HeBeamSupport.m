
classdef HeBeamSupport
    % HEBEAMSUPPORT  Clase de soporte para la conversión MATLAB del código HeBeam.
    %
    % Esta clase centraliza toda la funcionalidad auxiliar necesaria para que
    % el archivo principal hebeam.m funcione sin depender del ecosistema Python.
    %
    % Además del núcleo original, esta versión incorpora un lector de archivos TXT
    % exportados por DownData. Dicho lector permite trabajar con ficheros donde las
    % señales de una línea espectral vienen todas juntas en el mismo archivo, con
    % pares de columnas tiempo/señal del tipo:
    %   t-He_667_01-58120   He_667_01-58120   t-He_667_02-58120   He_667_02-58120 ...
    % No es necesario borrar la primeraparte del achivo .TXT donde se incluye información
    % adicional.

    properties (Constant)
        MAGN_NE = 0;
        MAGN_TE = 1;
        SIDE_BOTH = 0;
        SIDE_NEGATIVE = -1;
        SIDE_POSITIVE = 1;

        % Señales espectroscópicas usadas por el algoritmo original.
        SIGNAL1 = {'He_667_01','He_667_02','He_667_03','He_667_04', ...
                   'He_667_05','He_667_06','He_667_07','He_667_08', ...
                   'He_667_09','He_667_10','He_667_11','He_667_12', ...
                   'He_667_13','He_667_14','He_667_15','He_667_16'};
        SIGNAL2 = {'He_706_01','He_706_02','He_706_03','He_706_04', ...
                   'He_706_05','He_706_06','He_706_07','He_706_08', ...
                   'He_706_09','He_706_10','He_706_11','He_706_12', ...
                   'He_706_13','He_706_14','He_706_15','He_706_16'};
        SIGNAL3 = {'He_728_01','He_728_02','He_728_03','He_728_04', ...
                   'He_728_05','He_728_06','He_728_07','He_728_08', ...
                   'He_728_09','He_728_10','He_728_11','He_728_12', ...
                   'He_728_13','He_728_14','He_728_15','He_728_16'};

        % Nombre de la señal de referencia del beam.
        BEAMNAME = 'HELIO_HAZ';

        FLOW_KHZ = 20.0;
        N_CHANNELS = 16;
        CHANNEL_DISTANCE = 0.0035;

        FCAL_D1 = [-0.85, -0.93, -0.95, -0.91, -0.95, -1.00, -0.95, -1.00, ...
                   -0.95, -0.95, -0.93, -0.95, -1.00, -1.00, -1.00, -1.11];
        FCAL_D2 = [-0.71, -0.78, -0.81, -0.88, -0.95, -0.97, -1.07, -1.02, ...
                   -1.02, -1.03, -1.00, -1.02, -1.00, -1.00, -1.00, -1.09];
        FCAL_D3 = [-1.04, -0.93, -1.05, -1.05, -0.99, -0.99, -1.00, -1.00, ...
                   -1.01, -0.96, -0.97, -0.98, -1.00, -1.10, -1.11, -1.12];
    end

    methods (Static)
        function diag = makeLocalDiag()
            diag = struct();
            diag.factorysigma = 1;
            diag.factor = 1;
            diag.shift = 0;
            diag.time = [];
            diag.data = [];
            diag.isread = false;
            diag.side = HeBeamSupport.SIDE_BOTH;
            diag.xmin = 0;
            diag.xmax = 1;
            diag.z0 = 0;
            diag.trueysigma = false;
            diag.color = 'C4';
        end

        function s = makeLocalData(x, y, dy, channel)
            s = struct('x', x, 'y', y, 'dy', dy, 'channel', channel);
        end

        function arr = packLocalData(x, y, dy)
            mask = isfinite(y);
            idx = find(mask);
            if isempty(idx)
                arr = [];
                return;
            end
            arr(1, numel(idx)) = HeBeamSupport.makeLocalData(0, 0, dy, 1);
            for ii = 1:numel(idx)
                k = idx(ii);
                arr(ii) = HeBeamSupport.makeLocalData(double(x(k)), double(y(k)), double(dy), k);
            end
        end

        function out = calcHeBeam(pulse, tRequest, config, dataPath, traceReader, z0User)
            if pulse < 47380
                warning('HeBeamSupport:NoSuitableConfig', ...
                    'No suitable config for HeBeam pulse %d (pulse < 47380).', pulse);
                out = [];
                return;
            end

            [rhonMap, z0Table, ratios] = HeBeamSupport.loadStaticData(dataPath);

            cfgField = matlab.lang.makeValidName(config);
            if ~isfield(rhonMap, cfgField)
                warning('HeBeamSupport:UnknownConfig', ...
                    'Configuration %s not found in hebeam_rhon.json.', config);
                out = [];
                return;
            end

            if isempty(traceReader)
                error('HeBeamSupport:MissingTraceReader', ...
                    ['Debe proporcionar ''TraceReader'' como function handle ', ...
                     'equivalente a zaa.tj2das.readtrace o usar el lector TXT por defecto.']);
            end

            try
                [timevec, data1] = HeBeamSupport.readMany(traceReader, pulse, HeBeamSupport.SIGNAL1);
                [~,       data2] = HeBeamSupport.readMany(traceReader, pulse, HeBeamSupport.SIGNAL2);
                [~,       data3] = HeBeamSupport.readMany(traceReader, pulse, HeBeamSupport.SIGNAL3);
                [beamtime, beamM] = HeBeamSupport.readMany(traceReader, pulse, {HeBeamSupport.BEAMNAME});
            catch ME
                warning('HeBeamSupport:ReadError', ...
                    'Error reading He Beam pulse %d: %s', pulse, ME.message);
                out = [];
                return;
            end

            beam = interp1(beamtime(:), beamM(:,1), timevec(:), 'linear', 'extrap');

            calne = 1.77;
            calte = 0.5;

            Tcal   = reshape(ratios.Tcal,   200, 200);
            Ncal   = reshape(ratios.Ncal,   200, 200);
            Ratio1 = reshape(ratios.Ratio1, 200, 200);
            Ratio2 = reshape(ratios.Ratio2, 200, 200);

            data1 = data1 .* HeBeamSupport.FCAL_D1;
            data2 = data2 .* HeBeamSupport.FCAL_D2;
            data3 = data3 .* HeBeamSupport.FCAL_D3;

            fs = (numel(timevec) - 1) / (double(timevec(end)) - double(timevec(1)));
            [b, a] = HeBeamSupport.butterLowpass(HeBeamSupport.FLOW_KHZ, fs, 5);
            data1 = filter(b, a, data1);
            data2 = filter(b, a, data2);
            data3 = filter(b, a, data3);

            threshold = 4.0;
            active = (beam >= threshold);
            index = find(~active(1:end-1) & active(2:end));
            if isempty(index)
                out = [];
                return;
            end

            x1ini = 40;   x1fin = 60;
            x2ini = 340;  x2fin = 360;
            xsini = 50;   xsfin = 150;

            pulsestime = timevec(index);
            [~, j] = min(abs(pulsestime - tRequest));
            measuretime = pulsestime(j);
            indexj = index(j);

            iA = indexj + x2ini;
            iB = indexj + x2fin;
            if iB > size(data1,1)
                out = [];
                return;
            end
            meanf = [mean(data1(iA:iB,:),1); mean(data2(iA:iB,:),1); mean(data3(iA:iB,:),1)];

            iA = indexj + x1ini;
            iB = indexj + x1fin;
            if iB > size(data1,1)
                out = [];
                return;
            end
            meani = [mean(data1(iA:iB,:),1); mean(data2(iA:iB,:),1); mean(data3(iA:iB,:),1)];

            x1 = (x1ini + x1fin) / 2;
            x2 = (x2ini + x2fin) / 2;
            Bline = (meanf - meani) / (x2 - x1);
            Aline = meanf - Bline * (indexj + x2);
            indeces = (indexj : indexj + x2fin).';
            if indeces(end) > size(data1,1)
                out = [];
                return;
            end
            data1(indeces,:) = data1(indeces,:) - (Aline(1,:) + indeces * Bline(1,:));
            data2(indeces,:) = data2(indeces,:) - (Aline(2,:) + indeces * Bline(2,:));
            data3(indeces,:) = data3(indeces,:) - (Aline(3,:) + indeces * Bline(3,:));

            i1 = indexj + xsini;
            i2 = indexj + xsfin;
            if i2 > size(data1,1)
                out = [];
                return;
            end
            Sr = zeros(HeBeamSupport.N_CHANNELS, 3);
            Sr(:,1) = sum(data1(i1:i2,:), 1).';
            Sr(:,2) = sum(data2(i1:i2,:), 1).';
            Sr(:,3) = sum(data3(i1:i2,:), 1).';

            channels = (0:HeBeamSupport.N_CHANNELS-1).';
            V = [channels.^3, channels.^2, channels, ones(size(channels))];
            S = zeros(HeBeamSupport.N_CHANNELS, 3);
            for k = 1:3
                p = V \ Sr(:,k);
                S(:,k) = V * p;
            end

            ne = zeros(HeBeamSupport.N_CHANNELS, 1);
            Te = zeros(HeBeamSupport.N_CHANNELS, 1);
            for ch = 1:HeBeamSupport.N_CHANNELS
                epsilon1 = abs(Ratio1 - (S(ch,1) / S(ch,3)) * calne);
                epsilon2 = abs(Ratio2 - (S(ch,3) / S(ch,2)) * calte);
                epsilon = epsilon1 + epsilon2;
                [~, iRow] = min(min(epsilon, [], 2));
                [~, iCol] = min(min(epsilon, [], 1));
                ne(ch) = Ncal(iRow, iCol);
                Te(ch) = Tcal(iRow, iCol);
            end

            ne = ne / 1e13;
            ne(ne >= 1.99) = NaN;
            Te = Te / 1000;
            Te(Te <= 0.01) = NaN;

            if double(z0User) == 0
                valid = z0Table.pulse <= pulse;
                if ~any(valid)
                    error('HeBeamSupport:NoZ0', 'No se encontró ningún valor z0 válido para pulse=%d.', pulse);
                end
                z0 = z0Table.z0(find(valid, 1, 'last'));
                fprintf('Found HeBeam z0 for %d: %g\n', pulse, z0);
            else
                z0 = double(z0User);
            end

            info_rhon = rhonMap.(cfgField);
            info_rhon = info_rhon(:);
            z_min = info_rhon(1);
            z_max = info_rhon(2);
            n_points = floor((numel(info_rhon) - 2) / 2);
            knots = info_rhon(3 : 2 + n_points);
            coeff = info_rhon(3 + n_points : 2 + 2*n_points);
            degree = 3;

            z = z0 + (0:HeBeamSupport.N_CHANNELS-1).' * HeBeamSupport.CHANNEL_DISTANCE;
            rhon = 1.5 * ones(size(z));
            wh = (z >= z_min) & (z <= z_max);
            zsel = z(wh);
            if ~isempty(zsel)
                rhon(wh) = HeBeamSupport.evalBSplineVector(knots, coeff, degree, zsel);
            end

            out = struct('rhon', rhon, 'te', Te, 'ne', ne, 'time', measuretime);
        end

        function [time, data] = readMany(traceReader, pulse, signals)
            nSig = numel(signals);
            time = [];
            data = [];
            for i = 1:nSig
                tr = traceReader(pulse, signals{i});
                x = HeBeamSupport.getFieldOrProperty(tr, 'x');
                y = HeBeamSupport.getFieldOrProperty(tr, 'y');
                x = x(:);
                y = y(:);
                if isempty(time)
                    time = x;
                    data = zeros(numel(time), nSig);
                end
                if numel(x) ~= numel(time)
                    error('HeBeamSupport:TraceLengthMismatch', ...
                        'La señal %s tiene una longitud distinta de la primera.', signals{i});
                end
                data(:,i) = double(y);
            end
        end

        function tr = readDownDataTrace(dataPath, pulse, signalName)
            % READDOWNDATATRACE  Lector de una sola señal desde TXT DownData.
            %
            % Está diseñado para adaptarse al esquema actual del script, que pide
            % una señal individual cada vez. Internamente localiza qué archivo TXT
            % contiene la familia correcta (667, 706, 728 o HELIO_HAZ), extrae el
            % par de columnas tiempo/señal correspondiente y devuelve un struct con
            % campos x, y, n y label.

            signalName = char(signalName);
            pulseStr = num2str(pulse);

            filePath = HeBeamSupport.findDownDataFile(dataPath, signalName);
            parsed = HeBeamSupport.parseDownDataFile(filePath);

            timeHeaderExact = ['t-' signalName '-' pulseStr];
            dataHeaderExact = [signalName '-' pulseStr];

            headers = parsed.headers;
            timeIdx = find(strcmp(headers, timeHeaderExact), 1, 'first');
            dataIdx = find(strcmp(headers, dataHeaderExact), 1, 'first');

            % Si no existe coincidencia exacta con el pulso, intentar buscar por
            % nombre de señal ignorando el shot, para facilitar depuración.
            if isempty(timeIdx) || isempty(dataIdx)
                timePrefix = ['t-' signalName '-'];
                dataPrefix = [signalName '-'];
                timeCandidates = find(startsWith(headers, timePrefix));
                dataCandidates = find(startsWith(headers, dataPrefix) & ~startsWith(headers, ['t-' dataPrefix]));

                if numel(timeCandidates) == 1 && numel(dataCandidates) == 1
                    timeIdx = timeCandidates(1);
                    dataIdx = dataCandidates(1);
                    warning('HeBeamSupport:PulseHeaderFallback', ...
                        ['No se encontró cabecera exacta para el pulso %d y la señal %s. ', ...
                         'Se usará la única coincidencia disponible en el archivo.'], pulse, signalName);
                else
                    error('HeBeamSupport:SignalHeaderNotFound', ...
                        ['No se encontraron en el TXT las columnas esperadas para la señal %s ', ...
                         'y el pulso %d.'], signalName, pulse);
                end
            end

            if timeIdx > size(parsed.matrix, 2) || dataIdx > size(parsed.matrix, 2)
                error('HeBeamSupport:HeaderIndexOutOfRange', ...
                    'Los índices de columnas detectados exceden el ancho de la matriz leída.');
            end

            x = parsed.matrix(:, timeIdx);
            y = parsed.matrix(:, dataIdx);

            % Eliminar filas no finitas; esto es útil si el importador rellena con NaN.
            valid = isfinite(x) & isfinite(y);
            x = x(valid);
            y = y(valid);

            if isempty(x)
                error('HeBeamSupport:NoValidNumericData', ...
                    'La señal %s no contiene datos numéricos válidos tras el parseo.', signalName);
            end

            tr = struct();
            tr.x = x(:);
            tr.y = y(:);
            tr.n = numel(tr.x);
            tr.label = sprintf('%d - %s', pulse, signalName);
            tr.file = filePath;
        end

        function filePath = findDownDataFile(dataPath, signalName)
            % FINDDOWNDATAFILE  Localiza el TXT DownData adecuado para una señal.
            %
            % Criterio: buscar archivos .txt que contengan la marca "DownData" y la
            % familia de señal correspondiente. Esto evita confundirlos con ratios.txt,
            % hebeam.txt o HeBeamSupport.txt, que también pueden estar en la carpeta.

            familyTag = HeBeamSupport.signalFamilyTag(signalName);
            files = dir(fullfile(dataPath, '*.txt'));

            candidates = {};
            for k = 1:numel(files)
                fp = fullfile(dataPath, files(k).name);
                try
                    headTxt = HeBeamSupport.readFileHead(fp, 120);
                catch
                    continue;
                end

                if contains(headTxt, 'DownData') && contains(headTxt, familyTag)
                    candidates{end+1} = fp; %#ok<AGROW>
                end
            end

            if isempty(candidates)
                if strcmp(familyTag, HeBeamSupport.BEAMNAME)
                    error('HeBeamSupport:MissingBeamTXT', ...
                        ['No se ha encontrado ningún TXT DownData con la señal %s en la carpeta: %s\n', ...
                         'El cálculo completo necesita esta señal para detectar el pulso del haz.'], ...
                         HeBeamSupport.BEAMNAME, dataPath);
                else
                    error('HeBeamSupport:MissingSignalTXT', ...
                        ['No se ha encontrado ningún TXT DownData para la familia %s en la carpeta: %s'], ...
                        familyTag, dataPath);
                end
            end

            if numel(candidates) > 1
                % Preferir coincidencia por nombre de fichero si existe.
                hit = '';
                for k = 1:numel(candidates)
                    [~, nm, ext] = fileparts(candidates{k});
                    low = lower([nm ext]);
                    if contains(low, lower(strrep(familyTag, '_', ''))) || contains(low, lower(familyTag))
                        hit = candidates{k};
                        break;
                    end
                end
                if ~isempty(hit)
                    filePath = hit;
                else
                    filePath = candidates{1};
                    warning('HeBeamSupport:MultipleTXTMatches', ...
                        ['Se han encontrado varios TXT compatibles con la familia %s. ', ...
                         'Se usará el primero: %s'], familyTag, filePath);
                end
            else
                filePath = candidates{1};
            end
        end

        function parsed = parseDownDataFile(filePath)
            % PARSEDOWNDATAFILE  Parsea un TXT DownData y cachea el resultado.
            persistent cache
            if isempty(cache)
                cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
            if isKey(cache, filePath)
                parsed = cache(filePath);
                return;
            end

            raw = fileread(filePath);
            lines = regexp(raw, '\r\n|\n|\r', 'split');

            headerLineIdx = [];
            for i = 1:numel(lines)
                li = strtrim(lines{i});
                if startsWith(li, 't-') && contains(li, sprintf('\t'))
                    headerLineIdx = i;
                    break;
                end
                % Alternativa robusta si el tab ya se ha interpretado al leer el texto.
                if startsWith(li, 't-') && contains(lines{i}, char(9))
                    headerLineIdx = i;
                    break;
                end
            end

            if isempty(headerLineIdx)
                error('HeBeamSupport:DownDataHeaderNotFound', ...
                    'No se encontró la línea de cabeceras tiempo/señal en el archivo %s.', filePath);
            end

            headerLine = lines{headerLineIdx};
            % Separar por TAB real.
            headers = regexp(headerLine, '\t', 'split');
            if numel(headers) == 1
                headers = strsplit(headerLine, sprintf('\t'));
            end
            headers = cellfun(@strtrim, headers, 'UniformOutput', false);
            headers = headers(~cellfun('isempty', headers));

            % Leer bloque numérico justo después de la cabecera.
            M = readmatrix(filePath, ...
                'FileType', 'text', ...
                'Delimiter', '\t', ...
                'NumHeaderLines', headerLineIdx);

            if isempty(M)
                error('HeBeamSupport:DownDataNoNumericBlock', ...
                    'No se pudo leer el bloque numérico del archivo %s.', filePath);
            end

            % Ajuste conservador del número de columnas al mínimo común entre lo
            % leído numéricamente y el número de cabeceras identificadas.
            nCols = min(numel(headers), size(M,2));
            headers = headers(1:nCols);
            M = M(:,1:nCols);

            parsed = struct('file', filePath, 'headers', {headers}, 'matrix', M, ...
                            'headerLineIdx', headerLineIdx);
            cache(filePath) = parsed;
        end

        function tag = signalFamilyTag(signalName)
            % SIGNALFAMILYTAG  Determina en qué TXT debería estar una señal.
            signalName = char(signalName);
            if startsWith(signalName, 'He_667_')
                tag = 'He_667_';
            elseif startsWith(signalName, 'He_706_')
                tag = 'He_706_';
            elseif startsWith(signalName, 'He_728_')
                tag = 'He_728_';
            elseif strcmp(signalName, HeBeamSupport.BEAMNAME)
                tag = HeBeamSupport.BEAMNAME;
            else
                error('HeBeamSupport:UnknownSignalFamily', ...
                    'No se reconoce la familia de la señal %s.', signalName);
            end
        end

        function txt = readFileHead(filePath, maxLines)
            % READFILEHEAD  Lee las primeras maxLines líneas de un archivo de texto.
            fid = fopen(filePath, 'r');
            if fid == -1
                error('HeBeamSupport:CannotOpenFile', 'No se pudo abrir %s.', filePath);
            end
            cleaner = onCleanup(@() fclose(fid));

            lines = cell(maxLines, 1);
            n = 0;
            while ~feof(fid) && n < maxLines
                n = n + 1;
                lines{n} = fgetl(fid);
            end
            txt = strjoin(lines(1:n), newline);
        end

        function value = getFieldOrProperty(obj, name)
            if isstruct(obj)
                if ~isfield(obj, name)
                    error('HeBeamSupport:MissingField', ...
                        'El objeto devuelto por TraceReader no tiene el campo %s.', name);
                end
                value = obj.(name);
            else
                if ~isprop(obj, name)
                    error('HeBeamSupport:MissingProperty', ...
                        'El objeto devuelto por TraceReader no tiene la propiedad %s.', name);
                end
                value = obj.(name);
            end
        end

        function [b, a] = butterLowpass(cutoff, fs, order)
            if exist('butter', 'file') ~= 2
                error('HeBeamSupport:MissingButter', ...
                    ['No se encuentra la función butter. Instala Signal Processing ', ...
                     'Toolbox o reemplaza este método por un diseño IIR propio.']);
            end
            nyq = 0.5 * fs;
            normal_cutoff = cutoff / nyq;
            [b, a] = butter(order, normal_cutoff, 'low');
        end

        function [rhonMap, z0Table, ratios] = loadStaticData(dataPath)
            persistent cachePath cacheRhonMap cacheZ0Table cacheRatios
            if ~isempty(cachePath) && strcmp(cachePath, dataPath)
                rhonMap = cacheRhonMap;
                z0Table = cacheZ0Table;
                ratios = cacheRatios;
                return;
            end

            jsonFile = fullfile(dataPath, 'hebeam_rhon.json');
            txt = fileread(jsonFile);
            j = jsondecode(txt);
            rhonMap = struct();

            if isstring(j.columns)
                cols = cellstr(j.columns);
            elseif iscell(j.columns)
                cols = j.columns;
            else
                cols = cellstr(string(j.columns));
            end

            dataRaw = j.data;
            if isnumeric(dataRaw)
                for c = 1:numel(cols)
                    key = matlab.lang.makeValidName(cols{c});
                    rhonMap.(key) = double(dataRaw(:,c));
                end
            elseif iscell(dataRaw)
                nRows = size(dataRaw, 1);
                nCols = size(dataRaw, 2);
                if nCols ~= numel(cols)
                    error('HeBeamSupport:BadJSONShape', ...
                        'hebeam_rhon.json tiene un número de columnas inconsistente.');
                end
                M = zeros(nRows, nCols);
                for r = 1:nRows
                    for c = 1:nCols
                        M(r,c) = double(dataRaw{r,c});
                    end
                end
                for c = 1:nCols
                    key = matlab.lang.makeValidName(cols{c});
                    rhonMap.(key) = M(:,c);
                end
            else
                error('HeBeamSupport:BadJSONData', ...
                    'Formato no reconocido para j.data en hebeam_rhon.json.');
            end

            z0File = fullfile(dataPath, 'hebeam_z0.csv');
            Tz0 = readtable(z0File, 'VariableNamingRule', 'preserve');
            if width(Tz0) < 2
                error('HeBeamSupport:BadZ0File', ...
                    'hebeam_z0.csv debe contener al menos dos columnas.');
            end
            z0Table = table(double(Tz0{:,1}), double(Tz0{:,2}), ...
                'VariableNames', {'pulse','z0'});

            % Carga robusta de ratios.txt: permite una columna fantasma inicial o
            % una última columna leída como texto si el archivo tiene formato raro.
            ratioFile = fullfile(dataPath, 'ratios.txt');
            ratios = HeBeamSupport.readRatiosRobust(ratioFile);

            cachePath = dataPath;
            cacheRhonMap = rhonMap;
            cacheZ0Table = z0Table;
            cacheRatios = ratios;
        end

        function ratios = readRatiosRobust(ratioFile)
            % READRATIOSROBUST  Lectura tolerante de ratios.txt.
            T = readtable(ratioFile, ...
                'FileType', 'text', ...
                'Delimiter', {' ', '\t'}, ...
                'MultipleDelimsAsOne', true, ...
                'ReadVariableNames', false);

            % Caso correcto ideal: 4 columnas numéricas.
            if width(T) == 4
                T.Properties.VariableNames = {'Tcal', 'Ncal', 'Ratio1', 'Ratio2'};
                ratios = HeBeamSupport.forceAllTableColumnsToDouble(T);
                return;
            end

            % Caso habitual detectado en depuración:
            %   - una primera columna fantasma NaN
            %   - una última columna como cell/string
            if width(T) == 5
                A = T{:,1};
                if isnumeric(A) && all(isnan(A))
                    T(:,1) = [];
                    T.Properties.VariableNames = {'Tcal', 'Ncal', 'Ratio1', 'Ratio2'};
                    ratios = HeBeamSupport.forceAllTableColumnsToDouble(T);
                    return;
                end
            end

            error('HeBeamSupport:BadRatiosFile', ...
                'ratios.txt no se ha podido interpretar como 4 columnas numéricas válidas.');
        end

        function T = forceAllTableColumnsToDouble(T)
            % FORCEALLTABLECOLUMNSTODOUBLE  Convierte columnas de tabla a double.
            vars = T.Properties.VariableNames;
            for k = 1:numel(vars)
                v = T.(vars{k});
                if isnumeric(v)
                    T.(vars{k}) = double(v);
                elseif iscell(v) || isstring(v) || ischar(v)
                    T.(vars{k}) = str2double(string(v));
                else
                    error('HeBeamSupport:NonConvertibleRatiosColumn', ...
                        'La columna %s de ratios.txt no se puede convertir a double.', vars{k});
                end
                if any(isnan(T.(vars{k})))
                    warning('HeBeamSupport:RatiosColumnContainsNaN', ...
                        'La columna %s de ratios.txt contiene NaN tras la conversión.', vars{k});
                end
            end
        end

        function vals = evalBSplineVector(knots, coeff, degree, xq)
            vals = zeros(size(xq));
            for i = 1:numel(xq)
                vals(i) = HeBeamSupport.evalBSplineScalar(knots, coeff, degree, xq(i));
            end
        end

        function y = evalBSplineScalar(t, c, k, x)
            % EVALBSPLINESCALAR  Evaluación robusta de una B-spline escalar.
            %
            % Esta versión evita el esquema manual anterior basado en span + de Boor
            % que puede ser sensible a desajustes finos de indexado respecto al
            % formato tck que usa SciPy/splev en el código Python original.
            %
            % Estrategia:
            %   1) Se calcula el número efectivo de coeficientes a partir de t y k:
            %        nCoeffEff = numel(t) - k - 1
            %   2) Si el vector c trae coeficientes extra, se recorta a los primeros
            %      nCoeffEff. Esto mantiene compatibilidad con el formato observado en
            %      hebeam_rhon.json.
            %   3) Se evalúa la spline mediante las funciones base de Cox-de Boor.

            nCoeffEff = numel(t) - k - 1;

            if nCoeffEff <= 0
                error('HeBeamSupport:InvalidSpline', ...
                    'Spline inválida: numel(t) debe ser mayor que k+1.');
            end

            if numel(c) < nCoeffEff
                error('HeBeamSupport:InvalidSpline', ...
                    ['Spline inválida: el vector de coeficientes es demasiado corto. ', ...
                     'Se necesitan al menos %d coeficientes y solo hay %d.'], ...
                     nCoeffEff, numel(c));
            end

            % Si hay coeficientes extra, usar solo los efectivos.
            c = c(1:nCoeffEff);

            % Fuera del soporte básico, devolver 0.
            if x < t(1) || x > t(end)
                y = 0;
                return;
            end

            % Base de grado 0.
            N = zeros(nCoeffEff, k+1);
            for i = 1:nCoeffEff
                if (t(i) <= x && x < t(i+1)) || (x == t(end) && i == nCoeffEff)
                    N(i,1) = 1;
                end
            end

            % Recurrencia de Cox-de Boor.
            for p = 1:k
                for i = 1:nCoeffEff
                    left = 0;
                    right = 0;

                    denom1 = t(i+p) - t(i);
                    if denom1 ~= 0
                        left = ((x - t(i)) / denom1) * N(i,p);
                    end

                    if i+1 <= nCoeffEff
                        denom2 = t(i+p+1) - t(i+1);
                        if denom2 ~= 0
                            right = ((t(i+p+1) - x) / denom2) * N(i+1,p);
                        end
                    end

                    N(i,p+1) = left + right;
                end
            end

            % Combinar base y coeficientes.
            y = sum(c(:) .* N(:,k+1));
        end
    end
end
