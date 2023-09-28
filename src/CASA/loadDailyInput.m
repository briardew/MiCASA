addpath(DIRUTIL);

syear = datestr(dnum, 'yyyy');
smon  = datestr(dnum, 'mm');
sday  = datestr(dnum, 'dd');

% Read MODIS/VIIRS fPAR
fin = [DIRMODV, '/vegind/', syear, '/modvir_vegind.x', num2str(NLON), ...
    '_y', num2str(NLAT), '.daily.', syear, smon, sday, '.nc'];
FPAR = flipud(ncread(fin, 'fPAR')');

% Read MODIS/VIIRS burned area
fin = [DIRMODV, '/burn/', syear, '/modvir_burn.x', num2str(NLON), ...
    '_y', num2str(NLAT), '.daily.', syear, smon, sday, '.nc'];
BAdefo = flipud(ncread(fin, 'badefo')');
BAherb = flipud(ncread(fin, 'baherb')');
BAwood = flipud(ncread(fin, 'bawood')');

FPAR(isnan(FPAR)) = 0;
BAdefo(isnan(BAdefo)) = 0;
BAherb(isnan(BAherb)) = 0;
BAwood(isnan(BAwood)) = 0;

% Read MERRA-2
fm2 = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2.tavg1_2d_flx_Nx.', ...
       syear, smon, sday, '.nc4'];
airtm2 = ncread(fm2, 'TLML') - 273.15;				% Could also be TSH
%airtmo = ncread(fm2, 'TSH')  - 273.15;				% Could also be TLML
% nb changed scaling factor
pptm2  = ncread(fm2, 'PRECTOTCORR') * 60*60*24;

fm2 = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2.tavg1_2d_rad_Nx.', ...
       syear, smon, sday, '.nc4'];
solradm2 = ncread(fm2, 'SWGDN');

% Can remove/hard-code for speed, but here por robusto
latm2 = ncread(fm2, 'lat');
lonm2 = ncread(fm2, 'lon');

AIRT   = flipud(avgarea(latm2, lonm2, mean(airtm2,   3), lat, lon)');
PPT    = flipud(avgarea(latm2, lonm2, mean(pptm2,    3), lat, lon)');
SOLRAD = flipud(avgarea(latm2, lonm2, mean(solradm2, 3), lat, lon)');
