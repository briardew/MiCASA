%MAKE_3HRLY_METEO  Compute meterological forcing from MERRA-2 data for diurnal
%cycle caluation
%
%   Recipe:
%     1) Run make_3hrly_meteo
%     2) Run make_3hrly_land

% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2024-10-11	New version for MiCASA
%===============================================================================

TEMP0  = 273.15 + 10;				% 10 deg Celcius
TSCALE = 10;					% Scaling of Q10 exponent
QBASE  = 1.5;					% Base of Q10 function


% INITIALIZE
%===============================================================================
lofi.setup;
% Compress these files since they are final
DEFLATE = 9;
SHUFFLE = true;

LONGNAME  = [PRODUCT, ' 3-hourly Climatological Meteorology ', RESLONG];
SHORTNAME = [upper(PRODUCT), '_METEO_3HC'];

TSTAMP = ['days since ', num2str(startYearTime), '-01-01'];
DNUM0  = datenum(startYearTime, 01, 01);
TOTYRS = endYearClim - startYearClim + 1;

% Simplify do_meteo_type for comparisons
do_meteo_type = lower(strrep(strrep(do_meteo_type, '\s', ''), '-', ''));

% Climatology variabiles
% Note 1: Although variables have trends, disaggregation only uses
% 3-hourly variability within day
% Note 2: Reanalysis grid variables (latm2, etc.) defined in setup
clnum = zeros(NLONM2, NLATM2, 8, 365);
clrad = zeros(NLONM2, NLATM2, 8, 365);
clq10 = zeros(NLONM2, NLATM2, 8, 365);
nFEB28 = 31 + 28;


% 1. READ & AVERAGE MERRA-2 DATA
%===============================================================================
for nyr = 1:TOTYRS
    nyear = startYearClim + nyr - 1;
    syear = num2str(nyear);

    yrlen = datenum(nyear+1,01,01) - datenum(nyear,01,01);

    m2rad = zeros(NLONM2, NLATM2, 8);
    m2q10 = zeros(NLONM2, NLATM2, 8);

    lenmsg = 0;
    for nyday = 1:yrlen
        dnum = datenum(nyear,01,01) + nyday - 1;
        dvec = datevec(dnum);

        smon = num2str(dvec(2), '%02u');
        sday = num2str(dvec(3), '%02u');

        if yrlen == 366 & nFEB28 < nyday
            nclim = nyday - 1;
        else
            nclim = nyday;
        end

        fprintf(repmat('\b', 1, lenmsg));
        message = ['Reading radiation and temperature for ', ...
            syear, '-', smon, '-', sday, ' ...'];
        fprintf(message);
        lenmsg = length(message);

        % Read met data
        % ---
        if strcmp(do_meteo_type, 'geosit')
            if dnum < datenum(2008,01,01)
                tagit = 'd5294_geosit_jan98';
            elseif dnum < datenum(2018,01,01)
                tagit = 'd5294_geosit_jan08';
            else
                tagit = 'd5294_geosit_jan18';
            end

            m2radin = zeros(NLONM2, NLATM2, 24);
            m2temin = zeros(NLONM2, NLATM2, 24);
            for nhr = 1:24
                shr = num2str(nhr-1, '%02u');

                frad = [DIRIT, '/', tagit, '/diag/Y', syear, '/M', smon, ...
                    '/', tagit, '.rad_tavg_1hr_glo_L576x361_slv.', ...
                    syear, '-', smon, '-', sday, 'T' shr, '30Z.nc4'];
                ftem = [DIRIT, '/', tagit, '/diag/Y', syear, '/M', smon, ...
                    '/', tagit, '.slv_tavg_1hr_glo_L576x361_slv.', ...
                    syear, '-', smon, '-', sday, 'T' shr, '30Z.nc4'];

                m2radin(:,:,nhr) = ncread(frad, VARSW);
                m2temin(:,:,nhr) = ncread(ftem, VARTS);
            end
        else
            frad = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2', ...
                '.tavg1_2d_rad_Nx.', syear, smon, sday, '.nc4'];
            ftem = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2', ...
                '.tavg1_2d_slv_Nx.', syear, smon, sday, '.nc4'];

            m2radin = double(ncread(frad, VARSW));
            m2temin = double(ncread(ftem, VARTS));
        end

        m2q10in = QBASE.^((m2temin - TEMP0)/TSCALE);
        for n3hr = 1:8
            nhrs = [(n3hr-1)*3+1:n3hr*3];

            m2rad(:,:,n3hr) = mean(m2radin(:,:,nhrs), 3);
            m2q10(:,:,n3hr) = mean(m2q10in(:,:,nhrs), 3);
        end

        % Average into 365-day climatology
        % ---
        delrad = m2rad - clrad(:,:,:,nclim);
        delq10 = m2q10 - clq10(:,:,:,nclim);

        clnum(:,:,:,nclim) = clnum(:,:,:,nclim) + 1;
        clrad(:,:,:,nclim) = clrad(:,:,:,nclim) + delrad./clnum(:,:,:,nclim);
        clq10(:,:,:,nclim) = clq10(:,:,:,nclim) + delq10./clnum(:,:,:,nclim);
    end
    fprintf('\n');
