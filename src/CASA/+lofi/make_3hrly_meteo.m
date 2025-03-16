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
lofi.setup;					% Just needed for lat/lon
% Need to turn this off to reproduce v1 2001-2024
%DEFLATE = 9;
%SHUFFLE = true;

DNUM0 = datenum(startYearTime, 01, 01);
DSTR0 = ['days since ', datestr(DNUM0, 'yyyy-mm-dd HH:MM:SS')];

TOTYRS = endYearClim - startYearClim + 1;

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

        % Read MERRA-2 data
        % ---
        fswgdn = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2', ...
            '.tavg1_2d_rad_Nx.', syear, smon, sday, '.nc4'];
        ftem   = [DIRM2, '/Y', syear, '/M', smon, '/MERRA2', ...
            '.tavg1_2d_slv_Nx.', syear, smon, sday, '.nc4'];

        fprintf(repmat('\b', 1, lenmsg));
        message = ['Reading MERRA-2 radiation and temperature for ', ...
            syear, '/', smon, '/', sday, ' ...'];
        fprintf(message);
        lenmsg = length(message);

        m2radin = double(ncread(fswgdn, 'SWGDNCLR'));
        m2temin = double(ncread(ftem,   'TS'));
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

    % Output variables (DIRMET defined in setup)
    dstr = ['CLIM', datestr(datenum(midYearClim,01,01)+nyday-1, 'mmdd')];
    fbit = ['MiCASA_v', VERSION, '_meteo_x', num2str(NLON), '_y', ...
        num2str(NLAT), '_3hrly_', dstr, '.', FEXT];
    fout = [DIRMET, '/', fbit];

    disp(['Writing ', fbit, ' ...']);
    fprintf(repmat('\b', 1, lenmsg));
    message = ['Writing ', fbit, ' ...'];
    fprintf(message);
    lenmsg = length(message);

    if isfile(fout)
        if ~REPRO, continue; end
        [status, result] = system(['rm ', fout]);
    else
        [status, result] = system(['mkdir -p ', DIRMET]);
    end

    times = datenum(midYearClim, 01, 01) + nyday - 1 - DNUM0 + [0:3:21]'/24;

    nccreate(  fout, 'lat', 'dimensions',{'lat',NLAT}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwrite(   fout, 'lat', lat);
    ncwriteatt(fout, 'lat', 'units','degrees_north');
    ncwriteatt(fout, 'lat', 'long_name','latitude');

    nccreate(  fout, 'lon', 'dimensions',{'lon',NLON}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwrite(   fout, 'lon', lon);
    ncwriteatt(fout, 'lon', 'units','degrees_east');
    ncwriteatt(fout, 'lon', 'long_name','longitude');

    nccreate(  fout, 'time', 'dimensions',{'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwrite(   fout, 'time', times);
    ncwriteatt(fout, 'time', 'units',DSTR0);
    ncwriteatt(fout, 'time', 'long_name','time');
    ncwriteatt(fout, 'time', 'bounds','time_bnds');

    nccreate(  fout, 'time_bnds', ...
        'dimensions',{'nv',2, 'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwriteatt(fout, 'time_bnds', 'units',DSTR0);
    ncwriteatt(fout, 'time_bnds', 'long_name','time bounds');
    ncwrite(fout,    'time_bnds', [times'; times' + times(2)-times(1)]);

    nccreate(  fout, 'SWGDNCLR', 'datatype','single', ...
        'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwrite(   fout, 'SWGDNCLR', single(radout));
    ncwriteatt(fout, 'SWGDNCLR', 'units', 'W m-2');
    ncwriteatt(fout, 'SWGDNCLR', 'long_name', ...
        'surface_incoming_shortwave_flux_assuming_clear_sky');

    nccreate(  fout, 'Q10', 'datatype','single', ...
        'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
    ncwrite(   fout, 'Q10', single(q10out));
    ncwriteatt(fout, 'Q10', 'units', 'none');
    ncwriteatt(fout, 'Q10', 'long_name','q10_function');

    ncwriteatt(fout, '/', 'Conventions', 'CF-1.9');
    ncwriteatt(fout, '/', 'title',       '3-hourly meteorological fields');
    ncwriteatt(fout, '/', 'comment',     ['Climatology over ', ...
        num2str(startYearClim), '-', num2str(endYearClim)]);
    ncwriteatt(fout, '/', 'institution', INSTITUTION);
    ncwriteatt(fout, '/', 'contact',     CONTACT);
    ncwriteatt(fout, '/', 'ProductionDateTime', ...
        datestr(now, 'yyyy-mm-ddTHH:MM:SSZ'));
end
fprintf('\n');
