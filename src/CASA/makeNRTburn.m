%MAKENRTBURN   Make near real time (NRT) burned area
%
%    MAKENRTBURN computes averages and std devs of burned area from an input
%    dataset and averages and std devs of biomass burning from QFED. It
%    computes NRT burned area by adding the the input average a scaled version
%    of the QFED anomaly. The random errors of this approximation
%
% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2024-12-17	First crack
%
% Notes:
% * This doesn't use defineConstants. One reason is that its builds input data,
% so the `runname` variable isn't entirely appropriate. Also not sure if this
% belongs in the CASA or modvir ecosystem. Downsides: reproduction of janky
% monthly mean approach, doesn't produce files in the same format as modvir
% (need to fix modvir here), and separate definition of 1980 as time start.
%
% TODO:
% * Split into 2 phases for fit and use? (takes about 10 minutes)
% * Make more robust/consistent
%===============================================================================

runname = 'vNRT'; defineConstants;

REPRO = 0;								% Reprocess?
VERIN = '1';
YEAR0 = 2001;								% Fit start
YEARF = 2021;								% Fit end
DNOUT = [datenum(2024,10,01):now-1];

% Need to make this more robust; for now, happy not referencing
% my own nobackup; NB: This will only work on systems that already have QFED
DIRHEAD = '../..';
QFDIR   = [DIRHEAD, '/data-aux/QFED/v2.6r1/sfc'];
QFNRT   = [DIRHEAD, '/data-aux/QFED/v2.6r1-nrt/sfc'];
DIRIN   = [DIRHEAD, '/data/v',VERIN, '/drivers'];
DIROUT  = [DIRHEAD, '/data/',runname,'/drivers'];

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

% Make sure the NCO utilities are available
% Needed for monthly means, would love a better way
[status, result] = system('ncra --version');
if status ~= 0
    error(sprintf([...
        '*** Missing NCO utilities ***\n\n', ...
        'On NCCS Discover, run\n', ...
        '    > module load nco\n', ...
        'from the terminal before starting Octave/Matlab.']));
end


% RUN
%==============================================================================
NBINS = 3;					% Wood, defo, and herb

% Get grid data
% ---
% Assumes input version at same resolution (for now)
fba = [DIRIN, '/burn/2003/MiCASA_v', VERIN, '_burn_', CASARES, ...
    '_monthly_200301.nc4'];
fqf = [QFDIR, '/0.1/monthly/Y2003/M01', ...
    '/qfed2.emis_co2.061.x3600_y1800.200301mm.nc4'];

lat  = ncread(fba, 'lat');
lon  = ncread(fba, 'lon');
NLAT = numel(lat);
NLON = numel(lon);

area = globarea(lat, lon, RADIUS);

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

        fba = [DIRIN, '/burn/', syear, '/MiCASA_v', VERIN, '_burn_', ...
            CASARES, '_monthly_', syear, smon, '.nc4'];
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

% Daily
% ---
disp('Computing dailies ...');
tic;
% Bit of a hack ***FIXME***
fvcf = [DIRIN, '/cover/MiCASA_v', VERIN, '_cover_', CASARES, ...
    '_yearly_2024.nc4'];
maxba(:,:,1) = area .* ncread(fvcf, 'ftree');
maxba(:,:,2) = area .* ncread(fvcf, 'ftree');
maxba(:,:,3) = area .* ncread(fvcf, 'fherb');

for id = 1:numel(DNOUT)
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
    fout = [DIROUT, '/burn/', syear, '/MiCASA_v', VERSION, '_burn_', ...
        CASARES, '_daily_', syear, smon, sday, '.nc4'];

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

    % Convert monthly to daily (d'oh)
    molen = datenum(year,nm+1,01) - datenum(year,nm,01);
    newba = newba/molen;

    % Threshold (could be before or after month conversion)
    newba = min(max(newba, 0), maxba);

    % Skip if file exists and not reprocessing
    if isfile(fout)
        if REPRO
            [status, result] = system(['rm ', fout]);
        else
            continue;
        end
    end

    % Make sure output folder exists
    dnowout = [DIROUT, '/burn/', syear];
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

% Monthly
% ---
disp('Computing monthlies ...');
tic;

dvec  = datevec(DNOUT(1));
YRAV0 = dvec(1);
dvec  = datevec(DNOUT(end));
YRAVF = dvec(1);

for year = YRAV0:YRAVF
    syear = num2str(year);
    dnowout = [DIROUT, '/burn/', syear];

    for nm = 1:12
        monlen = datenum(year, nm+1, 01) - datenum(year, nm, 01);
        smon = num2str(nm, '%02u');

        fout = [dnowout, '/MiCASA_v', VERSION, '_burn_', CASARES, ...
            '_monthly_', syear, smon, '.nc4'];
        fins = [dnowout, '/MiCASA_v', VERSION, '_burn_', CASARES, ...
            '_daily_', syear, smon, '??.nc4'];

        % Skip if file exists and not reprocessing
        if isfile(fout)
             if REPRO
                [status, result] = system(['rm ', fout]);
            else
                continue;
            end
        end

        % Skip if we don't have a whole month (brutal hack)
        [status, result] = system(['ls -1 ', fins, ' | wc -l']);
        if status ~= 0 || ~strcmp(result(1:2), num2str(monlen))
            continue;
        end

        % Recall BA is a total
        [status, result] = system(['ncra -y ttl -O -h ', fins, ' ', fout]);

        time = datenum(year, nm, 1) - datenum(YSTART, 1, 1);

        % Fix time and time_bnds
        ncwriteatt(fout, 'time', 'cell_methods','time: minimum');
        ncwrite(fout,    'time', time);
        ncwriteatt(fout, 'time_bnds', 'cell_methods','time: minimum');
        ncwrite(fout,    'time_bnds', [time; time+monlen]);
    end
end
toc;