end

swlong = ncreadatt(frad, VARSW, 'long_name');

% 2. REGRID & WRITE
%===============================================================================
[LA, LO] = meshgrid(lat, lon);
% Border protection
lonmx = [lonm2; 180];
[LAMX, LOMX] = meshgrid(latm2, lonmx);

lenmsg = 0;
for nyday = 1:365
    cxrad = [clrad(:,:,:,nyday); clrad(1,:,:,nyday)];
    cxq10 = [clq10(:,:,:,nyday); clq10(1,:,:,nyday)];

    radout = zeros(NLON, NLAT, 8);
    q10out = zeros(NLON, NLAT, 8);
    for n3hr = 1:8
        radout(:,:,n3hr) = interp2(LAMX, LOMX, cxrad(:,:,n3hr), LA, LO, 'linear');
        q10out(:,:,n3hr) = interp2(LAMX, LOMX, cxq10(:,:,n3hr), LA, LO, 'linear');
    end

    % Output variables (METHEAD & DIRMET defined in setup)
    dnum = datenum(startYearClim,01,01) + nyday - 1;
    fbit = [METHEAD, datestr(dnum, 'yyyymmdd'), '.', FEXT];
    fout = [DIRMET, '/climate/', fbit];

    fprintf(repmat('\b', 1, lenmsg));
    message = ['Writing ', fbit, ' ...'];
    fprintf(message);
    lenmsg = length(message);

    if isfile(fout)
        if ~FORCE, continue; end
        [status, result] = system(['rm ', fout]);
    else
        [status, result] = system(['mkdir -p ', DIRMET, '/climate']);
    end

    times = dnum - DNUM0 + [0:3:21]'/24;

    nccreate(  fout, 'time', 'dimensions',{'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwriteatt(fout, 'time', 'long_name','time');
    ncwriteatt(fout, 'time', 'units',TSTAMP);
    ncwriteatt(fout, 'time', 'calendar','proleptic_gregorian');
    ncwriteatt(fout, 'time', 'climatology','clim_bnds');
    ncwrite(   fout, 'time', times);

    nccreate(  fout, 'clim_bnds', ...
        'dimensions',{'nv',2, 'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwriteatt(fout, 'clim_bnds', 'long_name','climatology bounds');
    ncwrite(   fout, 'clim_bnds', [times'; times' + times(2)-times(1)]);

    nccreate(  fout, 'lat', 'dimensions',{'lat',NLAT}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwriteatt(fout, 'lat', 'long_name','latitude');
    ncwriteatt(fout, 'lat', 'units','degrees_north');
    ncwrite(   fout, 'lat', lat);

    nccreate(  fout, 'lon', 'dimensions',{'lon',NLON}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwriteatt(fout, 'lon', 'long_name','longitude');
    ncwriteatt(fout, 'lon', 'units','degrees_east');
    ncwrite(   fout, 'lon', lon);

    nccreate(  fout, VARSW, 'datatype','single', ...
        'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwriteatt(fout, VARSW, 'long_name', swlong);
    ncwriteatt(fout, VARSW, 'units', 'W m-2');
    ncwrite(   fout, VARSW, single(radout));

    nccreate(  fout, 'Q10', 'datatype','single', ...
        'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwriteatt(fout, 'Q10', 'long_name','Q10 function');
    ncwriteatt(fout, 'Q10', 'units', 'none');
    ncwrite(   fout, 'Q10', single(q10out));

    ncwriteatt(fout, '/', 'ShortName',   SHORTNAME);
    ncwriteatt(fout, '/', 'LongName',    LONGNAME);
    ncwriteatt(fout, '/', 'title',       [LONGNAME, ' v', VERSION]);
    ncwriteatt(fout, '/', 'Conventions', CONVENTIONS);
    ncwriteatt(fout, '/', 'ProcessingLevel', '4');
    ncwriteatt(fout, '/', 'institution', INSTITUTION);
    ncwriteatt(fout, '/', 'contact',     CONTACT);
    ncwriteatt(fout, '/', 'SouthernmostLatitude', LATMIN);
    ncwriteatt(fout, '/', 'NorthernmostLatiude',  LATMAX);
    ncwriteatt(fout, '/', 'WesternmostLongitude', LONMIN);
    ncwriteatt(fout, '/', 'EasternmostLongitude', LONMAX);
    ncwriteatt(fout, '/', 'RangeBeginningDate',   datestr(dnum, 'yyyy-mm-dd'));
    ncwriteatt(fout, '/', 'RangeBeginningTime',   '00:00:00.000000');
    ncwriteatt(fout, '/', 'RangeEndingDate',      datestr(dnum, 'yyyy-mm-dd'));
    ncwriteatt(fout, '/', 'RangeEndingTime',      '23:59:59.999999');
    ncwriteatt(fout, '/', 'comment',     ...
        ['Climatology over ', num2str(startYearClim), '-', num2str(endYearClim)]);
    ncwriteatt(fout, '/', 'GranuleID',   fbit);
    ncwriteatt(fout, '/', 'history',     ...
        ['Created on ', datestr(now, 'yyyy-mm-ddTHH:MM:SS.FFF000')]);
end
fprintf('\n');
