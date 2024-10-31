addpath('/discover/nobackup/bweir/matlab/globutils');

%NDOWN = 12;
NDOWN = 60;
LAYER = 'D1';

% Could read these from .hdr file
NLATIN = 21600;
NLONIN = 43200;
NODATA = 65535;

%%% Initialize
dxin = 180/NLATIN;
latin = [ -90+dxin/2:dxin: 90-dxin/2]';
lonin = [-180+dxin/2:dxin:180-dxin/2]';
areain = globarea(latin, lonin);

dx = 180/NLATIN*NDOWN;
lat = [ -90+dx/2:dx: 90-dx/2]';
lon = [-180+dx/2:dx:180-dx/2]';
area = globarea(lat, lon);

NLAT = numel(lat);
NLON = numel(lon);

%%% Read raster file
fprintf('Reading ... '); tic;
SMUin = multibandread('HWSD2.bil', [NLATIN NLONIN 1], 'uint16=>uint16', 0, ...
    'bil', 'ieee-le');
SMUin = flipud(SMUin)';
SMUin(SMUin == NODATA) = 0;

% Hack to screen out water
SMU1in = multibandread('../v1.2/hwsd.bil', [NLATIN NLONIN 1], 'uint16=>uint16', 0, ...
    'bil', 'ieee-le');
SMU1in = flipud(SMU1in)';
SMUin(SMU1in == 0) = 0;
clear SMU1in;

%% Only for plotting/reference
%SMU3 = [];
%for jj = 1:NDOWN
%    for ii = 1:NDOWN
%        SMU3 = cat(3, SMU3, SMUin(ii:NDOWN:end,jj:NDOWN:end));
%    end
%end
%SMU = mode(SMU3, 3);

%%% Read database
SDB = readcell('HWSD2_LAYERS.csv');
smudbs = [SDB{2:end,2}]';
fprintf([int2str(toc), ' seconds elapsed.\n']);

%%% Compute totals for each SMU
fprintf('Calculating SMU totals ... '); tic;
% Add one since SMU can be 0 (see below)
NSMUDBS  = max(smudbs) + 1;
sharesmu = zeros(NSMUDBS, 1);
socsmu   = zeros(NSMUDBS, 1);
sandsmu  = zeros(NSMUDBS, 1);
siltsmu  = zeros(NSMUDBS, 1);
claysmu  = zeros(NSMUDBS, 1);
fillsmu  = zeros(NSMUDBS, 1);
for nn = 1:NSMUDBS
    % Subtract one from nn since SMU can be 0 (see above)
    % Add one to idbs since first line is header
    idbs = find(smudbs == nn-1) + 1;
    for mm = 1:numel(idbs)
        id = idbs(mm);

        %  9 = SHARE
        % 24 = LAYER
        % 25 = TOPDEP
        % 26 = BOTDEP
        % 27 = COARSE
        % 28 = SAND
        % 29 = SILT
        % 30 = CLAY
        % 33 = BULK
        % 35 = ORG_CARBON

        if ~strcmp(SDB{id,24}, LAYER), continue; end

        sharesmu(nn) = sharesmu(nn) + SDB{id,9};

        jjs = [9,25:27,33,35];
        if sum(ismissing([SDB{id,jjs}])) == 0 && 0 <= min([SDB{id,jjs}])
            depshare = (SDB{id,26} - SDB{id,25}) * SDB{id,9}/100;
            socsmu(nn) = socsmu(nn) + SDB{id,33}*SDB{id,35}/100 ...
                * (1 - SDB{id,27}/100) * depshare;
        end

        sanddb = SDB{id,28};
        siltdb = SDB{id,29};
        claydb = SDB{id,30};

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

        sandsmu(nn) = sandsmu(nn) + sanddb * SDB{id,9}/100;
        siltsmu(nn) = siltsmu(nn) + siltdb * SDB{id,9}/100;
        claysmu(nn) = claysmu(nn) + claydb * SDB{id,9}/100;
        fillsmu(nn) = fillsmu(nn) + filldb * SDB{id,9}/100;

        % Inefficient but whatevs
        deptag = [num2str(SDB{id,25}), '-', num2str(SDB{id,26}), 'cm'];
    end
