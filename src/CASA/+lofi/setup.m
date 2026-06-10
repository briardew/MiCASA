%SETUP  Define settings for LoFI fluxes

% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2020-01-01	Big redesign
%===============================================================================

% Run settings
% ---
defineConstants;
% Define climatology midpoint, make sure it's not a leap year
midYearClim = floor((startYearClim + endYearClim)/2);
if mod(midYearClim, 4) == 0 && (mod(midYearClim, 100) ~= 0 ...
    || mod(midYearClim, 400) == 0)
    midYearClim = midYearClim + 1;
end

FORCE  = lower(do_reprocess(1)) == 'y';			% Reprocess?
GCBTAG = '2023-v1.1';					% GCB version to use for sink size
% Land-ocean exchange via rivers and marginal seas (Pg C/year)
% 0.78 was used for MiCASA v1
% This value is on the high end of a considerable uncertainty; worth revisiting
RIVER  = 0.78;

% Product settings
% ---
FLUXHEAD = [PRODUCT, '_v', VERSION, '_flux_',  CASARES];
METHEAD  = [PRODUCT, '_v', VERSION, '_meteo_', CASARES, '_3hrly-climate_'];

% Environment settings
% ---
DIROUT = [DIRRUN, '/netcdf'];
DIRMET = [DIRRUN, '/drivers/meteo/climate'];		% Where to put climatological diurnal cycle

% Reanalysis files & grid data
% ---
fm2    = [DIRM2, '/MERRA2.const_2d_asm_Nx.00000000.nc4'];
latm2  = ncread(fm2, 'lat');
lonm2  = ncread(fm2, 'lon');
NLATM2 = numel(latm2);
NLONM2 = numel(lonm2);

% Constants
% ---
MASSDRY =  5.1352;					% x 10^18 kg
MOLMDRY =  28.965;					% kg/Kmole
MOLMC   =  12.011;
MOLMCO2 =  44.0098;					% MOLMC + 2*MOLMO
PPMTOPG = MOLMC/MOLMDRY*MASSDRY;
DAYSEC  = 60.*60.*24.;					% Seconds in day
