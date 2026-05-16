DIR0 = '~ghg_ops/Projects/MiCASA/data';
VER0 = '1';
DIR1 = '../data';
VER1 = '1A';

NLAT = 1800;
NLON = 3600;

RESTAG = ['x', num2str(NLON), '_y', num2str(NLAT)];

dnums = [datenum(2019,01,01):datenum(2019,02,28)]';

zz = zeros(NLON, NLAT);
oo =  ones(NLON, NLAT);
num0 = zz; avg0 = zz; std0 = zz; max0 = NaN*oo; min0 = NaN*oo;
num1 = zz; avg1 = zz; std1 = zz; max1 = NaN*oo; min1 = NaN*oo;
for nn = 1:numel(dnums)
    syear = datestr(dnums(nn), 'yyyy');
    sdate = datestr(dnums(nn), 'yyyymmdd');

    f0 = [DIR0, '/v', VER0, '/drivers/vegind/', syear, ...
        '/MiCASA_v', VER0, '_vegind_', RESTAG, '_daily_', sdate, '.nc4'];
    f1 = [DIR1, '/v', VER1, '/drivers/vegind/', syear, ...
        '/MiCASA_v', VER1, '_vegind_', RESTAG, '_daily_', sdate, '.nc4'];

    ndvi0 = ncread(f0, 'NDVI');
    ndvi1 = ncread(f1, 'NDVI');

    iok = ~isnan(ndvi0);
    num0 = num0 + iok;
    dx = ndvi0 - avg0;
    avg0(iok) = avg0(iok) + dx(iok)./num0(iok);
    std0(iok) = dx(iok) .* (ndvi0(iok) - avg0(iok));
    max0 = nanmax(max0, ndvi0);
    min0 = nanmin(min0, ndvi0);

    iok = ~isnan(ndvi1);
    num1 = num1 + iok;
    dx = ndvi1 - avg1;
    avg1(iok) = avg1(iok) + dx(iok)./num1(iok);
    std1(iok) = dx(iok) .* (ndvi1(iok) - avg1(iok));
    max1 = nanmax(max1, ndvi1);
    min1 = nanmin(min1, ndvi1);
end
% NaN out averages that aren't actually 0
avg0(num0 == 0) = NaN;
avg1(num1 == 0) = NaN;
% Biased estimator, but we often have num = 1
std0 = sqrt(std0./num0);
std1 = sqrt(std1./num1);
del0 = max0 - min0;
del1 = max1 - min1;

lat = ncread(f0, 'lat');
lon = ncread(f0, 'lon');
