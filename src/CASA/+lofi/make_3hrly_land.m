%MAKE_3HRLY_LAND  Compute diurnal cycle of land NEE fluxes based on input
%meteorology
%
%   Recipe:
%     1) Run make_3hrly_meteo
%     2) Run make_3hrly_land

% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2024-10-11	New version for MiCASA
%===============================================================================


% INITIALIZE
%===============================================================================
lofi.setup;

LONGNAME  = [PRODUCT, ' 3-hourly NPP Rh ATMC NEE FIRE FUEL Fluxes ', RESLONG];
SHORTNAME = [upper(PRODUCT), '_FLUX_3H'];

TSTAMP = ['days since ', num2str(startYearTime), '-01-01'];
DNUM0  = datenum(startYearTime, 01, 01);
TOTYRS = endYear - startYear + 1;

for nyr = 1:TOTYRS
    nyear = startYear + nyr - 1;
    syear = num2str(nyear);

    for nmon = 1:12
        smon  = num2str(nmon, '%02u');
        molen = datenum(nyear, nmon+1, 01) - datenum(nyear, nmon, 01);

        for nday = 1:molen
            sday  = num2str(nday, '%02u');
            sdate = [syear, '-', smon, '-', sday];

            fbit = [FLUXHEAD, '_3hrly_', syear, smon, sday, '.', FEXT];
            dout = [DIROUT, '/3hrly/', syear, '/', smon];
            fout = [dout, '/', fbit];

            % Skip if file exists and not overwriting
            if isfile(fout)
                if FORCE
                    [status, result] = system(['rm ', fout]);
                else
                    continue;
                end
            end

%           1. READ DAILY FLUXES
%===============================================================================
            fbit = ['daily/', syear, '/', smon, '/', ...
                FLUXHEAD, '_daily_', syear, smon, sday, '.', FEXT];
            fin  = [DIROUT, '/', fbit];

            if ~isfile(fin), continue; end

            disp(['Reading daily data from ', fbit, ' ...']);

            dayhetr = ncread(fin, 'Rh') - ncread(fin, 'ATMC');
            daynpp  = ncread(fin, 'NPP');
            % This uses the approximation that GPP = 2*NPP
            daygpp  = 2*daynpp;
            dayecor = dayhetr + daynpp;

%           2. READ METEO DATA
%===============================================================================
            % Leap days use the 28th
            if nmon == 2 && nday == 29
                sdm2 = '28';
            else
                sdm2 = sday;
            end
            % Input variables (METHEAD & DIRMET defined in setup)
            fbit = [METHEAD, num2str(startYearClim), smon, sdm2, '.', FEXT];
            fm2  = [DIRMET, '/climate/', fbit];

            disp(['Reading meteo data from ', fbit, ' ...']);

            m2rad = ncread(fm2, VARSW);
            m2q10 = ncread(fm2, 'Q10');

            % Prevent NaNs
            m2rad(m2rad == 0) = min(m2rad(0 < m2rad));

%           3. DIS-AGGREGATE DAILY FLUXES TO 3-HOURLY
%===============================================================================
            gpp3hr  = zeros(NLON, NLAT, 8);
            ecor3hr = zeros(NLON, NLAT, 8);

            % This is why the trend in Q10 is not important: only care about
            % 3hrly percentages of daily means
            avgrad = mean(m2rad, 3);
            avgq10 = mean(m2q10, 3);

            for n3hr = 1:8
                gpp3hr(:,:,n3hr)  = daygpp  .* m2rad(:,:,n3hr)./avgrad;
                ecor3hr(:,:,n3hr) = dayecor .* m2q10(:,:,n3hr)./avgq10;
            end
            nee3hr = ecor3hr - gpp3hr;

%           4. WRITE
%===============================================================================
            % Redefine fbit since it gets overwritten
            fbit = [FLUXHEAD, '_3hrly_', syear, smon, sday, '.', FEXT];
            dout = [DIROUT, '/3hrly/', syear, '/', smon];
            fout = [dout, '/', fbit];

            disp(['Writing ', fbit, ' ...']);

            % Make sure output folder exists 
            if ~isfolder(dout)
                [status, result] = system(['mkdir -p ', dout]);
            end

            dnum  = datenum(nyear, nmon, nday);
            times = dnum - DNUM0 + [0:3:21]'/24;

            nccreate(  fout, 'time', 'dimensions',{'time',inf}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwriteatt(fout, 'time', 'long_name','time');
            ncwriteatt(fout, 'time', 'units',TSTAMP);
            ncwriteatt(fout, 'time', 'bounds','time_bnds');
            ncwrite(   fout, 'time', times);

            nccreate(  fout, 'time_bnds', ...
                'dimensions',{'nv',2, 'time',inf}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwriteatt(fout, 'time_bnds', 'long_name','time bounds');
            ncwrite(   fout, 'time_bnds', [times'; times' + times(2)-times(1)]);

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

            nccreate(  fout, 'NEE', 'datatype','single', ...
                'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwriteatt(fout, 'NEE', 'long_name','Net ecosystem exchange');
            ncwriteatt(fout, 'NEE', 'units','kg m-2 s-1');
            ncwriteatt(fout, 'NEE', 'expressed_as','carbon');
            ncwrite(   fout, 'NEE', single(nee3hr));

            nccreate(  fout, 'NPP', 'datatype','single', ...
                'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwriteatt(fout, 'NPP', 'long_name','Net primary productivity');
            ncwriteatt(fout, 'NPP', 'units','kg m-2 s-1');
            ncwriteatt(fout, 'NPP', 'expressed_as','carbon');
            ncwrite(   fout, 'NPP', single(0.5*gpp3hr));

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
            try
                comday = ncreadatt(fin, '/', 'comment');
                ncwriteatt(fin, '/', 'comment', comday);
            end
            ncwriteatt(fout, '/', 'GranuleID',   fbit);
            ncwriteatt(fout, '/', 'history',     ...
                ['Created on ', datestr(now, 'yyyy-mm-ddTHH:MM:SS.FFF000')]);
            ncwriteatt(fout, '/', 'stage', 'intermediate');
        end
    end
    fprintf('\n');
end
