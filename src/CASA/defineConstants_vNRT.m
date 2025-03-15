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
RADIUS = 6371007.181;						% Radius of the Earth
Q10    = single(1.50);						% Effect of temperature on soil fluxes
TEMP0  = single(30.0);						% Temperature where Q10 function = 1
R10    = single(1.00);						% Effect of temperature on soil fluxes (unused for now)
aboveWoodFraction = single(0.80);				% Fraction of wood that is above ground
herbivoreEff      = single(0.50);				% Efficiency of herbivory (part autotrophic respiration, part to surface litter pools)

VERSION  = 'NRT';						% Version number
do_daily = 'y';							% Run at a daily timestep (alternative is monthly)
do_reprocess  = 'n';						% Reprocess/overwrite results
do_deprecated = 'n';						% Use deprecated functionality (for debugging, etc.)
do_soilm_bug  = 'y';						% Reproduce bug that allowed soil moisture to go negative
do_nrt_meteo  = 'y';						% Use NRT meteorology?

do_spinup_stage1 = 'n';						% Do first  stage spin-up (as opposed to loading it)
do_spinup_stage2 = 'n';						% Do second stage spin-up (as opposed to loading it)
do_restart_all   = 'y';						% Save workspace at every non-spinup step (slow, for NRT)
do_restart_load  = 'y';						% Load workspace to start

spinUpYear1 = 250;
spinUpYear2 = 1750;
SOCadjustYear = 50;						% Number of years before startYear to adjust SOC

dvec = datevec(now);
startYear = 2024;						% First year with interannual data
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
dx   = 0.1;
lat  = [ -90+dx/2:dx: 90-dx/2]';
lon  = [-180+dx/2:dx:180-dx/2]';
NLAT = numel(lat);
NLON = numel(lon);

% Auto-generate some folders
DIRMODV = [DIRCASA, '/v', VERSION, '/drivers'];			% Driver data dir
