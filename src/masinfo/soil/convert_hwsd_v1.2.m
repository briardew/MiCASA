addpath('/discover/nobackup/bweir/matlab/globutils');

NDOWN = 12;

% Could read these from .hdr file
NLATIN = 21600;
NLONIN = 43200;
NODATA = 65535;

%%% Initialize
dxin = 180/NLATIN;
latin = [ -90+dxin/2:dxin: 90-dxin/2]';
lonin = [-180+dxin/2:dxin:180-dxin/2]';

dx = 180/NLATIN*NDOWN;
lat = [ -90+dx/2:dx: 90-dx/2]';
lon = [-180+dx/2:dx:180-dx/2]';

NLAT = numel(lat);
NLON = numel(lon);

%%% Read raster file
fprintf('Reading ... '); tic;
SMUin = multibandread('hwsd.bil', [NLATIN NLONIN 1], 'uint16=>uint16', 0, ...
    'bil', 'ieee-le');
SMUin = flipud(SMUin)';

%% Only for plotting/reference
%SMU3 = [];
%for jj = 1:NDOWN
%    for ii = 1:NDOWN
%        SMU3 = cat(3, SMU3, SMUin(ii:NDOWN:end,jj:NDOWN:end));
%    end
%end
%SMU = mode(SMU3, 3);

%%% Read database
SDB = readcell('HWSD_DATA.csv');
smudbs = [SDB{2:end,2}]';
fprintf([int2str(toc), ' seconds elapsed.\n']);

%%% Compute totals for each SMU
fprintf('Calculating SMU totals ... '); tic;
% Add one since SMU can be 0 (see below)
NSMUDBS   = max(smudbs) + 1;
sharesmu  = zeros(NSMUDBS, 1);
t_socsmu  = zeros(NSMUDBS, 1);
t_sandsmu = zeros(NSMUDBS, 1);
t_siltsmu = zeros(NSMUDBS, 1);
t_claysmu = zeros(NSMUDBS, 1);
t_fillsmu = zeros(NSMUDBS, 1);
s_socsmu  = zeros(NSMUDBS, 1);
s_sandsmu = zeros(NSMUDBS, 1);
s_siltsmu = zeros(NSMUDBS, 1);
s_claysmu = zeros(NSMUDBS, 1);
s_fillsmu = zeros(NSMUDBS, 1);
for nn = 1:NSMUDBS
    % Subtract one from nn since SMU can be 0 (see above)
    % Add one to idbs since first line is header
    idbs = find(smudbs == nn-1) + 1;
    for mm = 1:numel(idbs)
        id = idbs(mm);

        %  6 = SHARE
        % 14 = T_TEXTURE
        % 24 = T_GRAVEL
        % 25 = T_SAND
        % 26 = T_SILT
        % 27 = T_CLAY
        % 28 = T_USDA_TEX_CLASS
        % 30 = T_OC
        % 40 = S_GRAVEL
        % 41 = S_SAND
        % 42 = S_SILT
        % 43 = S_CLAY
        % 46 = S_OC
        % 56 = T_BULK_DENSITY
        % 57 = S_BULK_DENSITY

        sharesmu(nn) = sharesmu(nn) + SDB{id,6};

        % Topsoil variables
        jjs = [6,24,30,56];
        if sum(ismissing([SDB{id,jjs}])) == 0 && 0 <= min([SDB{id,jjs}])
            t_socsmu(nn) = t_socsmu(nn) + SDB{id,56}*SDB{id,30}/100 ...
                * (1 - SDB{id,24}/100) * 30 * SDB{id,6}/100;
        end

        sanddb = SDB{id,25};
        siltdb = SDB{id,26};
        claydb = SDB{id,27};

        % Classify all non water/ice as sand, everything else to fill
        if sum(ismissing([sanddb, siltdb, claydb])) > 0
            sanddb = 0;
            siltdb = 0;
            claydb = 0;
        elseif min([sanddb, siltdb, claydb]) < -2
            sanddb = 100;
            siltdb = 0;
            claydb = 0;
        elseif min([sanddb, siltdb, claydb]) < 0
            sanddb = 0;
            siltdb = 0;
            claydb = 0;
        end

        % One entry adds up to 99 :)
        filldb = 100 - (sanddb + siltdb + claydb);

        t_sandsmu(nn) = t_sandsmu(nn) + sanddb * SDB{id,6}/100;
        t_siltsmu(nn) = t_siltsmu(nn) + siltdb * SDB{id,6}/100;
        t_claysmu(nn) = t_claysmu(nn) + claydb * SDB{id,6}/100;
        t_fillsmu(nn) = t_fillsmu(nn) + filldb * SDB{id,6}/100;

        % Subsoil variables
        jjs = [6,40,46,57];
        if sum(ismissing([SDB{id,jjs}])) == 0 && 0 <= min([SDB{id,jjs}])
            s_socsmu(nn) = s_socsmu(nn) + SDB{id,57}*SDB{id,46}/100 ...
                * (1 - SDB{id,40}/100) * 70 * SDB{id,6}/100;
        end

        sanddb = SDB{id,41};
        siltdb = SDB{id,42};
        claydb = SDB{id,43};

        % Classify all non water/ice as sand, everything else to fill
        if sum(ismissing([sanddb, siltdb, claydb])) > 0
            sanddb = 0;
            siltdb = 0;
            claydb = 0;
        elseif min([sanddb, siltdb, claydb]) < -2
            sanddb = 100;
            siltdb = 0;
            claydb = 0;
        elseif min([sanddb, siltdb, claydb]) < 0
            sanddb = 0;
            siltdb = 0;
            claydb = 0;
        end

        % One entry adds up to 99 :)
        filldb = 100 - (sanddb + siltdb + claydb);

        s_sandsmu(nn) = s_sandsmu(nn) + sanddb * SDB{id,6}/100;
        s_siltsmu(nn) = s_siltsmu(nn) + siltdb * SDB{id,6}/100;
        s_claysmu(nn) = s_claysmu(nn) + claydb * SDB{id,6}/100;
        s_fillsmu(nn) = s_fillsmu(nn) + filldb * SDB{id,6}/100;
    end
