% NB: This will only work on systems that already have MERRA-2 or GEOS IT
% ***This and makeNRTburn are the only Discover-specific bits left***
DIRM2 = '/discover/nobackup/projects/gmao/merra2/data/pub/products/MERRA2_all';
DIRIT = '/discover/nobackup/projects/gmao/geos-it/dao_ops/archive';

if ~exist('runname', 'var')
    fprintf('You must specify the `runname` variable. Suggested options are:\n');
    fprintf('    * vNRT\n');
    fprintf('    * v1A/spinup\n');
    fprintf('    * v1A\n');
    fprintf('    * v1A-CONUS\n');
    error('The variable `runname` is undefined.');
end

% Parse version info from runname
% ---
iver = find(runname == '-' | runname == '/', 1) - 1;
if isempty(iver), iver = numel(runname); end
icut = find(isletter([' ',runname(2:end)]), 1) - 1;
if isempty(icut) || icut == 1, icut = numel(runname); end

VERSION = runname(2:iver);					% Version number
VERCUT  = runname(2:icut);					% Version number w/o subletters

% Default directories (can be overwritten)
% ---
DIRHEAD = '../..';						% Head directory (needs improvement; could be worse)
DIRDATA = [DIRHEAD, '/data'];					% Directory under which all output goes
DIRAUX  = [DIRHEAD, '/data-aux'];				% Directory holding inputs to be regridded/etc.
DIRMODV = [DIRDATA, '/v', VERSION, '/drivers'];			% Directory holding MODIS/VIIRS driver data
DIRMAPS = [DIRDATA, '/v', VERSION, '/maps'];
DIRRUN  = [DIRDATA, '/', runname];

if strcmp(VERCUT, 'NRT')
    defineConstants_vNRT;
elseif strcmp(VERCUT, '1')
    defineConstants_v1;
elseif strcmp(VERCUT, '0')
    defineConstants_v0;
else
    error(['Was unable to parse a valid version from the runname: ', runname]);
end

REPRO = lower(do_reprocess(1)) == 'y';				% Reprocess/overwrite results
