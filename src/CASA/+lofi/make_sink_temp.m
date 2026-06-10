%MAKE_SINK_TEMP  Compute temperature term for atmospheric correction to MiCASA

% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2024-05-16	Initial version
% 2026-06-10	New version, reads pre-computed fields, non zero-diff
%
% TODO:
%===============================================================================

lofi.setup;

syear = num2str(startYearClim - 1);
load([DIRMAPS, '/annual/', syear, '/AIRT.mat']);
airt0 = flipud(AIRT(:,:,12))';

dtpos = zeros(NLON, NLAT, 12);
dtneg = zeros(NLON, NLAT, 12);
for nyear = startYearClim:endYearClim
    syear = num2str(nyear);
    load([DIRMAPS, '/annual/', syear, '/AIRT.mat']);

    for nmon = 1:12
        airt1 = flipud(AIRT(:,:,nmon))';
        dtpos(:,:,nmon) = dtpos(:,:,nmon) + max(airt1 - airt0, 0)/10;
        dtneg(:,:,nmon) = dtneg(:,:,nmon) + min(airt1 - airt0, 0)/10;
        airt0 = airt1;
    end
end
dtpos = dtpos/(endYearClim - startYearClim + 1);
dtneg = dtneg/(endYearClim - startYearClim + 1);
