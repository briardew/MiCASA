%MAKENRTBURN   Make near real time (NRT) burned area
%
%    MAKENRTBURN computes averages and std devs of burned area from an
%    input dataset and averages and std devs of biomass burning from
%    QFED. It computes NRT burned area by adding the the input average
%    a scaled version of the QFED anomaly. The random errors of this
%    approximation
%
% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2024-12-17	First crack
%
% TODO:
% * Split into 2 phases for fit and use? (takes about 10 minutes)
% * Make more robust/consistent
%===============================================================================

% Need to make this more robust; for now, happy not referencing
% my own nobackup; NB: This will only work on systems that already have QFED
DIRHEAD = '../..';
QFDIR   = [DIRHEAD, '/data-aux/QFED/v2.6r1/sfc'];
QFNRT   = [DIRHEAD, '/data-aux/QFED/v2.6r1-nrt/sfc'];
DIRIN   = [DIRHEAD, '/data/burn'];
DIROUT  = [DIRHEAD, '/data-nrt/burn'];

VERSION = '1';
REPRO = 1;					% Reprocess?
YEAR0 = 2001;					% Fit start
YEARF = 2021;					% Fit end
DNOUT = [datenum(2024,10,01):now];

% Low resolution for scaling factors
dxlo  = 4;
latlo = [ -90+dxlo/2:dxlo: 90-dxlo/2]';
lonlo = [-180+dxlo/2:dxlo:180-dxlo/2]';
NLATLO = numel(latlo);
NLONLO = numel(lonlo);

% Mid resolution to blur QFED
dxmx = 0.25;
latmx = [ -90+dxmx/2:dxmx: 90-dxmx/2]';
lonmx = [-180+dxmx/2:dxmx:180-dxmx/2]';
NLATMX = numel(latmx);
NLONMX = numel(lonmx);

% Timestamp settings
YSTART = 1980;
TSTAMP = ['days since ', num2str(YSTART), '-01-01'];

% Output file settings
FEXT    = 'nc4';
FORMAT  = 'netcdf4';
% We do these afterwards since Matlab appears to have memory issues
% It is also quite long
%DEFLATE = 9;
%SHUFFLE = true;
DEFLATE = 0;
SHUFFLE = false;


% RUN
%==============================================================================
NBINS = 3;					% Wood, defo, and herb

% Get grid data
% ---
fba = [DIRIN, '/2003/modvir_burn.x3600_y1800.monthly.200301.nc'];
fqf = [QFDIR, '/0.1/monthly/Y2003/M01', ...
    '/qfed2.emis_co2.061.x3600_y1800.200301mm.nc4'];

lat  = ncread(fba, 'lat');
lon  = ncread(fba, 'lon');
NLAT = numel(lat);
NLON = numel(lon);

area = globarea(lat, lon, 6371007.181);

latqf  = ncread(fqf, 'lat');
lonqf  = ncread(fqf, 'lon');
NLATQF = numel(latqf);
NLONQF = numel(lonqf);

% Initialize arrays
% ---
newba = zeros(NLON, NLAT, NBINS);
avgba = zeros(NLON, NLAT, NBINS, 12);
stdba = zeros(NLON, NLAT, NBINS, 12);
maxba = zeros(NLON, NLAT, NBINS);
newqf = zeros(NLONQF, NLATQF, NBINS);
avgqf = zeros(NLONQF, NLATQF, NBINS, 12);
stdqf = zeros(NLONQF, NLATQF, NBINS, 12);
maxqf = zeros(NLON, NLAT, NBINS);

% Compute climatologies
% ---
disp('Computing climatologies ...');
tic;
for year = YEAR0:YEARF
    ny = year - YEAR0 + 1;
    syear = num2str(year);
    for nm = 1:12
        smon = num2str(nm, '%02u');

        fba = [DIRIN, '/', syear, '/modvir_burn.x3600_y1800.monthly.', ...
            syear, smon, '.nc'];
        fqf = [QFDIR, '/0.1/monthly/Y', syear, '/M', smon, ...
            '/qfed2.emis_co2.061.x3600_y1800.', syear, smon, 'mm.nc4'];

        newba(:,:,1) = ncread(fba, 'bawood');
        newba(:,:,2) = ncread(fba, 'badefo');
        newba(:,:,3) = ncread(fba, 'baherb');

        newqf(:,:,1) = ncread(fqf, 'biomass');
        newqf(:,:,2) = newqf(:,:,1);
        newqf(:,:,3) = newqf(:,:,1);

	%% Online variance algorithm
        prvba = avgba(:,:,:,nm);
	prvqf = avgqf(:,:,:,nm);

        %%% Hold these for online algorithm
        outba = prvba + (newba - prvba)/ny;
        outqf = prvqf + (newqf - prvqf)/ny;

        avgba(:,:,:,nm) = outba;
        avgqf(:,:,:,nm) = outqf;
        stdba(:,:,:,nm) = stdba(:,:,:,nm) + (newba - prvba).*(newba - outba);
        stdqf(:,:,:,nm) = stdqf(:,:,:,nm) + (newqf - prvqf).*(newqf - outqf);
	maxqf = max(maxqf, newqf);
    end
