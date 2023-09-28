REPRO = 0;

defineConstants;
addpath(DIRUTIL);

%---  ---%
% Eventually replace this with real stuff
lonin = [-179.75:0.5:179.75]';
latin = [-89.75:0.5:89.75]';

[LA, LO] = meshgrid(lat, lon);
[LAin, LOin] = meshgrid(latin, lonin);

datasets = {'basisregions', 'crop_states', 'EMAX', 'FBC', 'FHC', 'FTC', ...
    'FUELNEED', 'ORGC_sub', 'ORGC_top', 'POPDENS', 'SINK', 'SOILTEXT', ...
    'VEG'};
for ii = 1:length(datasets)
    dd = datasets{ii};

    fin  = [DIRCASA, '/monthly-0.5deg/maps/', dd, '.mat'];
    fout = [DIRCASA, '/', runname,  '/maps/', dd, '.mat'];

    if exist(fout,'file') && ~REPRO, continue; end

    load(fin);
    eval([dd, ' = transpose(interp2(LAin, LOin, transpose(', dd, ...
        '), LA, LO, "nearest"));']);
    save(fout, dd, '-v7');
end

datasets = {'FP', 'MORT', 'PF'};
for ii = 1:length(datasets)
    dd = datasets{ii};

    fin  = [DIRCASA, '/monthly-0.5deg/climate/', dd, '.mat'];
    fout = [DIRCASA, '/', runname,  '/climate/', dd, '.mat'];

    if exist(fout,'file') && ~REPRO, continue; end

    vvin = load(fin);
    eval([dd, ' = zeros(NLAT, NLON, 12);']);
    for nn = 1:12
        eval([dd, '(:,:,nn) = transpose(interp2(LAin, LOin, transpose(', ...
            'vvin.', dd, '(:,:,nn)), LA, LO, "nearest"));']);
    end
    save(fout, dd, '-v7');
end

%---  ---%
fout = [DIRCASA, '/', runname, '/maps/land_percent.mat'];
if ~exist(fout,'file') || REPRO
    land_percent = 0;
    for year = double(startYear):double(endYear)
        syear = num2str(year);
        % Read MODIS/VIIRS land cover
        fin = [DIRMODV, '/cover/modvir_cover.x', num2str(NLON), ...
            '_y', num2str(NLAT), '.yearly.', syear, '.nc'];
        pctin = ncread(fin, 'percent');
        land_percent = land_percent + flipud(sum(pctin(:,:,1:14), 3)');
    end
    land_percent = land_percent/(endYear - startYear + 1);

    save(fout, 'land_percent', '-v7');
end

%---  ---%
datasets = {'FPAR', 'BAdefo', 'BAherb', 'BAwood', 'AIRT', 'PPT', 'SOLRAD'};
for ii = 1:length(datasets)
    eval([datasets{ii}, 'mo = zeros(NLAT, NLON, 12);']);
end

for month = 1:12
    % Zero previous month's totals
    for ii = 1:length(datasets)
        ntot = 0;
        eval([datasets{ii}, 'tot = 0;']);
    end

    for year = double(startYear):double(endYear)
        tic;
        for dnum = datenum(year,month,01):datenum(year,month+1,01)-1
            loadDailyInput

            ntot = ntot + 1;
            for ii = 1:length(datasets)
                eval([datasets{ii}, 'tot = ', datasets{ii}, 'tot + ', datasets{ii}, ';']);
            end
        end
        disp([num2str(year), '/', num2str(month,'%02u'), ', time used = ', ...
            num2str(toc), ' seconds']);
    end

    for ii = 1:length(datasets)
        eval([datasets{ii}, 'mo(:,:,month) = ', datasets{ii}, 'tot/ntot;']);
    end
end

for ii = 1:length(datasets)
    dd = datasets{ii};

    % Check if file exists and skip if not reprocessing
    fout = [DIRCASA, '/', runname, '/climate/', dd, '.mat'];
    if exist(fout,'file') && ~REPRO, continue; end

    eval([dd, ' = ', dd, 'mo;']);
    eval(['clear ',  dd, 'mo;']);
    save(fout, dd, '-v7');
end
