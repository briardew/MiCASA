%MAKE_SINK_PREP1  Compute growth rates for atmospheric correction to MiCASA

% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2024-05-16	Initial version
%
% TODO:
% * Write AIRT out from CASA, add to extras file, and process
%===============================================================================

lofi.setup;

% Read MERRA-2 temperatures (could be replaced)
% ---
syear = num2str(startYearClim - 1);
smon  = '12';
fm2   = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2.tavgM_2d_slv_Nx.', ...
    syear, smon, '.nc4'];
% Copying what's in CASA; bad practice; fixme?
airt0 = ncread(fm2, 'TS') - 273.15;

dtposm2 = zeros(NLONM2, NLATM2, 12);
dtnegm2 = zeros(NLONM2, NLATM2, 12);
for nyear = startYearClim:endYearClim
    syear = num2str(nyear);
    for nmon = 1:12
        smon = num2str(nmon, '%02u');
        fm2  = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2.tavgM_2d_slv_Nx.', ...
            syear, smon, '.nc4'];
        % Copying what's in CASA; bad practice; fixme?
        airtm2 = ncread(fm2, 'TS') - 273.15;

        dtposm2(:,:,nmon) = dtposm2(:,:,nmon) + max(airtm2 - airt0, 0)/10;
        dtnegm2(:,:,nmon) = dtnegm2(:,:,nmon) + min(airtm2 - airt0, 0)/10;
        airt0  = airtm2;
    end
end
dtposm2 = dtposm2/(endYearClim - startYearClim + 1);
dtnegm2 = dtnegm2/(endYearClim - startYearClim + 1);

% Regrid
% ---
[LA, LO] = meshgrid(lat, lon);
% Border protection
lonmx = [lonm2; 180];
[LAMX, LOMX] = meshgrid(latm2, lonmx);

dtposmx = [dtposm2; dtposm2(1,:,:)];
dtnegmx = [dtnegm2; dtnegm2(1,:,:)];

dtpos = zeros(NLON, NLAT, 12);
dtneg = zeros(NLON, NLAT, 12);
for nmon = 1:12
    dtpos(:,:,nmon) = interp2(LAMX, LOMX, dtposmx(:,:,nmon), LA, LO, 'linear');
    dtneg(:,:,nmon) = interp2(LAMX, LOMX, dtnegmx(:,:,nmon), LA, LO, 'linear');
end
