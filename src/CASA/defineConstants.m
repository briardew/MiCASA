% Data directories
% ---
DIRM2   = '/discover/nobackup/projects/gmao/merra2/data/pub/products/MERRA2_all';
DIRIT   = '/discover/nobackup/projects/gmao/geos-it/dao_ops/archive';
DIRMODV = '/discover/nobackup/bweir/MiCASA/data';
DIRCASA = '/discover/nobackup/bweir/MiCASA/data-casa';
DIRAUX  = '/discover/nobackup/bweir/MiCASA/data-aux';

% Define constants
% ---
Q10   = single(1.50);				% Effect of temperature on soil fluxes
TEMP0 = single(30.0);				% Temperature where Q10 function = 1
R10   = single(1.00);				% Effect of temperature on soil fluxes (unused for now)
aboveWoodFraction = single(0.80);		% Fraction of wood that is above ground
herbivoreEff      = single(0.50);		% Efficiency of herbivory (part autotrophic respiration, part to surface litter pools)

% Defaults
% ---
do_daily = 'y';					% Run at a daily timestep (alternative is monthly)
do_reprocess  = 'n';				% Reprocess/overwrite results
do_deprecated = 'n';				% Use deprecated functionality (for debugging, etc.)
do_soilm_bug  = 'n';				% Reproduce bug that allowed soil moisture to go negative
do_nrt_meteo  = 'n';				% Use NRT meteorology?
use_sink = 'y';					% Apply crop sink (recommended 'y', may deprecate 'n')
use_crop_moisture  = 'n';			% Remove moisture limitation over indicated areas (recommended 'n', may deprecate 'y')
use_crop_ppt_ratio = 'n';			

do_spinup_stage1 = 'y';				% Do first  stage spin-up (as opposed to loading it)
do_spinup_stage2 = 'y';				% Do second stage spin-up (as opposed to loading it)
do_restart_all   = 'n';				% Save workspace at every non-spinup step (slow, for NRT)
do_restart_load  = 'n';				% Load workspace to start

spinUpYear1 = 250;
spinUpYear2 = 1750;
SOCadjustYear = 50;				% Number of years before startYear to adjust SOC

startYear = 2001;				% First year with interannual data
endYear   = 2023;				% Last  year with interannual data
startYearClim = 2003;				% First year to use in climatology
endYearClim   = 2012;				% Last  year to use in climatology
startYearTime = 1980;				% First year to use in time stamp

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

% RUN-SPECIFIC
% ---
runname = 'daily-0.1deg-nrt';
DIRMODV = '/discover/nobackup/bweir/MiCASA/data-nrt';
do_reprocess = 'n';				
do_soilm_bug = 'y';				% Reproduce bug that allowed soil moisture to go negative
do_nrt_meteo = 'y';				%
do_spinup_stage1 = 'n';				% Do first  stage spin-up (as opposed to loading it)
do_spinup_stage2 = 'n';				% Do second stage spin-up (as opposed to loading it)
do_restart_load  = 'y';				% Load workspace to start
do_restart_all   = 'y';				% Save workspace at every non-spinup step (slow, for NRT)
startYear = 2024;				% First year with interannual data
endYear   = 2024;				% Last  year with interannual data

%runname = 'daily-0.1deg-new';
%do_spinup_stage1 = 'n';			% Do first  stage spin-up (as opposed to loading it)
%do_spinup_stage2 = 'n';			% Do second stage spin-up (as opposed to loading it)
%do_restart_load  = 'y';			% Load workspace to start
%do_restart_all   = 'y';			% Save workspace at every non-spinup step (slow, for NRT)
%do_soilm_bug = 'y';				% Reproduce bug that allowed soil moisture to go negative
%startYear = 2024;				% First year with interannual data
%endYear   = 2024;				% Last  year with interannual data

% Runs needed to reproduce above
% NB: Spin-up is done at monthly
% ---
%runname = 'daily-0.1deg';
%do_spinup_stage1 = 'n';			% Do first  stage spin-up (as opposed to loading it)
%do_spinup_stage2 = 'n';			% Do second stage spin-up (as opposed to loading it)
%do_restart_load  = 'y';			% Load workspace to start
%do_soilm_bug = 'y';				% Reproduce bug that allowed soil moisture to go negative

%runname = 'monthly-0.1deg';
%do_daily = 'n';				% Run at a daily timestep (alternative is monthly)

% Runs for testing changes/reproducibility
% ---
%runname = 'monthly-0.5deg';
%dx   = 0.5;
%lat  = [ -90+dx/2:dx: 90-dx/2]';
%lon  = [-180+dx/2:dx:180-dx/2]';
%NLAT = numel(lat);
%NLON = numel(lon);
%do_daily = 'n';				% Run at a daily timestep (alternative is monthly)
%% Need to fix BA regridding
%startYear = 2003;				% First year with interannual data
%endYear   = 2013;				% Last  year with interannual data

%runname = 'original-0.5deg';
%dx   = 0.5;
%lat  = [ -90+dx/2:dx: 90-dx/2]';
%lon  = [-180+dx/2:dx:180-dx/2]';
%NLAT = numel(lat);
%NLON = numel(lon);
%do_daily = 'n';				% Run at a daily timestep (alternative is monthly)
%do_deprecated = 'y';				% Use deprecated functionality (for debugging, etc.)
%use_crop_moisture  = 'y';			% Remove moisture limitation over indicated areas (recommended 'n', may deprecate 'y')
%startYear = 2003;				% First year with interannual data
%endYear   = 2013;				% Last  year with interannual data
%startYearClim = 2003;				% First year to use in climatology
%endYearClim   = 2013;				% Last  year to use in climatology

DIRNAT = [DIRCASA, '/', runname, '/native'];
if ~isfolder(DIRNAT)
    [status, result] = system(['mkdir -p ', DIRNAT]);
end
