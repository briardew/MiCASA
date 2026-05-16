%VER = 'NRT';
%dnums = [datenum(2025,01,01):1:floor(now)-2]';

VER = '1';
%dnums = [datenum(2024,01,01):1:datenum(2024,06,30)]';
dnums = [datenum(2019,01,01):1:datenum(2019,03,07)]';

DIRDATA = '~ghg_ops/Projects/MiCASA/data';
DIRM2 = '/discover/nobackup/projects/gmao/merra2/data/pub/products/MERRA2_all';
DIRIT = '/discover/nobackup/projects/gmao/geos-it/dao_ops/archive/d5294_geosit_jan18/diag';
% Yikes. I'd like these utilities shared in this repo, but ... yikes.
addpath('/discover/nobackup/bweir/matlab');
addpath('/discover/nobackup/bweir/matlab/globutils');

NLAT = 1800;
NLON = 3600;
lat  = [ -90+ 90/NLAT:180/NLAT: 90- 90/NLAT]';
lon  = [-180+180/NLON:360/NLON:180-180/NLON]';
area = globarea(lat, lon);

figure(1); clf; worldmap('world');
style = hgexport('readstyle','hires');
coast = load('coastlines');

cmnbe  = flipud(brewermap(128,'RdBu'));
cmfplo = [206 126  69; ...
          206 126  69; ...
          214 136  65; ...
          223 146  61; ...
          232 164  73; ...
          241 181  85; ...
          252 209  99; ...
          153 183  24; ...
          116 169   1; ...
          102 160   0; ...
           82 148   0; ...
           62 134   1; ...
           32 116   1; ...
            5  98   1; ...
            0  76   0; ...
            2  59   1; ...
            1  46   1; ...
            1  29   1; ...
            1  19   1];
cmfpar = interp1(linspace(0,100,size(cmfplo,1))', cmfplo, [0:100]');
cmland = [255   0   0; ...              % -4: FIRE
           28  40  66; ...		% -3: OCEAN
          125 125 125; ...		% -2: URBAN
          255 255 255; ...		% -1: SNOW
          cmfpar]/255;			% [0,100]: fPAR
cmall  = [cmland; flipud(brewermap(100,'Blues'))];

for ii = 1:numel(dnums)
    dnum  = dnums(ii);
    syear = datestr(dnum, 'yyyy');
    smon  = datestr(dnum, 'mm');
    sday  = datestr(dnum, 'dd');

%   ff = [DIRDATA, '/v', VER, '/drivers/vegind/', syear, ...
%       '/MiCASA_v', VER, '_vegind_x3600_y1800_daily_', syear, smon, sday, '.nc4'];
    % Hack, remove
    ff = ['../data', '/v', '1A', '/drivers/vegind/', syear, ...
        '/MiCASA_v', '1A', '_vegind_x3600_y1800_daily_', syear, smon, sday, '.nc4'];
    fpar = ncread(ff, 'fPAR');

    ff = [DIRDATA, '/v', VER, '/drivers/burn/', syear, ...
        '/MiCASA_v', VER, '_burn_x3600_y1800_daily_', syear, smon, sday, '.nc4'];
    burn = ncread(ff, 'batot');
    % Color red if at least 1/4 of the cell is burning
    bmask = 30.5*10*burn./area;
    bmask = min(max(bmask, 0), 1);

    % Sea and land ice
    fm2   = [DIRM2, '/MERRA2.const_2d_asm_Nx.00000000.nc4'];
    lndm2 = ncread(fm2, 'FRLAND');
    icem2 = ncread(fm2, 'FRLANDICE');
    snom2 = 0;

    for hour = 0:23
        fm2 = [DIRIT, '/Y', syear, '/M', smon, ...
            '/d5294_geosit_jan18.ocn_tavg_1hr_glo_L576x361_slv.', ...
            syear, '-', smon, '-', sday, 'T', num2str(hour,'%02u'), '30Z.nc4'];
        icem2in = ncread(fm2, 'FRSEAICE');
        icem2in(isnan(icem2in)) = 0;
        icem2 = icem2 + icem2in/24;

        fm2 = [DIRIT, '/Y', syear, '/M', smon, ...
            '/d5294_geosit_jan18.lnd_tavg_1hr_glo_L576x361_slv.', ...
            syear, '-', smon, '-', sday, 'T', num2str(hour,'%02u'), '30Z.nc4'];
        snom2in = ncread(fm2, 'FRSNO');
        snom2in(isnan(snom2in)) = 0;
        snom2 = snom2 + snom2in/24;
    end

    latm2  = ncread(fm2, 'lat');
    lonm2  = ncread(fm2, 'lon');
    aream2 = globarea(latm2, lonm2);

    smask = avgarea(latm2, lonm2, min(max(snom2+icem2, 0), 1), lat, lon);
    smask = min(max(smask, 0), 1);

    % Need to fix this
    water = 1 - avgarea(latm2, lonm2, lndm2, lat, lon);

    wmask = water;
    wmask(isnan(wmask)) = 1;
    wmask = min(max(wmask, 0), 1);

    clf; worldmap('world');
    set(gcf, 'inverthardcopy', 'off');
    set(gcf, 'color', 'k');
    pcolormx(lat, lon, 100*fpar');    
    pcolormx(lat, lon, -4*ones(size(bmask))', bmask');
    pcolormx(lat, lon, -3*ones(size(wmask))', wmask');
    pcolormx(lat, lon, -1*ones(size(smask))', smask');
    plotm(coast.coastlat, coast.coastlon, 'k');
    colormap(cmland);
    plabel off; mlabel off;
    posa = get(gca, 'position');
    ha = annotation('textbox', [posa(1) posa(2)+0.135 0 0], ...
        'string', datestr(dnum, 'dd mmm yyyy'),  ...
        'color', 'w', 'edgecolor', 'none', 'fitboxtotext', 'on');
    caxis([-4 100]);
    hgexport(gcf, ['figs/marb_',syear,smon,sday,'.png'], style);

    ff = [DIRDATA, '/v', VER, '/holding/daily/', syear, ...
        '/', smon, '/MiCASA_v', VER, '_flux_x3600_y1800_daily_', ...
        syear, smon, sday, '.nc4'];
    nbe = ncread(ff, 'NEE') + ncread(ff, 'FIRE') + ncread(ff, 'FUEL');

    clf; worldmap('world');
    set(gcf, 'inverthardcopy', 'off');
    set(gcf, 'color', 'k');
    pcolormx(lat, lon, 1e3*24*60*60*nbe');    
    plotm(coast.coastlat, coast.coastlon, 'k');
    colormap(cmnbe);
    plabel off; mlabel off;
    caxis([-4 4]);
    hc = colorbar('horz');
    set(hc, 'color', 'w');
    hgexport(gcf, ['figs/flux_',syear,smon,sday,'.png'], style);
end