end
% Sometimes we get very small negatives
stdba = sqrt(abs(stdba)/(YEARF - YEAR0 + 1));
stdqf = sqrt(abs(stdqf)/(YEARF - YEAR0 + 1));
% Threshold to avoid NaNs
stdqf = max(stdqf, max(stdqf(:))/1e9);
toc;

% Compute dailies
% ---
disp('Computing dailies ...');
tic;
% Bit of a hack ***FIXME***
fvcf = [DIRHEAD, '/data/cover/modvir_cover.x3600_y1800.yearly.2024.nc'];
maxba(:,:,1) = area .* ncread(fvcf, 'ftree');
maxba(:,:,2) = area .* ncread(fvcf, 'ftree');
maxba(:,:,3) = area .* ncread(fvcf, 'fherb');

for id = 1:numel(DNOUT)
    ny = year - YEAR0 + 1;
    dnum = DNOUT(id);
    dvec = datevec(dnum);

    year = dvec(1);
    nm   = dvec(2);
    nd   = dvec(3);

    syear = num2str(year);
    smon  = num2str(nm, '%02u');
    sday  = num2str(nd, '%02u');

    fqf = [QFNRT, '/0.1/Y', syear, '/M', smon, ...
        '/qfed2.emis_co2.061.', syear, smon, sday, '.nc4'];
    % Brutal hack? ***FIXME***
    fout = [DIROUT, '/', syear, '/modvir_burn.x3600_y1800.daily.', ...
        syear, smon, sday, '.nc'];

    newqf(:,:,1) = ncread(fqf, 'biomass');
    newqf(:,:,2) = newqf(:,:,1);
    newqf(:,:,3) = newqf(:,:,1);

%    %% A. Climatology (for bug/unit tests)
%    newba = avgba(:,:,:,nm);

    %% B. Two-moment expansion
    ZMIN = -300; ZMAX = 300;
    zzzba = (newqf - avgqf(:,:,:,nm))./stdqf(:,:,:,nm);
    zzzba = min(max(zzzba, ZMIN), ZMAX);
    newba = avgba(:,:,:,nm) + zzzba.*stdba(:,:,:,nm);
    % Zero-out small values to prevent widespread, persistent sources
    newba(zzzba == ZMIN) = 0;

    % Convert daily to monthly (d'oh)
    molen = datenum(year,nm+1,01) - datenum(year,nm,01);
    newba = newba/molen;

    % Threshold (could be before or after month conversion)
    newba = min(max(newba, 0), maxba);

    if isfile(fout)
        if REPRO
            [status, result] = system(['rm ', fout]);
        else
            continue;
        end
    end

    dnowout = [DIROUT, '/', syear];
    if ~isfolder(dnowout)
        [status, result] = system(['mkdir -p ', dnowout]);
    end

    % Write it
    time = datenum(year, nm, nd) - datenum(YSTART, 1, 1);

    nccreate(fout,   'lat', 'dimensions',{'lat',NLAT}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwriteatt(fout, 'lat', 'units','degrees_north');
    ncwriteatt(fout, 'lat', 'long_name','latitude');
    ncwrite(fout,    'lat', lat);

    nccreate(fout,   'lon', 'dimensions',{'lon',NLON}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwriteatt(fout, 'lon', 'units','degrees_east');
    ncwriteatt(fout, 'lon', 'long_name','longitude');
    ncwrite(fout,    'lon', lon);

    nccreate(fout,   'time', 'dimensions',{'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwriteatt(fout, 'time', 'long_name','time');
    ncwriteatt(fout, 'time', 'units',TSTAMP);
    ncwriteatt(fout, 'time', 'bounds','time_bnds');
    ncwrite(fout,    'time', time);

    nccreate(fout,   'time_bnds', ...
        'dimensions', {'nv',2, 'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwriteatt(fout, 'time_bnds', 'units',TSTAMP);
    ncwriteatt(fout, 'time_bnds', 'long_name','time bounds');
    ncwrite(fout,    'time_bnds', [time; time+1]);

    nccreate(fout,   'batot', 'datatype','single', ...
        'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwrite(fout,    'batot', single(sum(newba,3)));
    ncwriteatt(fout, 'batot', 'units','m2');
    ncwriteatt(fout, 'batot', 'long_name','Total burned area');

    nccreate(fout,   'bawood', 'datatype','single', ...
        'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwrite(fout,    'bawood', single(newba(:,:,1)));
    ncwriteatt(fout, 'bawood', 'units','m2');
    ncwriteatt(fout, 'bawood', 'long_name','Woody burned area');

    nccreate(fout,   'badefo', 'datatype','single', ...
        'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwrite(fout,    'badefo', single(newba(:,:,2)));
    ncwriteatt(fout, 'badefo', 'units','m2');
    ncwriteatt(fout, 'badefo', 'long_name','Deforestation burned area');

    nccreate(fout,   'baherb', 'datatype','single', ...
        'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwrite(fout,    'baherb', single(newba(:,:,3)));
    ncwriteatt(fout, 'baherb', 'units','m2');
    ncwriteatt(fout, 'baherb', 'long_name','Herbaceous burned area');
end
toc;
