DIRM2   = '/discover/nobackup/projects/gmao/merra2/data/pub/products/MERRA2_all';
DIRMODV = '/discover/nobackup/bweir/miCASA/data';
DIRCASA = '/discover/nobackup/bweir/miCASA/data-casa';
DIRUTIL = '/discover/nobackup/bweir/miCASA/utils';		% Needed for regridding (avgarea)

% Define constants
%comment out spinUpYear here, and assign it in the new spin up section of CASA.m
%spinUpYear          = single(1750);     % First year (1750)
startYear           = single(2003);     % First year with interannual data
endYear             = single(2021);     % Last year
SOCadjustYear       = single(50);       % number of years before startYear to adjust SOC

Q10                 = single(1.50);     % effect of temperature on soil fluxes

%ai
%remove EMAX constant as it will be replaced by a spatially varying EMAX,
%as was done with the previous version of CASA
%change:  leave EMAX defined so that it can be either constant or spatially
%varying, depending on the switch "use_cropstate_emax"
EMAX                = single(0.50);     % Maximum Light Use Efficiency

%ai 11/28/2011
%comment out EMAX since it is used in the mc simulation.

aboveWoodFraction   = single(0.80);     % fraction of wood that is above ground
herbivoreEff        = single(0.50);     % efficiency of herbivory (part autotrophic respiration, part to surface litter pools)

%runname = 'monthly-0.5deg';
%dx = 0.5;
%lat = [-90+dx/2:dx:90-dx/2]';
%lon = [-180+dx/2:dx:180-dx/2]';
%NLAT = numel(lat);
%NLON = numel(lon);
%do_daily = 'n';

runname = 'monthly-0.1deg';
dx = 0.1;
lat = [-90+dx/2:dx:90-dx/2]';
lon = [-180+dx/2:dx:180-dx/2]';
NLAT = numel(lat);
NLON = numel(lon);
do_daily = 'n';

%runname = 'daily-0.1deg';
%dx = 0.1;
%lat = [-90+dx/2:dx:90-dx/2]';
%lon = [-180+dx/2:dx:180-dx/2]';
%NLAT = numel(lat);
%NLON = numel(lon);
%do_daily = 'y';

do_spinup_stage1 = 'y';
do_spinup_stage2 = 'y';
%do_spinup_stage1 = 'n';
%do_spinup_stage2 = 'n';

spinUpYear_stage1 = 250;
spinUpYear_stage2 = 1750;

use_cropstate_emax = 'y';
use_sink = 'y';
use_crop_moisture = 'y';
use_crop_ppt_ratio = 'y';

spinUpYear   = single(spinUpYear_stage1);
spinUpYear_2 = single(spinUpYear_stage2);