end
fprintf([int2str(toc), ' seconds elapsed.\n']);

%%% Fill raster arrays and downsample
fprintf('Filling raster arrays ... '); tic;
% Add one to SMU since it can be 0 (see above)
[t_soc, smx, smy] = avgarea(latin, lonin, t_socsmu(SMUin+1), lat, lon);
s_soc = avgarea(latin, lonin, s_socsmu(SMUin+1), lat, lon);

smx = round(smx)/NDOWN;
smy = round(smy)/NDOWN;
share  = smy' *  sharesmu(SMUin+1) * smx;

t_sand = smy' * t_sandsmu(SMUin+1) * smx;
t_silt = smy' * t_siltsmu(SMUin+1) * smx;
t_clay = smy' * t_claysmu(SMUin+1) * smx;
t_fill = smy' * t_fillsmu(SMUin+1) * smx;

s_sand = smy' * s_sandsmu(SMUin+1) * smx;
s_silt = smy' * s_siltsmu(SMUin+1) * smx;
s_clay = smy' * s_claysmu(SMUin+1) * smx;
s_fill = smy' * s_fillsmu(SMUin+1) * smx;
fprintf([int2str(toc), ' seconds elapsed.\n']); tic;

%%% Create texture map
% Values from Potter et al. (1993)
ppcoarse = [83;  8;  9];
ppcormed = [60; 20; 20];
ppmedium = [37; 33; 30];
ppmedfin = [27; 25; 48];
ppfine   = [17; 17; 66];

dcoarse = 0.5*(t_sand - ppcoarse(1)).^2 + 0.5*(t_silt - ppcoarse(2)).^2 ...
        + 0.5*(t_clay - ppcoarse(3)).^2;
dcormed = 0.5*(t_sand - ppcormed(1)).^2 + 0.5*(t_silt - ppcormed(2)).^2 ...
        + 0.5*(t_clay - ppcormed(3)).^2;
dmedium = 0.5*(t_sand - ppmedium(1)).^2 + 0.5*(t_silt - ppmedium(2)).^2 ...
        + 0.5*(t_clay - ppmedium(3)).^2;
dmedfin = 0.5*(t_sand - ppmedfin(1)).^2 + 0.5*(t_silt - ppmedfin(2)).^2 ...
        + 0.5*(t_clay - ppmedfin(3)).^2;
dfine   = 0.5*(t_sand - ppfine(1)).^2   + 0.5*(t_silt - ppfine(2)).^2 ...
        + 0.5*(t_clay - ppfine(3)).^2;
dmin    = min(dcoarse, min(dcormed, min(dmedium, min(dmedfin, dfine))));
dmin(t_sand + t_silt + t_clay == 0) = -1;

