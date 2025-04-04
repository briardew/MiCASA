% Pretty hacky for now
% Considering writing a Python entry point

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
