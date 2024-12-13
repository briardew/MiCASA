%YEAR0 = 2024;
%YEARF = 2024;
YEAR0 = 2023;
YEARF = 2023;
TESTDIR = '/discover/nobackup/bweir/MiCASA/data-casa/daily-0.1deg-final/holding/daily';

addpath('/discover/nobackup/bweir/matlab/globutils');

syear = num2str(YEAR0);
lat = ncread([TESTDIR, '/', syear, '/01/MiCASA_v1_flux_', ...
    'x3600_y1800_daily_', syear, '0101.nc4'], 'lat');
lon = ncread([TESTDIR, '/', syear, '/01/MiCASA_v1_flux_', ...
    'x3600_y1800_daily_', syear, '0101.nc4'], 'lon');

[LA, LO] = meshgrid(lat, lon);
area = globarea(lat, lon);
area = area .* (30 <= LA) .* (LA <= 50) .* (-100 <= LO) .* (LO <= -70);

NDAYS = datenum(YEARF, 12, 31) - datenum(YEAR0, 01, 01);

npptots  = single(zeros(NDAYS, 1));
restots  = single(zeros(NDAYS, 1));
firetots = single(zeros(NDAYS, 1));
fueltots = single(zeros(NDAYS, 1));
sinktots = single(zeros(NDAYS, 1));

nppmtots  = single(zeros(NDAYS, 1));
nppttots  = single(zeros(NDAYS, 1));
soilmtots = single(zeros(NDAYS, 1));

nn = 0;
for year = YEAR0:YEARF
    syear = num2str(year);

    for nm = 1:12
        smon = num2str(nm, '%02u');
        modays = datenum(year, nm+1, 01) - datenum(year, nm, 01);

        for nd = 1:modays
            sday = num2str(nd, '%02u');

            ff = [TESTDIR, '/', syear, '/', smon, '/MiCASA_v1_flux_', ...
                'x3600_y1800_daily_', syear, smon, sday, '.nc4'];

            nppday  = ncread(ff, 'NPP');
            resday  = ncread(ff, 'Rh');
            fireday = ncread(ff, 'FIRE');
            fuelday = ncread(ff, 'FUEL');
            sinkday = ncread(ff, 'ATMC');

            ff = [TESTDIR, '/', syear, '/', smon, '/MiCASA_v1_extra_', ...
                'x3600_y1800_daily_', syear, smon, sday, '.nc4'];

            nppmday  = ncread(ff, 'NPPmoist');
            npptday  = ncread(ff, 'NPPtemp');
            soilmday = ncread(ff, 'SOILM');

            nn = nn + 1;
            npptots(nn)   = sum(sum( area.*nppday   ));
            restots(nn)   = sum(sum( area.*resday   ));
            firetots(nn)  = sum(sum( area.*fireday  ));
            fueltots(nn)  = sum(sum( area.*fuelday  ));
            sinktots(nn)  = sum(sum( area.*sinkday  ));

            nppmtots(nn)  = sum(sum( area.*nppmday  ));
            nppttots(nn)  = sum(sum( area.*npptday  ));
            soilmtots(nn) = sum(sum( area.*soilmday ));
        end
    end
end
