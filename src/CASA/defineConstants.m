% Pretty hacky for now
% Considering writing a Python entry point

% NB: This will only work on systems that already have MERRA-2 or GEOS IT
% AFAIK this is the only Discover-specific bit left
DIRM2 = '/discover/nobackup/projects/gmao/merra2/data/pub/products/MERRA2_all';
DIRIT = '/discover/nobackup/projects/gmao/geos-it/dao_ops/archive';

if ~exist('runname', 'var')
    error('Must specify the variable runname ...');
end

% NB: If we get to v10, have that conditional BEFORE v1
if min(strfind(runname, 'vNRT')) == 1
    runname = 'vNRT';
    defineConstants_vNRT;
elseif min(strfind(runname, 'v1')) == 1
    defineConstants_v1;
elseif min(strfind(runname, 'v0')) == 1
    defineConstants_v0;
end

REPRO = lower(do_reprocess(1)) == 'y';				% Reprocess/overwrite results

CASARES = ['x', num2str(NLON),   '_y', num2str(NLAT)];
MODVRES = ['x', num2str(NLONMV), '_y', num2str(NLATMV)];
