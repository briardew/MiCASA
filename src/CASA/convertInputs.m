%YEAR0 = 2003;
%YEARF = 2013;
YEAR0 = 2003;
YEARF = 2021;

lat = [-89.75:0.5:89.75]';
lon = [-179.75:0.5:179.75]';

addpath('/discover/nobackup/bweir/matlab/globutils');

DIRM2 = '/discover/nobackup/projects/gmao/merra2/data/pub/products/MERRA2_all';
NLAT  = numel(lat);
NLON  = numel(lon);

fin = [DIRM2, '/MERRA2.const_2d_asm_Nx.00000000.nc4'];
latm2 = double(ncread(fin, 'lat'));
lonm2 = double(ncread(fin, 'lon'));

for ny = YEAR0:YEARF
  syear = num2str(ny);

  AIRT   = zeros(NLAT, NLON, 12);
  PPT    = zeros(NLAT, NLON, 12);
  SOLRAD = zeros(NLAT, NLON, 12);
  FPAR   = zeros(NLAT, NLON, 12);
  SNOW   = zeros(NLAT, NLON, 12);
  BAdefo = zeros(NLAT, NLON, 12);
  BAherb = zeros(NLAT, NLON, 12);
  BAwood = zeros(NLAT, NLON, 12);

  for nm = 1:12
    smon  = num2str(nm, '%02u');
    ndays = datenum(ny, nm+1, 01) - datenum(ny, nm, 01);

%   Read MERRA-2
    fin = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2.tavgM_2d_flx_Nx.', ...
           syear, smon, '.nc4'];
    airtmo   = double(ncread(fin, 'TLML')) - 273.15;				% Could also be TSH
%   airtmo   = double(ncread(fin, 'TSH'))  - 273.15;				% Could also be TLML
    pptmo    = double(ncread(fin, 'PRECTOTCORR')) * 60*60*24*ndays;

    fin = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2.tavgM_2d_rad_Nx.', ...
           syear, smon, '.nc4'];
    solradmo = double(ncread(fin, 'SWGDN'));

    AIRT(:,:,nm)   = flipud(avgarea(latm2, lonm2, airtmo,   lat, lon)');
    PPT(:,:,nm)    = flipud(avgarea(latm2, lonm2, pptmo,    lat, lon)');
    SOLRAD(:,:,nm) = flipud(avgarea(latm2, lonm2, solradmo, lat, lon)');

%   Read MODVIR fPAR
    fin = ['MODVIR/output/modvir_nbar.x720_y360.monthly.', syear, smon, '.nc'];
    FPAR(:,:,nm) = flipud(double(ncread(fin, 'fPAR'))');
    SNOW(:,:,nm) = flipud(double(ncread(fin, 'snow'))');

%   Read MODVIR burned area
    fin = ['MODVIR/output/modvir_burn.x720_y360.monthly.', syear, smon, '.nc'];
    BAdefo(:,:,nm) = flipud(double(ncread(fin, 'badefo'))');
    BAherb(:,:,nm) = flipud(double(ncread(fin, 'baherb'))');
    BAwood(:,:,nm) = flipud(double(ncread(fin, 'bawood'))');
  end

  FPAR(isnan(FPAR)) = 0;
  SNOW(isnan(SNOW)) = 0;
  BAdefo(isnan(BAdefo)) = 0;
  BAherb(isnan(BAherb)) = 0;
  BAwood(isnan(BAwood)) = 0;

% Apply snow scaling to fPAR
  FPAR = FPAR .* (1 - SNOW);

  save(['data/annual/', syear, '/AIRT.mat'],   'AIRT');
  save(['data/annual/', syear, '/PPT.mat'],    'PPT');
  save(['data/annual/', syear, '/SOLRAD.mat'], 'SOLRAD');

  save(['data/annual/', syear, '/FPAR.mat'],   'FPAR');
  save(['data/annual/', syear, '/SNOW.mat'],   'SNOW');

  save(['data/annual/', syear, '/BAdefo.mat'], 'BAdefo');
  save(['data/annual/', syear, '/BAherb.mat'], 'BAherb');
  save(['data/annual/', syear, '/BAwood.mat'], 'BAwood');
end
