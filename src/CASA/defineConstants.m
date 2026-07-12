% Error checking
% ---
if ~exist('runname', 'var')
    fprintf('You must specify the `runname` variable. Suggested options are:\n');
    fprintf('    * vNRT\n');
    fprintf('    * v1A/spinup\n');
    fprintf('    * v1A\n');
    fprintf('    * v1A-CONUS\n');
    error('The variable `runname` is undefined.');
end

% Constants
% ---
DAYSEC = 60.*60.*24.;						% Seconds in day

% Meteorology
% ---
% NB: This will only work on systems that already have MERRA-2 or GEOS IT
% *** This and makeNRTburn are the only Discover-specific bits left ***
DIRM2 = '/discover/nobackup/projects/gmao/merra2/data/pub/products/MERRA2_all';
DIRIT = '/discover/nobackup/projects/gmao/geos-it/dao_ops/archive';

% Need these defined in `defineConstants` for `lofi.make_3hrly_meteo`
% Using clear-sky (SWGDNCLR) instead of all-sky (SWGDN) values to represent growth under
% diffuse radiation: [Joiner et al. (2018)](https://10.3390/rs10091346)
VARSW = 'SWGDNCLR';
% Using surface skin temperature (TS). Other options include lowest model level (TLML),
% 2-meter (T2M), effective surface skin (TSH) temperature, surface temperature of
% saturated zone (TSAT), soil temperatures layer 1 (TSOIl1), etc. These choices have not
% been extensively tested. Likely it's more important to use matching soil textures.
VARTS = 'TS';

% Parse version info from runname
% ---
iver = find(runname == '-' | runname == '/', 1) - 1;
if isempty(iver), iver = numel(runname); end
icut = find(isletter([' ',runname(2:iver)]), 1) - 1;
if isempty(icut) || icut == 1, icut = iver; end

VERSION = runname(2:iver);					% Version number
VERCUT  = runname(2:icut);					% Version number w/o subletters

% Default directories (can be overwritten)
% ---
% This needs to be improved
if ~exist('DIRDATA', 'var')
    DIRDATA = ['../../data'];					% Directory under which all output goes
end
DIRAUX  = [DIRDATA, '/../data-aux'];				% Directory holding inputs to be regridded/etc.
DIRMODV = [DIRDATA, '/v', VERSION, '/drivers'];			% Directory holding MODIS/VIIRS driver data
DIRMAPS = [DIRDATA, '/v', VERSION, '/maps'];
DIRRUN  = [DIRDATA, '/', runname];

% Version-specific settings
% ---
if strcmp(VERCUT, 'NRT')
    defineConstants_vNRT;
elseif strcmp(VERCUT, '1')
    defineConstants_v1;
elseif strcmp(VERCUT, '0')
    defineConstants_v0;
else
    error(['Was unable to parse a valid version from the runname: ', runname]);
end

FORCE = lower(do_force(1)) == 'y';				% Force overwrite existing files?

% File output
% ---
FEXT    = 'nc4';
FORMAT  = 'netcdf4';
% We compress in post since it is very time consuming and Discover limits compute
% jobs to 24 hours
DEFLATE = 0;
SHUFFLE = false;
CONVENTIONS = 'CF-1.9';
INSTITUTION = 'NASA Goddard Space Flight Center';
CONTACT = 'Brad Weir <brad.weir@nasa.gov>';
PRODUCT = 'MiCASA';

% Variables for metadata
dotzero = @(xx) [num2str(xx), repmat('.0', floor(xx) == xx)];
RESLONG = [dotzero(lat(2) - lat(1)), ' degree x ', ...
    dotzero(lon(2) - lon(1)), ' degree'];
LATMIN = dotzero(lat(  1) - 0.5*(lat(2) - lat(1)));
LATMAX = dotzero(lat(end) + 0.5*(lat(2) - lat(1))); 
LONMIN = dotzero(lon(  1) - 0.5*(lon(2) - lon(1)));
LONMAX = dotzero(lon(end) + 0.5*(lon(2) - lon(1))); 
