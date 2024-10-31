% Data directories
% ---
DIRM2   = '/discover/nobackup/projects/gmao/merra2/data/pub/products/MERRA2_all';
DIRMODV = '/discover/nobackup/bweir/MiCASA/data';
DIRCASA = '/discover/nobackup/bweir/MiCASA/data-casa';
DIRAUX  = '/discover/nobackup/bweir/MiCASA/data-aux';

% Define constants
% ---
Q10               = single(1.50);		% Effect of temperature on soil fluxes
TEMP0             = single(30.0);		% Temperature where Q10 function = 1
R10               = single(1.00);		% Effect of temperature on soil fluxes (unused for now)
aboveWoodFraction = single(0.80);		% Fraction of wood that is above ground
herbivoreEff      = single(0.50);		% Efficiency of herbivory (part autotrophic respiration, part to surface litter pools)

%%% DEFAULTS
do_deprecated = 'n';				% Use deprecated functionality (for debugging, etc.)
use_sink = 'y';					% Apply crop sink (recommended 'y', may deprecate 'n')
use_crop_moisture  = 'n';			% Remove moisture limitation over indicated areas (recommended 'n', may deprecate 'y')
use_crop_ppt_ratio = 'n';			
do_soilm_bug = 'n';				% Reproduce bug that allowed soil moisture to go negative

do_spinup_stage1 = 'y';				% Do first  stage spin-up (as opposed to loading it)
do_spinup_stage2 = 'y';				% Do second stage spin-up (as opposed to loading it)
do_restart_all   = 'n';				% Save workspace at every non-spinup step (slow, for NRT)
do_restart_load  = 'n';				% Load workspace to start

spinUpYear1   = 250;
spinUpYear2   = 1750;
SOCadjustYear = 50;				% Number of years before startYear to adjust SOC

startYear = 2001;				% First year with interannual data
endYear   = 2023;				% Last  year with interannual data
startYearClim = 2003;				% First year to use in climatology
endYearClim   = 2012;				% Last  year to use in climatology

% Grid variables for MODIS/VIIRS inputs
dxmv  = 0.1;
latmv = [ -90+dxmv/2:dxmv: 90-dxmv/2]';
lonmv = [-180+dxmv/2:dxmv:180-dxmv/2]';
NLATMV = numel(latmv);
NLONMV = numel(lonmv);


%%% RUN-SPECIFIC
runname = 'daily-0.1deg-new';
dx = 0.1;
lat = [ -90+dx/2:dx: 90-dx/2]';
lon = [-180+dx/2:dx:180-dx/2]';
NLAT = numel(lat);
NLON = numel(lon);
do_daily = 'y';
do_spinup_stage1 = 'n';				% Do first  stage spin-up (as opposed to loading it)
do_spinup_stage2 = 'n';				% Do second stage spin-up (as opposed to loading it)
do_restart_load  = 'y';				% Load workspace to start
endYear   = 2024;				% Last  year with interannual data

%% Keep here for reproducibility
%runname = 'daily-0.1deg';
%dx = 0.1;
%lat = [ -90+dx/2:dx: 90-dx/2]';
%lon = [-180+dx/2:dx:180-dx/2]';
%NLAT = numel(lat);
%NLON = numel(lon);
%do_daily = 'y';
%do_spinup_stage1 = 'n';				% Do first  stage spin-up (as opposed to loading it)
%do_spinup_stage2 = 'n';				% Do second stage spin-up (as opposed to loading it)
%do_restart_load  = 'y';				% Load workspace to start
%do_soilm_bug = 'y';					% Reproduce bug that allowed soil moisture to go negative

%runname = 'monthly-0.1deg';
%dx = 0.1;
%lat = [ -90+dx/2:dx: 90-dx/2]';
%lon = [-180+dx/2:dx:180-dx/2]';
%NLAT = numel(lat);
%NLON = numel(lon);
%do_daily = 'n';

%runname = 'monthly-0.5deg';
%dx = 0.5;
%lat = [ -90+dx/2:dx: 90-dx/2]';
%lon = [-180+dx/2:dx:180-dx/2]';
%NLAT = numel(lat);
%NLON = numel(lon);
%do_daily = 'n';
%% Need to fix BA regridding
%startYear     = 2003;					% First year with interannual data
%endYear       = 2013;					% Last  year with interannual data

%runname = 'original-0.5deg';
%dx = 0.5;
%lat = [ -90+dx/2:dx: 90-dx/2]';
%lon = [-180+dx/2:dx:180-dx/2]';
%NLAT = numel(lat);
%NLON = numel(lon);
%do_deprecated = 'y';
%do_daily = 'n';
%use_crop_moisture = 'y';
%startYear     = 2003;					% First year with interannual data
%endYear       = 2013;					% Last  year with interannual data
%startYearClim = 2003;					% First year to use in climatology
%endYearClim   = 2013;					% Last  year to use in climatology

DIRNAT = [DIRCASA, '/', runname, '/native'];
if ~isfolder(DIRNAT)
    [status, result] = system(['mkdir -p ', DIRNAT]);
end
