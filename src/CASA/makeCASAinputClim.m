REPRO = 1;

defineConstants;

casares = ['x', num2str(NLON),   '_y', num2str(NLAT)];
mvres   = ['x', num2str(NLONMV), '_y', num2str(NLATMV)];

% Make sure directories exist
dout = [DIRCASA, '/', runname,  '/maps'];
if ~isfolder(dout)
    [status, result] = system(['mkdir -p ', dout]);
end

dout = [DIRCASA, '/', runname,  '/climate'];
if ~isfolder(dout)
    [status, result] = system(['mkdir -p ', dout]);
end

%---  ---%
% Eventually replace this with real stuff (***FIXME***)
lonxx = [-180.25:0.5:180.25]';
latxx = [-90.25:0.5:90.25]';

[LA,   LO]   = meshgrid(lat,   lon);
[LAxx, LOxx] = meshgrid(latxx, lonxx);

%%% Annual climatologies (interpolation, lazy)
%datasets = {'basisregions', 'FUELNEED'};
%interpms = {'nearest', 'linear'};
datasets = {'basisregions', 'FUELNEED', 'SOILTEXT'};
interpms = {'nearest', 'linear', 'nearest'};
for ii = 1:length(datasets)
    dname = datasets{ii};

    fin  = [DIRCASA, '/original-0.5deg/maps/', dname, '.mat'];
    fout = [DIRCASA, '/', runname,   '/maps/', dname, '.mat'];

    if isfile(fout) && ~REPRO, continue; end

    AA = load(fin).(dname);
    AA = [AA(:,1), AA, AA(:,end)];
    AA = [AA(1,:); AA; AA(end,:)];

    % Hack for soil texture
    % Should be an issue for basisregions, but ignoring for now
    if strcmp(dname, 'SOILTEXT')
        AA(AA == 0) = 2;
    end

    BB = flipud(interp2(LAxx, LOxx, flipud(AA'), LA, LO, interpms{ii}))';

    eval([dname, ' = BB;']);
    save(fout, dname, '-v7');
    clear AA BB;
end

%%% Monthly climatologies (interpolation, lazy)
datasets = {'FP', 'MORT'};
interpms = {'linear', 'linear'};
for ii = 1:length(datasets)
    dname = datasets{ii};
    fout  = [DIRCASA, '/',  runname,  '/climate/', dname, '.mat'];

    if isfile(fout) && ~REPRO, continue; end

    % Create climatology
    AAmo = 0;
    for year = startYearClim:endYearClim
        fin  = [DIRCASA, '/original-0.5deg/annual/', num2str(year), ...
            '/', dname, '.mat'];
        AAmo = AAmo + load(fin).(dname);
    end
    AAmo = AAmo/(endYearClim - startYearClim + 1);

    eval([dname, ' = zeros(NLAT, NLON, 12);']);
    for nm = 1:12
        AA = AAmo(:,:,nm);
        AA = [AA(:,1), AA, AA(:,end)];
        AA = [AA(1,:); AA; AA(end,:)];

        BB = flipud(interp2(LAxx, LOxx, flipud(AA'), LA, LO, interpms{ii}))';

        eval([dname, '(:,:,nm) = BB;']);
    end

    save(fout, dname, '-v7');
    clear AAmo AA BB;
end

%%% Peat fraction
dname = 'PF';
fout = [DIRCASA, '/', runname, '/climate/', dname, '.mat'];
if ~isfile(fout) || REPRO
    PF = zeros(NLAT, NLON, 12);
    % Notice transposition of CASA resolution ***FIXME?***
    [AA, RR] = readgeoraster([DIRAUX, '/CIFOR/TROP-SUBTROP_PeatV21_', ...
        '2016_CIFOR.x', num2str(NLAT), '_y', num2str(NLON), '.tif']);

    for nn = 1:12
        PF(:,:,nn) = AA;
    end

    save(fout, dname, '-v7');
end

%%% Population density
dname = 'POPDENS';
fout = [DIRCASA, '/', runname, '/maps/', dname, '.mat'];
if ~isfile(fout) || REPRO
    POPDENS = zeros(NLAT, NLON);

    % Add actual appropriate year weights ***FIXME***
    [AA, RR] = readgeoraster([DIRAUX, '/SEDAC/gpw_v4_population_density_', ...
        'adjusted_to_2015_unwpp_country_totals_rev11_2005_', casares, '.tif']);
    POPDENS = POPDENS + 0.5*1e-6*AA;
    [AA, RR] = readgeoraster([DIRAUX, '/SEDAC/gpw_v4_population_density_', ...
        'adjusted_to_2015_unwpp_country_totals_rev11_2010_', casares, '.tif']);
    POPDENS = POPDENS + 0.5*1e-6*AA;

    save(fout, dname, '-v7');
end

%%% Fractional land cover types
% Needed for VEG and FTC/FHC/FBC below
ftreemv = 0;
fherbmv = 0;
ftypemv = 0;
for year = startYearClim:endYearClim
    syear = num2str(year);
    fin = [DIRMODV, '/cover/modvir_cover.', mvres, '.yearly.', syear, '.nc'];

    ftreein = ncread(fin, 'ftree');
    fherbin = ncread(fin, 'fherb');
    ftypein = ncread(fin, 'ftype');

    ftreemv = ftreemv + ftreein;
    fherbmv = fherbmv + fherbin;
    ftypemv = ftypemv + ftypein;
end
ftreemv = ftreemv/(endYearClim - startYearClim + 1);
fherbmv = fherbmv/(endYearClim - startYearClim + 1);
ftypemv = ftypemv/(endYearClim - startYearClim + 1);

% Is area averaging right here? (***FIXME***)
ftree = avgarea(latmv, lonmv, ftreemv, lat, lon);
fherb = avgarea(latmv, lonmv, fherbmv, lat, lon);
NTYPE = size(ftypemv, 3);
ftype = zeros(NLON, NLAT, NTYPE);
for nt = 1:NTYPE
    ftype(:,:,nt) = avgarea(latmv, lonmv, ftypemv(:,:,nt), lat, lon);
end

%%% Specific land cover type classification for soil moisture
dname = 'VEG';
fout = [DIRCASA, '/', runname, '/maps/', dname, '.mat'];
if ~isfile(fout) || REPRO
    VEG = zeros(NLAT, NLON);

    [maxfrac, lct] = max(ftype, [], 3);
    lct = flipud(lct');

    %%% INPUT %%%
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

    VEG(lct ==  1) =  1;
    VEG(lct ==  2) =  2;
    VEG(lct ==  3) =  3;
    VEG(lct ==  4) =  4;
    VEG(lct ==  5) =  5;
    VEG(lct ==  6 | lct ==  7) = 6;
    VEG(lct ==  8 | lct ==  9 | lct == 10) = 7;
    VEG(lct == 11 | lct == 17) = 8;			% Classify water as wetlands so all cells have a type
    VEG(lct == 12 | lct == 14) = 9;
    VEG(lct == 13) = 10;
    VEG(lct == 15) = 12;
    VEG(lct == 16) = 11;

    save(fout, dname, '-v7');
end

%%% Fractional tree, herbaceous, and bare cover
FTC = flipud(ftree');
FHC = flipud(fherb');
% Add [0,1] check?
FBC = 1. - FTC - FHC;

datasets = {'FTC', 'FHC', 'FBC'};
for ii = 1:length(datasets)
    dname = datasets{ii};
    fout  = [DIRCASA, '/', runname,  '/maps/', dname, '.mat'];

    if isfile(fout) && ~REPRO, continue; end

    save(fout, dname, '-v7');
end

%%% Crops
dxin = 1/12;
latin = [ -90 + dxin/2:dxin: 90 - dxin/2]';
lonin = [-180 + dxin/2:dxin:180 - dxin/2]';
fcorn = [DIRAUX, '/SPAM/2010/spam2010V2r0_global_P_MAIZ_A.tif'];
fsoy  = [DIRAUX, '/SPAM/2010/spam2010V2r0_global_P_SOYB_A.tif'];

totin = zeros(numel(lonin), numel(latin));

% conversion = (1 - fwater) * fcarbon
% Constants from Bernacchi et al. (2005; https://doi.org/10.1111/j.1365-2486.2005.01050.x)
corn = struct('name','corn', 'file',fcorn, 'values',totin, ...
    'conversion',(1 - 0.155) * 0.447);
soy  = struct('name','soy', 'file',fsoy, 'values',totin, ...
    'conversion',(1 - 0.130) * 0.540);

crops = [corn; soy];

for nn = 1:numel(crops)
    ff = crops(nn).file;

    [AA, RR] = readgeoraster(ff, 'outputtype', 'double');
    AA = max(AA, 0);

    crops(nn).values = crops(nn).conversion * flipud(AA)';
    totin = totin + crops(nn).values;
end

weight = min(max((LA - 23)/(27 - 23), 0), 1);
areain = globarea(latin, lonin);

totre = 1e6 * avgarea(latin, lonin, totin./areain, lat, lon);
total = totre .* weight;

%% CASA-specific stuff
SINK = flipud(total');

EMAX = 0.40 * ones(size(SINK));
EMAX = EMAX - 0.04*flipud(sum(ftype(:,:,[6:10]), 3)');
inds = find(SINK > 0);
EMAX(inds) = EMAX(inds) + 0.0013*SINK(inds);
% Adjustment to better match past CASAs
EMAX = EMAX * 1.07;

datasets = {'SINK', 'EMAX'};
for ii = 1:length(datasets)
    dname = datasets{ii};
    fout  = [DIRCASA, '/', runname,  '/maps/', dname, '.mat'];

    if isfile(fout) && ~REPRO, continue; end

    save(fout, dname, '-v7');
end

%%% Soil carbon and texture components
%
% Plan for extension w/ modularity:
% The block below should go into some subroutine, say,
%     +makeCASAinput/soil.m
% This will do the HWSD & SoilGrids dependent conversion to the format CASA
% wants and save as .mat files. It can also call various conversion
% subroutines, say,
%     +convert/HWSDv1.m
%     +convert/HWSDv2.m
%     +convert/SoilGrids.m
% That can create netCDF files in a reasonably consistent format at any
% resolution and chose whether or not to overwrite existing output.
%
% This should reproduce all functionality with appropriate speed. The only
% remaining consideration for me is whether these should be a separate
% package instead of within CASA. Also all of this assumes the data are
% already downloaded, and for things like peat fraction, a shell
% conversion is probably the easiest.
%
% Will want the option to pick between HWSD v1.2, v2, and SoilGrids here
NSOILDAT = 1;
if NSOILDAT == 1
    fin = [DIRAUX, '/HWSD/v2/HWSD2_0-20cm.', casares, '.nc'];
    ORGC_top = flipud(ncread(fin, 'soc')');
    sand = flipud(ncread(fin, 'sand')');
    silt = flipud(ncread(fin, 'silt')');
    clay = flipud(ncread(fin, 'clay')');
    fill = flipud(ncread(fin, 'fill')');

    fin = [DIRAUX, '/HWSD/v2/HWSD2_20-40cm.', casares, '.nc'];
    ORGC_top = ORGC_top + 0.50*flipud(ncread(fin, 'soc')');
    sand = 0.75*sand + 0.25*flipud(ncread(fin, 'sand')');
    silt = 0.75*silt + 0.25*flipud(ncread(fin, 'silt')');
    clay = 0.75*clay + 0.25*flipud(ncread(fin, 'clay')');
    fill = 0.75*fill + 0.25*flipud(ncread(fin, 'fill')');

    ORGC_sub = 0.50*flipud(ncread(fin, 'soc')');
    fin = [DIRAUX, '/HWSD/v2/HWSD2_40-60cm.', casares, '.nc'];
    ORGC_sub = ORGC_sub + flipud(ncread(fin, 'soc')');
    fin = [DIRAUX, '/HWSD/v2/HWSD2_60-80cm.', casares, '.nc'];
    ORGC_sub = ORGC_sub + flipud(ncread(fin, 'soc')');
    fin = [DIRAUX, '/HWSD/v2/HWSD2_80-100cm.', casares, '.nc'];
    ORGC_sub = ORGC_sub + flipud(ncread(fin, 'soc')');
elseif NSOILDAT == 2
    fin = [DIRAUX, '/HWSD/v1.2/HWSD1.2.', casares, '.nc'];
    ORGC_top = flipud(ncread(fin, 't_soc')');
    ORGC_sub = flipud(ncread(fin, 's_soc')');
    sand = flipud(ncread(fin, 't_sand')');
    silt = flipud(ncread(fin, 't_silt')');
    clay = flipud(ncread(fin, 't_clay')');
    fill = flipud(ncread(fin, 't_fill')');
end

%%% Soil texture class
% Percentages of sand-silt-clay from Potter et al. (1993)
ppcoarse = [83;  8;  9];
ppcormed = [60; 20; 20];
ppmedium = [37; 33; 30];
ppmedfin = [27; 25; 48];
ppfine   = [17; 17; 66];

% Fix fill/sand accounting based on land cover type
inds = find(flipud(sum(ftype(:,:,[1:14,16]), 3)') > 0);
sand(inds) = sand(inds) + fill(inds);
fill(inds) = 0;
inds = find(flipud(sum(ftype(:,:,[1:14,16]), 3)') == 0);
fill(inds) = fill(inds) + sand(inds) + silt(inds) + clay(inds);
sand(inds) = 0;
silt(inds) = 0;
clay(inds) = 0;

% Determine closest texture class centroid
dcoarse = 0.5*(sand - ppcoarse(1)).^2 + 0.5*(silt - ppcoarse(2)).^2 ...
        + 0.5*(clay - ppcoarse(3)).^2;
dcormed = 0.5*(sand - ppcormed(1)).^2 + 0.5*(silt - ppcormed(2)).^2 ...
        + 0.5*(clay - ppcormed(3)).^2;
dmedium = 0.5*(sand - ppmedium(1)).^2 + 0.5*(silt - ppmedium(2)).^2 ...
        + 0.5*(clay - ppmedium(3)).^2;
dmedfin = 0.5*(sand - ppmedfin(1)).^2 + 0.5*(silt - ppmedfin(2)).^2 ...
        + 0.5*(clay - ppmedfin(3)).^2;
dfine   = 0.5*(sand - ppfine(1)).^2   + 0.5*(silt - ppfine(2)).^2 ...
        + 0.5*(clay - ppfine(3)).^2;
dmin    = min(dcoarse, min(dcormed, min(dmedium, min(dmedfin, dfine))));
% Ensure no match for non-soil pixels
dmin(sand + silt + clay == 0) = -1;

%% 1 = peat, which is reclassified as 3 in code
%% 7 is reclassified as 6 in code
%SOILTEXT = zeros(size(dmin));
%SOILTEXT(dcoarse == dmin) = 2;
%SOILTEXT(dcormed == dmin) = 3;
%SOILTEXT(dmedium == dmin) = 4;
%SOILTEXT(dmedfin == dmin) = 5;
%SOILTEXT(dfine   == dmin) = 6;

% Convert from percent to fraction
sand = sand/100;
silt = silt/100;
clay = clay/100;
fill = fill/100;

%datasets = {'ORGC_top', 'ORGC_sub', 'sand', 'silt', 'clay', 'SOILTEXT'};
datasets = {'ORGC_top', 'ORGC_sub', 'sand', 'silt', 'clay'};
for ii = 1:length(datasets)
    dname = datasets{ii};
    fout  = [DIRCASA, '/', runname,  '/maps/', dname, '.mat'];

    if isfile(fout) && ~REPRO, continue; end

    save(fout, dname, '-v7');
end
