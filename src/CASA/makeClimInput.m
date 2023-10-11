REPRO = 0;

defineConstants;
addpath(DIRUTIL);

%---  ---%
% Eventually replace this with real stuff
lonin = [-179.75:0.5:179.75]';
latin = [-89.75:0.5:89.75]';

[LA, LO] = meshgrid(lat, lon);
[LAin, LOin] = meshgrid(latin, lonin);

%%%
datasets = {'basisregions', 'EMAX', 'FBC', 'FHC', 'FTC', ...
    'FUELNEED', 'ORGC_sub', 'ORGC_top', 'POPDENS', 'SINK', 'SOILTEXT'};
for ii = 1:length(datasets)
    dname = datasets{ii};

    fin  = [DIRCASA, '/monthly-0.5deg/maps/', dname, '.mat'];
    fout = [DIRCASA, '/', runname,  '/maps/', dname, '.mat'];

    if exist(fout,'file') && ~REPRO, continue; end

    eval([dname, " = flipud(interp2(LAin, LOin, flipud(", dname, ...
        "'), LA, LO, 'nearest')');"]);
    save(fout, dname, '-v7');
end

%%%
datasets = {'FP', 'MORT', 'PF'};
for ii = 1:length(datasets)
    dname = datasets{ii};

    fin  = [DIRCASA, '/monthly-0.5deg/climate/', dname, '.mat'];
    fout = [DIRCASA, '/', runname,  '/climate/', dname, '.mat'];

    if exist(fout,'file') && ~REPRO, continue; end

    vars = load(fin);
    eval([dname, ' = zeros(NLAT, NLON, 12);']);
    for nn = 1:12
        % Probably missing two flipud's; does it matter?
        eval([dname, "(:,:,nn) = flipud(interp2(LAin, LOin, flipud(vars.", ...
            dname, "(:,:,nn)'), LA, LO, 'nearest')');"]);
    end
    save(fout, dname, '-v7');
end

%%%
dname = 'land_percent';
fout = [DIRCASA, '/', runname, '/maps/', dname, '.mat'];
if ~exist(fout,'file') || REPRO
    land_percent = 0;
    for year = double(startYear):double(endYear)
        syear = num2str(year);
        % Read MODIS/VIIRS land cover
        fin = [DIRMODV, '/cover/modvir_cover.x', num2str(NLON), ...
            '_y', num2str(NLAT), '.yearly.', syear, '.nc'];
        pctin = ncread(fin, 'percent');
        % Real specific about what indices are land here ***FORGIVE ME***
        land_percent = land_percent + flipud(sum(pctin(:,:,1:14), 3)');
    end
    land_percent = land_percent/(endYear - startYear + 1);

    save(fout, dname, '-v7');
end

%%% Needed for crop_states below
dname = 'VEG';
fout = [DIRCASA, '/', runname, '/maps/', dname, '.mat'];
VEG = zeros(NLAT, NLON);

syear = '2010';
% Read MODIS/VIIRS land cover
fin = [DIRMODV, '/cover/modvir_cover.x', num2str(NLON), ...
    '_y', num2str(NLAT), '.yearly.', syear, '.nc'];
lct = ncread(fin, 'mode');

%%% INPUT %%%
% 0     water
% 1     evergreen needleleaf forests
% 2     evergreen broadleaf forests
% 3     deciduous needleleaf forests
% 4     deciduous broadleaf forests
% 5     mixed forests
% 6     closed shrublands
% 7     open shrublands
% 8     woody savannas
% 9     savannas
% 10    grasslands
% 11    permanent wetlands
% 12    croplands
% 13    urban and built-up lands
% 14    cropland/natural vegetation mosaics
% 15    permanent snow and ice
% 16    barren
% 17    water bodies
% 18    unclassified

%%% OUTPUT %%%
% 0     water
% 1     evergreen needleleaf forests
% 2     evergreen broadleaf forests
% 3     deciduous needleleaf forests
% 4     deciduous broadleaf forests
% 5     mixed forests
% 6     shrublands
% 7     savanna and grassalnd
% 8     permanent wetlands
% 9     croplands
% 10    urban and built-up
% 11    barren or sparsely vegetated
% 12    permanent snow and ice 

VEG(flipud(lct' ==  1)) =  1;
VEG(flipud(lct' ==  2)) =  2;
VEG(flipud(lct' ==  3)) =  3;
VEG(flipud(lct' ==  4)) =  4;
VEG(flipud(lct' ==  5)) =  5;
VEG(flipud(lct' ==  6 | lct' ==  7)) = 6;
VEG(flipud(lct' ==  8 | lct' ==  9 | lct' == 10)) = 7;
VEG(flipud(lct' == 11)) =  8;
VEG(flipud(lct' == 12 | lct' == 14)) = 9;
VEG(flipud(lct' == 13)) = 10;
VEG(flipud(lct' == 15)) = 12;
VEG(flipud(lct' == 16)) = 11;

if ~exist(fout,'file') || REPRO
    save(fout, dname, '-v7');
end

dname = 'crop_states';
fout = [DIRCASA, '/', runname, '/maps/', dname, '.mat'];
if ~exist(fout,'file') || REPRO
    crop_states = zeros(NLAT, NLON);
    crop_states(VEG == 9) = 11;

    save(fout, dname, '-v7');
end

%%%
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
