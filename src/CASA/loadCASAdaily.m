% Read and regrid daily input data (and some monthlies)
% ===
% TODO:
% * Add OPeNDAP MERRA-2 read option

% Hack because v0 doesn't have MODIS/VIIRS files
VERUSE = VERSION; if VERSION(1) == '0', VERUSE = '1'; end

% Requires dnum variable as defined in CASA
syear = datestr(dnum, 'yyyy');
smon  = datestr(dnum, 'mm');
sday  = datestr(dnum, 'dd');

% Read MODIS/VIIRS fPAR
% ---
fin = [DIRMODV, '/vegind/', syear, '/MiCASA_v', VERUSE, ...
    '_vegind_', MODVRES, '_daily_', syear, smon, sday, '.nc4'];
FPAR = flipud(ncread(fin, 'fPAR')');

% Read MODIS/VIIRS burned area
% ---
fin = [DIRMODV, '/burn/', syear, '/MiCASA_v', VERUSE, ...
    '_burn_', MODVRES, '_daily_', syear, smon, sday, '.nc4'];
BAdefo = flipud(ncread(fin, 'badefo')');
BAherb = flipud(ncread(fin, 'baherb')');
BAwood = flipud(ncread(fin, 'bawood')');

FPAR(isnan(FPAR)) = 0;
BAdefo(isnan(BAdefo)) = 0;
BAherb(isnan(BAherb)) = 0;
BAwood(isnan(BAwood)) = 0;

% Try to keep the default case quick
if NLAT ~= NLATMV || NLON ~= NLONMV
    FPAR   = flipud(avgarea(latmv, lonmv, flipud(FPAR)', lat, lon, RADIUS)');

    area   = globarea(lat,   lon,   RADIUS);
    areamv = globarea(latmv, lonmv, RADIUS);

    % Recall these are areas
    BAdefo = flipud((avgarea(latmv, lonmv, flipud(BAdefo)'./areamv, lat, lon, RADIUS).*area)');
    BAherb = flipud((avgarea(latmv, lonmv, flipud(BAherb)'./areamv, lat, lon, RADIUS).*area)');
    BAwood = flipud((avgarea(latmv, lonmv, flipud(BAwood)'./areamv, lat, lon, RADIUS).*area)');
end

if lower(do_nrt_meteo(1)) == 'n'
    % Air temperature
    % ---
    fm2 = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2.tavg1_2d_slv_Nx.', ...
        syear, smon, sday, '.nc4'];
    % Using temperature of lowest model level (TLML); other options include
    % 2-meter (T2M) and effective surface skin (TSH) temperature; these choices
    % have not been tested
    airtm2 = ncread(fm2, 'TS') - 273.15;

    % Precipitation
    % ---
    % Using monthly because soil moisture module does not respond well to
    % daily precip; unclear exactly why (***FIXME***)
    fm2 = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2.tavgM_2d_flx_Nx.', ...
        syear, smon, '.nc4'];
    % * Units in M2: kg m-2 s-1 = mm s-1
    %   Thornwaite equation in doPET gives PET in units of mm month-1
    %   PPT is summed from mm day-1 here to mm month-1 in updateCASAinput
    % * PRECTOTCORR from M2 imparts a spatial blockiness on SOILM and Rh
    %   Its use here is thus discouraged
    %pptm2 = ncread(fm2, 'PRECTOT') * 60*60*24;
    pptm2 = ncread(fm2, 'PRECTOTCORR') * 60*60*24;

    % Short-wave radiation
    % ---
    fm2 = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2.tavg1_2d_rad_Nx.', ...
        syear, smon, sday, '.nc4'];
    % Using clear-sky (SWGDNCLR) instead of all-sky (SWGDN) values to represent
    % growth under diffuse radiation
    % [Joiner et al. (2018)](https://10.3390/rs10091346)
    sradm2 = ncread(fm2, 'SWGDNCLR');
else
    if dnum < datenum(2008,01,01)
        tagit = 'd5294_geosit_jan98';
    elseif dnum < datenum(2018,01,01)
        tagit = 'd5294_geosit_jan08';
    else
        tagit = 'd5294_geosit_jan18';
    end

    airtm2 = 0;
    pptm2  = 0;
    sradm2 = 0;
    for nhr = 1:24
        shr = num2str(nhr-1, '%02u');

        fm2 = [DIRIT, '/', tagit, '/diag/Y', syear, '/M', smon, ...
            '/', tagit, '.slv_tavg_1hr_glo_L576x361_slv.', ...
            syear, '-', smon, '-', sday, 'T' shr, '30Z.nc4'];
        airtm2 = airtm2 + ncread(fm2, 'TS') - 273.15;

        fm2 = [DIRIT, '/', tagit, '/diag/Y', syear, '/M', smon, ...
            '/', tagit, '.flx_tavg_1hr_glo_L576x361_slv.', ...
            syear, '-', smon, '-', sday, 'T' shr, '30Z.nc4'];
        pptm2 = pptm2 + ncread(fm2, 'PRECTOT') * 60*60*24;

        fm2 = [DIRIT, '/', tagit, '/diag/Y', syear, '/M', smon, ...
            '/', tagit, '.rad_tavg_1hr_glo_L576x361_slv.', ...
            syear, '-', smon, '-', sday, 'T' shr, '30Z.nc4'];
        sradm2 = sradm2 + ncread(fm2, 'SWGDNCLR');
    end
    airtm2 = airtm2/24;
    pptm2  =  pptm2/24;
    sradm2 = sradm2/24;
end

% Regrid
% ---
% Can remove/hard-code for speed, but here por robusto
latm2 = ncread(fm2, 'lat');
lonm2 = ncread(fm2, 'lon');

% Not convinced AIRT should be conservatively regridded
% Interpolating instead (maybe faster?) ...
[LA, LO] = meshgrid(lat, lon);
% Border protection
lonmx = [lonm2; 180];
[LAMX, LOMX] = meshgrid(latm2, lonmx);

airtmx = mean(airtm2, 3);
pptmx  = mean(pptm2,  3);
sradmx = mean(sradm2, 3);
airtmx = [airtmx; airtmx(1,:)];
pptmx  = [pptmx;   pptmx(1,:)];
sradmx = [sradmx; sradmx(1,:)];

% Suggest linear interpolation for speed and consistency
AIRT   = flipud(interp2(LAMX, LOMX, airtmx, LA, LO, 'linear')');
PPT    = flipud(interp2(LAMX, LOMX, pptmx,  LA, LO, 'linear')');
SOLRAD = flipud(interp2(LAMX, LOMX, sradmx, LA, LO, 'linear')');

PPT    = max(PPT,    0);
SOLRAD = max(SOLRAD, 0);