end
% One SMU (36003) doesn't have a full share
inds = find(sharesmu > 0);
socsmu(inds)  =  socsmu(inds) .* 100./sharesmu(inds);
sandsmu(inds) = sandsmu(inds) .* 100./sharesmu(inds);
siltsmu(inds) = siltsmu(inds) .* 100./sharesmu(inds);
claysmu(inds) = claysmu(inds) .* 100./sharesmu(inds);
fillsmu(inds) = fillsmu(inds) .* 100./sharesmu(inds);
fprintf([int2str(toc), ' seconds elapsed.\n']);

%%% Fill raster arrays and downsample
fprintf('Filling raster arrays ... '); tic;
% Add one to SMU since it can be 0 (see above)
[soc, smx, smy] = avgarea(latin, lonin, socsmu(SMUin+1), lat, lon);

% One way, kinda slow
%ii = repmat([1:NLON], NDOWN, 1);
%jj = repmat([1:NLAT], NDOWN, 1);
%[JJ, II] = meshgrid(jj(:), ii(:));
%sand = accumarray([II(:) JJ(:)], sandsmu(SMUin(:)+1), [NLON NLAT], @mean);
%silt = accumarray([II(:) JJ(:)], siltsmu(SMUin(:)+1), [NLON NLAT], @mean);
%clay = accumarray([II(:) JJ(:)], claysmu(SMUin(:)+1), [NLON NLAT], @mean);
%fill = accumarray([II(:) JJ(:)], fillsmu(SMUin(:)+1), [NLON NLAT], @mean);

% Another way, floating-point diffs, but way faster
smx = round(smx)/NDOWN;
smy = round(smy)/NDOWN;
share = smy' * sharesmu(SMUin+1) * smx;
sand  = smy' *  sandsmu(SMUin+1) * smx;
silt  = smy' *  siltsmu(SMUin+1) * smx;
clay  = smy' *  claysmu(SMUin+1) * smx;
fill  = smy' *  fillsmu(SMUin+1) * smx;
fprintf([int2str(toc), ' seconds elapsed.\n']); tic;

%%% Write
fprintf('Writing ... '); tic;
fout = ['HWSD2_', deptag, '.x', num2str(NLON), '_y', num2str(NLAT), '.nc'];

idnc = netcdf.create(fout, 'clobber');
netcdf.close(idnc);

ncwriteatt(fout, '/', 'Conventions', 'CF-1.10');
ncwriteatt(fout, '/', 'title',       'HWSD v2 regridded');
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

nccreate(fout,   'soc',  'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    'soc',  soc*100*100);
ncwriteatt(fout, 'soc',  'units',      'g C m-2');
ncwriteatt(fout, 'soc',  'long_name',  'Soil Organic Carbon');

nccreate(fout,   'sand', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    'sand', sand);
ncwriteatt(fout, 'sand', 'units',      '%');
ncwriteatt(fout, 'sand', 'long_name',  'Sand');

nccreate(fout,   'silt', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    'silt', silt);
ncwriteatt(fout, 'silt', 'units',      '%');
ncwriteatt(fout, 'silt', 'long_name',  'Silt');

nccreate(fout,   'clay', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    'clay', clay);
ncwriteatt(fout, 'clay', 'units',      '%');
ncwriteatt(fout, 'clay', 'long_name',  'Clay');

nccreate(fout,   'fill', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    'fill', fill);
ncwriteatt(fout, 'fill', 'units',      '%');
ncwriteatt(fout, 'fill', 'long_name',  'Fill (Ice/Rock/Impervious)');

nccreate(fout,   'share', 'dimensions', {'lon', NLON, 'lat', NLAT});
ncwrite(fout,    'share', share);
ncwriteatt(fout, 'share', 'units',      '%');
ncwriteatt(fout, 'share', 'long_name',  'Share');
fprintf([int2str(toc), ' seconds elapsed.\n']);
