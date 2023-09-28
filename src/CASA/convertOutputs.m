defineConstants;
addpath(DIRUTIL);

DIRIN  = [DIRCASA, '/', runname, '/native'];
DIROUT = [DIRCASA, '/', runname];
YEAR0  = 2003;
YEARF  = 2004;
ADDHER = 1;

% Begin
if ADDHER, disp('Adding HERBV to RH ...'); end

vaux = load([DIRIN, '/latestrunSpinUpData_stage1.mat']);

% For extracting variables
mask = vaux.mask';
inds = find(mask(:) == 1);

test = zeros(size(mask));
test(inds) = vaux.latitude;
test = fliplr(test);

NPP1   = zeros(size(mask));
RH1    = zeros(size(mask));
HERBV1 = zeros(size(mask));
FUEL1  = zeros(size(mask));
FIRE1  = zeros(size(mask));
SOILM1 = zeros(size(mask));

NPP   = zeros(NLON, NLAT, 12);
RH    = zeros(NLON, NLAT, 12);
HERBV = zeros(NLON, NLAT, 12);
FUEL  = zeros(NLON, NLAT, 12);
FIRE  = zeros(NLON, NLAT, 12);
SOILM = zeros(NLON, NLAT, 12);

for ny = YEAR0:YEARF
    syear = num2str(ny);

    load([DIRIN, '/NPP', syear, '.mat']);
    load([DIRIN, '/RES', syear, '.mat']);
    load([DIRIN, '/HER', syear, '.mat']);
    load([DIRIN, '/FUE', syear, '.mat']);

    load([DIRIN, '/COMdefo', syear, '.mat']);
    load([DIRIN, '/COMherb', syear, '.mat']);
    load([DIRIN, '/COMpeat', syear, '.mat']);
    load([DIRIN, '/COMwood', syear, '.mat']);

    load([DIRIN, '/soilm', syear, '.mat']);

    NPP2   = eval(['NPP',syear]);
    RH2    = eval(['RES',syear]);
    HERBV2 = eval(['HER',syear]);
    FUEL2  = eval(['FUE',syear]);
    FIRE2  = eval(['COMdefo',syear]) + eval(['COMherb',syear]) + ...
             eval(['COMpeat',syear]) + eval(['COMwood',syear]);
    SOILM2 = eval(['soilm',syear]);

    % Reshape
    for nm = 1:12
      NPP1(inds)   = NPP2(:,nm);
      RH1(inds)    = RH2(:,nm);
      HERBV1(inds) = HERBV2(:,nm);
      FUEL1(inds)  = FUEL2(:,nm);
      FIRE1(inds)  = FIRE2(:,nm);
      SOILM1(inds) = SOILM2(:,nm);

      NPP(:,:,nm)   = fliplr(NPP1);
      RH(:,:,nm)    = fliplr(RH1);
      HERBV(:,:,nm) = fliplr(HERBV1);
      FUEL(:,:,nm)  = fliplr(FUEL1);
      FIRE(:,:,nm)  = fliplr(FIRE1);
      SOILM(:,:,nm) = fliplr(SOILM1);
    end

    if ADDHER, RH = RH + HERBV; end

    % Clean up
    clear ['NPP',syear] ['RES',syear] ['FUE',syear] ['HER',syear];
    clear ['COMdefo',syear] ['COMherb',syear];
    clear ['COMpeat',syear] ['COMwood',syear];
    clear ['SOILM',syear];

    % NPP
    % ---
    fout = [DIROUT, '/NPP.monthly.x', num2str(NLON), '_y', num2str(NLAT), ...
        '.', syear, '.nc'];
    vout = 'NPP';

    idnc = netcdf.create(fout, 'clobber');
    netcdf.close(idnc);

    ncwriteatt(fout, '/', 'flux_variable_description', 'Net Primary Productivity');
    ncwriteatt(fout, '/', 'CO2_flux_unit', 'gC/m2/month');
    ncwriteatt(fout, '/', 'CO2_flux_sign', '+: uptake to vegetation');
    ncwriteatt(fout, '/', 'Time_Interval', 'month, mid-point');

    nccreate(  fout, 'lat',  'dimensions', {'lat', NLAT});
    ncwriteatt(fout, 'lat',  'units',      'degrees_north');
    ncwriteatt(fout, 'lat',  'long_name',  'latitude');
    ncwrite(   fout, 'lat',  lat);

    nccreate(  fout, 'lon',  'dimensions', {'lon', NLON});
    ncwriteatt(fout, 'lon',  'units',      'degrees_east');
    ncwriteatt(fout, 'lon',  'long_name',  'longitude');
    ncwrite(   fout, 'lon',  lon);

    nccreate(  fout, 'month', 'dimensions',     {'month', 12});

    nccreate(  fout, vout, 'dimensions',       ...
               {'lon', NLON, 'lat', NLAT, 'month', 12});
    ncwrite(   fout, vout, NPP);

    % RH
    % --
    fout = [DIROUT, '/RH.monthly.0.5x0.5.', syear, '.nc'];
    vout = 'RH';

    idnc = netcdf.create(fout, 'clobber');
    netcdf.close(idnc);

    ncwriteatt(fout, '/', 'flux_variable_description', 'Heterotrophic Respiration');
    ncwriteatt(fout, '/', 'CO2_flux_unit', 'gC/m2/month');
    ncwriteatt(fout, '/', 'CO2_flux_sign', '+: emission to atmosphere');
    ncwriteatt(fout, '/', 'Time_Interval', 'month, mid-point');

    nccreate(  fout, 'lat',  'dimensions', {'lat', NLAT});
    ncwriteatt(fout, 'lat',  'units',      'degrees_north');
    ncwriteatt(fout, 'lat',  'long_name',  'latitude');
    ncwrite(   fout, 'lat',  lat);

    nccreate(  fout, 'lon',  'dimensions', {'lon', NLON});
    ncwriteatt(fout, 'lon',  'units',      'degrees_east');
    ncwriteatt(fout, 'lon',  'long_name',  'longitude');
    ncwrite(   fout, 'lon',  lon);

    nccreate(  fout, 'month', 'dimensions',     {'month', 12});

    nccreate(  fout, vout, 'dimensions',       ...
               {'lon', NLON, 'lat', NLAT, 'month', 12});
    ncwrite(   fout, vout, RH);

    % HERBV
    % -----
    fout = [DIROUT, '/HERBV.monthly.0.5x0.5.', syear, '.nc'];
    vout = 'HERBV';

    idnc = netcdf.create(fout, 'clobber');
    netcdf.close(idnc);

    ncwriteatt(fout, '/', 'flux_variable_description', 'Herbivory Emission');
    ncwriteatt(fout, '/', 'CO2_flux_unit', 'gC/m2/month');
    ncwriteatt(fout, '/', 'CO2_flux_sign', '+: emission to atmosphere');
    ncwriteatt(fout, '/', 'Time_Interval', 'month, mid-point');

    nccreate(  fout, 'lat',  'dimensions', {'lat', NLAT});
    ncwriteatt(fout, 'lat',  'units',      'degrees_north');
    ncwriteatt(fout, 'lat',  'long_name',  'latitude');
    ncwrite(   fout, 'lat',  lat);

    nccreate(  fout, 'lon',  'dimensions', {'lon', NLON});
    ncwriteatt(fout, 'lon',  'units',      'degrees_east');
    ncwriteatt(fout, 'lon',  'long_name',  'longitude');
    ncwrite(   fout, 'lon',  lon);

    nccreate(  fout, 'month', 'dimensions', {'month', 12});

    nccreate(  fout, vout, 'dimensions',       ...
               {'lon', NLON, 'lat', NLAT, 'month', 12});
    ncwrite(   fout, vout, HERBV);

    % FUEL
    % ----
    fout = [DIROUT, '/FUEL.monthly.0.5x0.5.', syear, '.nc'];
    vout = 'FUEL';

    idnc = netcdf.create(fout, 'clobber');
    netcdf.close(idnc);

    ncwriteatt(fout, '/', 'flux_variable_description', 'Fuel Wood Emission');
    ncwriteatt(fout, '/', 'CO2_flux_unit', 'gC/m2/month');
    ncwriteatt(fout, '/', 'CO2_flux_sign', '+: emission to atmosphere');
    ncwriteatt(fout, '/', 'Time_Interval', 'month, mid-point');

    nccreate(  fout, 'lat',  'dimensions', {'lat', NLAT});
    ncwriteatt(fout, 'lat',  'units',      'degrees_north');
    ncwriteatt(fout, 'lat',  'long_name',  'latitude');
    ncwrite(   fout, 'lat',  lat);

    nccreate(  fout, 'lon',  'dimensions', {'lon', NLON});
    ncwriteatt(fout, 'lon',  'units',      'degrees_east');
    ncwriteatt(fout, 'lon',  'long_name',  'longitude');
    ncwrite(   fout, 'lon',  lon);

    nccreate(  fout, 'month', 'dimensions', {'month', 12});

    nccreate(  fout, vout, 'dimensions',       ...
               {'lon', NLON, 'lat', NLAT, 'month', 12});
    ncwrite(   fout, vout, FUEL);

    % FIRE
    % ----
    fout = [DIROUT, '/FIRE.monthly.0.5x0.5.', syear, '.nc'];
    vout = 'FIRE';

    idnc = netcdf.create(fout, 'clobber');
    netcdf.close(idnc);

    ncwriteatt(fout, '/', 'flux_variable_description', 'Wild Fire Emission');
    ncwriteatt(fout, '/', 'CO2_flux_unit', 'gC/m2/month');
    ncwriteatt(fout, '/', 'CO2_flux_sign', '+: emission to atmosphere');
    ncwriteatt(fout, '/', 'Time_Interval', 'month, mid-point');

    nccreate(  fout, 'lat',  'dimensions', {'lat', NLAT});
    ncwriteatt(fout, 'lat',  'units',      'degrees_north');
    ncwriteatt(fout, 'lat',  'long_name',  'latitude');
    ncwrite(   fout, 'lat',  lat);

    nccreate(  fout, 'lon',  'dimensions', {'lon', NLON});
    ncwriteatt(fout, 'lon',  'units',      'degrees_east');
    ncwriteatt(fout, 'lon',  'long_name',  'longitude');
    ncwrite(   fout, 'lon',  lon);

    nccreate(  fout, 'month', 'dimensions', {'month', 12});

    nccreate(  fout, vout, 'dimensions',       ...
               {'lon', NLON, 'lat', NLAT, 'month', 12});
    ncwrite(   fout, vout, FIRE);

    % SOILM
    % -----
    fout = [DIROUT, '/SOILM.monthly.0.5x0.5.', syear, '.nc'];
    vout = 'SOILM';

    idnc = netcdf.create(fout, 'clobber');
    netcdf.close(idnc);

    ncwriteatt(fout, '/', 'flux_variable_description', 'Soil Moisture');
    ncwriteatt(fout, '/', 'CO2_flux_unit', 'gC/m2/month');
    ncwriteatt(fout, '/', 'CO2_flux_sign', '+: emission to atmosphere');
    ncwriteatt(fout, '/', 'Time_Interval', 'month, mid-point');

    nccreate(  fout, 'lat',  'dimensions', {'lat', NLAT});
    ncwriteatt(fout, 'lat',  'units',      'degrees_north');
    ncwriteatt(fout, 'lat',  'long_name',  'latitude');
    ncwrite(   fout, 'lat',  lat);

    nccreate(  fout, 'lon',  'dimensions', {'lon', NLON});
    ncwriteatt(fout, 'lon',  'units',      'degrees_east');
    ncwriteatt(fout, 'lon',  'long_name',  'longitude');
    ncwrite(   fout, 'lon',  lon);

    nccreate(  fout, 'month', 'dimensions', {'month', 12});

    nccreate(  fout, vout, 'dimensions',       ...
               {'lon', NLON, 'lat', NLAT, 'month', 12});
    ncwrite(   fout, vout, SOILM);
end