t_text = zeros(size(t_fill));
t_text(dcoarse == dmin) = 2;
t_text(dcormed == dmin) = 3;
t_text(dmedium == dmin) = 4;
t_text(dmedfin == dmin) = 5;
t_text(dfine   == dmin) = 6;

%%% Write
fprintf('Writing ... '); tic;
fout = ['HWSD1.2.x', num2str(NLON), '_y', num2str(NLAT), '.nc'];

idnc = netcdf.create(fout, 'clobber');
netcdf.close(idnc);

ncwriteatt(fout, '/', 'Conventions', 'CF-1.10');
ncwriteatt(fout, '/', 'title',       'HWSD v1.2 regridded');
ncwriteatt(fout, '/', 'institution', 'NASA GEOS Constituent Group');
ncwriteatt(fout, '/', 'contact',     'Brad Weir <brad.weir@nasa.gov>');
ncwriteatt(fout, '/', 'history',    ['Created on ', datestr(now, 31)]);

nccreate(fout,   'lat',  'dimensions', {'lat', NLAT});
ncwriteatt(fout, 'lat',  'units',      'degrees_north');
ncwriteatt(fout, 'lat',  'long_name',  'latitude');
ncwrite(fout,    'lat',  lat);

nccreate(fout,   'lon',  'dimensions', {'lon', NLON});
ncwriteatt(fout, 'lon',  'units',      'degrees_east');
ncwriteatt(fout, 'lon',  'long_name',  'longitude');
ncwrite(fout,    'lon',  lon);

nccreate(fout,   't_soc',  'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    't_soc',  t_soc*100*100);
ncwriteatt(fout, 't_soc',  'units',      'g C m-2');
ncwriteatt(fout, 't_soc',  'long_name',  'Topsoil Soil Organic Carbon');

nccreate(fout,   't_sand', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    't_sand', t_sand);
ncwriteatt(fout, 't_sand', 'units',      '%');
ncwriteatt(fout, 't_sand', 'long_name',  'Topsoil Sand');

nccreate(fout,   't_silt', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    't_silt', t_silt);
ncwriteatt(fout, 't_silt', 'units',      '%');
ncwriteatt(fout, 't_silt', 'long_name',  'Topsoil Silt');

nccreate(fout,   't_clay', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    't_clay', t_clay);
ncwriteatt(fout, 't_clay', 'units',      '%');
ncwriteatt(fout, 't_clay', 'long_name',  'Topsoil Clay');

nccreate(fout,   't_fill', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    't_fill', t_fill);
ncwriteatt(fout, 't_fill', 'units',      '%');
ncwriteatt(fout, 't_fill', 'long_name',  'Topsoil Fill (Ice/Rock/Impervious)');

nccreate(fout,   't_text', 'dimensions', {'lon', NLON, 'lat', NLAT}, ...
    'datatype', 'int8');
ncwrite(fout,    't_text', int8(t_text));
ncwriteatt(fout, 't_text', 'units',      '#');
ncwriteatt(fout, 't_text', 'long_name',  'Topsoil Texture Class');

nccreate(fout,   's_soc',  'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    's_soc',  s_soc*100*100);
ncwriteatt(fout, 's_soc',  'units',      'g C m-2');
ncwriteatt(fout, 's_soc',  'long_name',  'Subsoil Soil Organic Carbon');

nccreate(fout,   's_sand', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    's_sand', s_sand);
ncwriteatt(fout, 's_sand', 'units',      '%');
ncwriteatt(fout, 's_sand', 'long_name',  'Subsoil Sand');

nccreate(fout,   's_silt', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    's_silt', s_silt);
ncwriteatt(fout, 's_silt', 'units',      '%');
ncwriteatt(fout, 's_silt', 'long_name',  'Subsoil Silt');

nccreate(fout,   's_clay', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    's_clay', s_clay);
ncwriteatt(fout, 's_clay', 'units',      '%');
ncwriteatt(fout, 's_clay', 'long_name',  'Subsoil Clay');

nccreate(fout,   's_fill', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    's_fill', s_fill);
ncwriteatt(fout, 's_fill', 'units',      '%');
ncwriteatt(fout, 's_fill', 'long_name',  'Subsoil Fill (Ice/Rock/Impervious)');

nccreate(fout,   'share', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    'share', share);
ncwriteatt(fout, 'share', 'units',      '%');
ncwriteatt(fout, 'share', 'long_name',  'Share');
fprintf([int2str(toc), ' seconds elapsed.\n']);
