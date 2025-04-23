% Data directories
% ---
% Need to make more robust; for now, happy not referencing my own nobackup
DIRHEAD = '../..';
DIRCASA = [DIRHEAD, '/data'];
DIRAUX  = [DIRHEAD, '/data-aux'];

% NB: This will only work on systems that already have MERRA-2 or GEOS IT
DIRM2 = '/discover/nobackup/projects/gmao/merra2/data/pub/products/MERRA2_all';
DIRIT = '/discover/nobackup/projects/gmao/geos-it/dao_ops/archive';

% Define constants
% ---
RADIUS = 6371000.000;						% Radius of the Earth
Q10    = single(1.50);						% Effect of temperature on soil fluxes
TEMP0  = single(30.0);						% Temperature where Q10 function = 1
R10    = single(1.00);						% Effect of temperature on soil fluxes (unused for now)
aboveWoodFraction = single(0.80);				% Fraction of wood that is above ground
herbivoreEff      = single(0.50);				% Efficiency of herbivory (part autotrophic respiration, part to surface litter pools)

VERSION  = '0';							% Version number
do_daily = 'n';							% Run at a daily timestep (alternative is monthly)
do_reprocess  = 'n';						% Reprocess/overwrite results
do_deprecated = 'y';						% Use deprecated functionality (for debugging, etc.)
do_soilm_bug  = 'y';						% Reproduce bug that allowed soil moisture to go negative
do_nrt_meteo  = 'n';						% Use NRT meteorology?

do_spinup_stage1 = 'y';						% Do first  stage spin-up (as opposed to loading it)
do_spinup_stage2 = 'y';						% Do second stage spin-up (as opposed to loading it)
do_restart_all   = 'n';						% Save workspace at every non-spinup step (slow, for NRT)
do_restart_load  = 'y';						% Load workspace to start

spinUpYear1 = 250;
spinUpYear2 = 1750;
SOCadjustYear = 50;						% Number of years before startYear to adjust SOC

dvec = datevec(now);
startYear = 2001;						% First year with interannual data
endYear   = dvec(1);						% Last  year with interannual data
startYearClim = 2003;						% First year to use in climatology
endYearClim   = 2012;						% Last  year to use in climatology
startYearTime = 1980;						% First year to use in time stamp

% Grid variables for MODIS/VIIRS inputs
dxmv   = 0.1;
latmv  = [ -90+dxmv/2:dxmv: 90-dxmv/2]';
lonmv  = [-180+dxmv/2:dxmv:180-dxmv/2]';
NLATMV = numel(latmv);
NLONMV = numel(lonmv);

% Grid variables for outputs
dx   = 0.5;
lat  = [ -90+dx/2:dx: 90-dx/2]';
lon  = [-180+dx/2:dx:180-dx/2]';
NLAT = numel(lat);
NLON = numel(lon);

if strcmp(runname,'v0/original')
    do_daily = 'n';						% Run at a daily timestep (alternative is monthly)
    startYear = 2003;						% First year with interannual data
    endYear   = 2013;						% Last  year with interannual data
    startYearClim = 2003;					% First year to use in climatology
    endYearClim   = 2013;					% Last  year to use in climatology
end

% Auto-generate some folders
% There are no v0 MODIS/VIIRS files; use v1 for testing
DIRMODV = [DIRCASA, '/v1/drivers'];				% Driver data dir
