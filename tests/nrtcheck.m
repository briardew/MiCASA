% User settings
YEAR0 = 2001;
YEARF = 2023;
TOTYRS = YEARF - YEAR0 + 1;
LASTMO = 9;

VERSION = 1;

EHEAD = '/discover/nobackup/bweir/MiCASA/data-casa/daily-0.1deg-final/holding/monthly';
EHNRT = '/discover/nobackup/ghg_ops/MiCASA/data-casa/daily-0.1deg-nrt/holding/monthly';

AHEAD = '/discover/nobackup/bweir/MiCASA/data';
AHNRT = '/discover/nobackup/ghg_ops/MiCASA/data-nrt';

DHEAD = '/discover/nobackup/ghg_ops/MiCASA/data-casa/daily-0.1deg-nrt/holding/daily';

% After running, you can check the NRT year (bolded) with commands like:
%     > plot(firemo(1:end-1,:)', '.-');
%     > hold on; plot(firemo(end,:)', 'k*-', 'linewidth', 2); hold off

%==============================================================================
% Environment setup, error checking
addpath('/discover/nobackup/bweir/matlab/globutils');

% Define useful constants
SVER = num2str(VERSION);
STAG = 'flux_x3600_y1800_monthly';

% Get spatial data
syear = num2str(YEAR0); nmo = 1;
ff = [EHEAD, '/', syear, '/MiCASA_v', SVER, '_', STAG, '_', ...
    syear, num2str(nmo,'%02u'), '.nc4'];
lat = ncread(ff, 'lat');
lon = ncread(ff, 'lon');
area = globarea(lat, lon);				% from /discover/nobackup/bweir/matlab/globutils
NLAT = numel(lat);
NLON = numel(lon);

% Initialize arrays
nppmo  = zeros(TOTYRS, 12);				% Net primary productivity
hetrmo = zeros(TOTYRS, 12);				% Heterotrophic respiration
firemo = zeros(TOTYRS, 12);				% Fire emissions
fuelmo = zeros(TOTYRS, 12);				% Fuel wood burning
burnmo = zeros(TOTYRS, 12);				% Burned area

nppclim  = zeros(NLON, NLAT, 12);			% Net primary productivity
hetrclim = zeros(NLON, NLAT, 12);			% Heterotrophic respiration
fireclim = zeros(NLON, NLAT, 12);			% Fire emissions
fuelclim = zeros(NLON, NLAT, 12);			% Fuel wood burning
burnclim = zeros(NLON, NLAT, 12);			% Burned area

% Read retrospective years
for year = YEAR0:YEARF
    syear = num2str(year);
    for nmo = 1:12
        ff = [EHEAD, '/', syear, '/MiCASA_v', SVER, '_', STAG, '_', ...
            syear, num2str(nmo,'%02u'), '.nc4'];
        xxin = ncread(ff, 'NPP');
        nppmo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));
        nppclim(:,:,nmo) = nppclim(:,:,nmo) + xxin;

        xxin = ncread(ff, 'Rh');
        hetrmo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));
        hetrclim(:,:,nmo) = hetrclim(:,:,nmo) + xxin;

        xxin = ncread(ff, 'FIRE');
        firemo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));
        fireclim(:,:,nmo) = fireclim(:,:,nmo) + xxin;

        xxin = ncread(ff, 'FUEL');
        fuelmo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));
        fuelclim(:,:,nmo) = fuelclim(:,:,nmo) + xxin;

        ff = [AHEAD, '/burn/', syear, '/modvir_burn.x3600_y1800.monthly.', ...
            syear, num2str(nmo,'%02u'), '.nc'];
        xxin = ncread(ff, 'batot');
        burnmo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));
        burnclim(:,:,nmo) = burnclim(:,:,nmo) + xxin;
    end
end
nppclim  =  nppclim / (YEARF - YEAR0 + 1);
hetrclim = hetrclim / (YEARF - YEAR0 + 1);
fireclim = fireclim / (YEARF - YEAR0 + 1);
fuelclim = fuelclim / (YEARF - YEAR0 + 1);
burnclim = burnclim / (YEARF - YEAR0 + 1);

% Read NRT year
year = 2024;
syear = num2str(year);
for nmo = 1:LASTMO
    ff = [EHEAD, '/', syear, '/MiCASA_v', SVER, '_', STAG, '_', ...
        syear, num2str(nmo,'%02u'), '.nc4'];
    xxin = ncread(ff, 'NPP');
    nppmo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));

    xxin = ncread(ff, 'Rh');
    hetrmo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));

    xxin = ncread(ff, 'FIRE');
    firemo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));

    xxin = ncread(ff, 'FUEL');
    fuelmo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));

    ff = [AHEAD, '/burn/', syear, '/modvir_burn.x3600_y1800.monthly.', ...
        syear, num2str(nmo,'%02u'), '.nc'];
    xxin = ncread(ff, 'batot');
    burnmo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));
end
for nmo = LASTMO+1:12
    ff = [EHNRT, '/', syear, '/MiCASA_v', 'NRT', '_', STAG, '_', ...
        syear, num2str(nmo,'%02u'), '.nc4'];
    xxin = ncread(ff, 'NPP');
    nppmo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));

    xxin = ncread(ff, 'Rh');
    hetrmo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));

    xxin = ncread(ff, 'FIRE');
    firemo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));

    xxin = ncread(ff, 'FUEL');
    fuelmo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));

    ff = [AHNRT, '/burn/', syear, '/modvir_burn.x3600_y1800.monthly.', ...
        syear, num2str(nmo,'%02u'), '.nc'];
    xxin = ncread(ff, 'batot');
    burnmo(year-YEAR0+1,nmo) = sum(sum( area.*xxin ));
end

nmo = LASTMO+1;
smo = num2str(nmo, '%02u');
molen   = datenum(year,nmo+1,01) - datenum(year,nmo,01);
fireday = zeros(molen, 1);
burnday = zeros(molen, 1);
for nd = 1:molen
    ff = [EHNRT, '/', syear, '/', smo, '/MiCASA_vNRT_flux_x3600_y1800_daily_', ...
        syear, smo, num2str(nd,'%02u'), '.nc4'];
    xxin = ncread(ff, 'FIRE');
    fireday(nd) = sum(sum( area.*xxin ));

    ff = [AHNRT, '/burn/', syear, '/modvir_burn.x3600_y1800.daily.', ...
        syear, smo, num2str(nd,'%02u'), '.nc'];
    xxin = ncread(ff, 'batot');
    burnday(nd) = sum(sum( area.*xxin ));
end
