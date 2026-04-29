% Numerical constants
% ---
RADIUS = 6371007.181;						% Radius of the Earth
Q10    = single(1.50);						% Effect of temperature on soil fluxes
TEMP0  = single(30.0);						% Temperature where Q10 function = 1
R10    = single(1.00);						% Effect of temperature on soil fluxes (unused for now)
aboveWoodFraction = single(0.80);				% Fraction of wood that is above ground
herbivoreEff      = single(0.50);				% Efficiency of herbivory (part autotrophic respiration, part to surface litter pools)

% Time configuration
% ---
spinUpYear1 = 250;
spinUpYear2 = 1750;
SOCadjustYear = 50;						% Number of years before startYear to adjust SOC

dvec = datevec(now);
startYear = 2001;						% First year with interannual data
endYear   = dvec(1);						% Last  year with interannual data
startYearClim = 2003;						% First year to use in climatology
endYearClim   = 2012;						% Last  year to use in climatology
startYearTime = 1980;						% First year to use in time stamp

% Run switches
% ---
do_daily = 'y';							% Run at a daily timestep (alternative is monthly)
do_spinup_stage1 = 'n';						% Do first  stage spin-up (as opposed to loading it)
do_spinup_stage2 = 'n';						% Do second stage spin-up (as opposed to loading it)
do_restart_load  = 'y';						% Load workspace to start

do_reprocess  = 'n';						% Reprocess/overwrite results
do_deprecated = 'n';						% Use deprecated functionality (for debugging, etc.)
do_soilm_bug  = 'n';						% Reproduce bug that allowed soil moisture to go negative
do_meteo_type = 'geosit';					% Meteorology type (merra2, geosit)

% Special cases
% ---
if strcmp(VERSION,'1')
    RADIUS = 6371000.000;					% Radius of the Earth
    do_soilm_bug  = 'y';					% Reproduce bug that allowed soil moisture to go negative
    do_meteo_type = 'merra2';					% Meteorology type (merra2, geosit)
end

if 5 < numel(runname) && strcmp(runname(end-5:end),'spinup')
    do_daily = 'n';						% Run at a daily timestep (alternative is monthly)
    do_spinup_stage1 = 'y';					% Do first  stage spin-up (as opposed to loading it)
    do_spinup_stage2 = 'y';					% Do second stage spin-up (as opposed to loading it)
    do_restart_load  = 'n';					% Load workspace to start
end

% MODIS/VIIRS input grid
% ---
dxmv = 0.1;
latmv = [ -90+dxmv/2:dxmv: 90-dxmv/2]';
lonmv = [-180+dxmv/2:dxmv:180-dxmv/2]';
NLATMV = numel(latmv);
NLONMV = numel(lonmv);
MODVRES = ['x', num2str(NLONMV), '_y', num2str(NLATMV)];	% Resolution tag for MODIS/VIIRS inputs

% Output grid
% ---
dx = 0.1;
lat = [ -90+dx/2:dx: 90-dx/2]';
lon = [-180+dx/2:dx:180-dx/2]';
NLAT = numel(lat);
NLON = numel(lon);
CASARES = ['x', num2str(NLON),   '_y', num2str(NLAT)];		% Resolution tag for CASA outputs
