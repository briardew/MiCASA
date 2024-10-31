dnums = [datenum(2024,08,01):datenum(2024,10,29)]';
DIR   = '../data-casa/daily-0.1deg-nrt/holding';
FHEAD = 'MiCASA_v1_flux_x3600_y1800';

addpath('/discover/nobackup/bweir/matlab');
cmap  = flipud(brewermap(128,'RdBu'));
style = hgexport('readstyle','hires');
coast = load('coast');

CFACT = 1.e3 * 60*60*24;

for nn = 1:numel(dnums)
    dnum  = dnums(nn);
    syear = datestr(dnum, 'yyyy');
    smon  = datestr(dnum, 'mm');
    sday  = datestr(dnum, 'dd');

    ff = [DIR, '/daily/', syear, '/', smon, '/', FHEAD, '_daily_', ...
        syear, smon, sday, '.nc4'];
    nbe = ncread(ff, 'NEE') + ncread(ff, 'FIRE') + ncread(ff, 'FUEL');

    % Inefficient, but don't care
    lat = ncread(ff, 'lat');
    lon = ncread(ff, 'lon');

    hp = pcolor(lon, lat, CFACT*nbe'); set(hp, 'edgecolor', 'none');
    caxis([-4 4]); colormap(cmap); colorbar horz;
    xlim([-130 -65]); ylim([24 50]);

    hold on;
    plot(coast.long, coast.lat, 'k');
    hold off;

    title(['NBE [g C m-2 day-1] ', syear, '-', smon, '-', sday]);
    hgexport(gcf, ['nbe_conus_', syear, smon, sday, '.png'], style);
end
