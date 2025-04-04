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

DNUM0 = datenum(1980, 01, 01);
DSTR0 = ['days since ', datestr(DNUM0, 'yyyy-mm-dd HH:MM:SS')];

% Get met data
M2HEAD = ['MiCASA_v', VERSION, '_meteo_x', num2str(NLON), '_y', ...
    num2str(NLAT)];

TOTYRS = endYear - startYear + 1;
for nyr = 1:TOTYRS
    nyear = startYear + nyr - 1;
    syear = num2str(nyear);

    lenmsg = 0;
    for nmon = 1:12
        smon  = num2str(nmon, '%02u');
        molen = datenum(nyear, nmon+1, 01) - datenum(nyear, nmon, 01);

        for nday = 1:molen
            sday  = num2str(nday, '%02u');
            sdate = [syear, '-', smon, '-', sday];

            fbit = [FHEAD, '_3hrly_', syear, smon, sday, '.', FEXT];
            dout = [MIROOT, '/3hrly/', syear, '/', smon];
            fout = [dout, '/', fbit];

            % Skip if file exists and not reprocessing
            if isfile(fout)
                if REPRO
                    [status, result] = system(['rm ', fout]);
                else
                    continue;
                end
            end

%           1. READ DAILY FLUXES
%===============================================================================
            fbit = ['daily/', syear, '/', smon, '/', ...
                FHEAD, '_daily_', syear, smon, sday, '.', FEXT];
            fin  = [MIROOT, '/', fbit];

            if ~isfile(fin), continue; end

            fprintf(repmat('\b', 1, lenmsg));
            message = ['Reading daily data from ', fbit, ' ...'];
            fprintf(message);
            lenmsg = length(message);

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
            fbit = [M2HEAD, '_3hrly_', 'CLIM', smon, sdm2, '.', FEXT];
            fm2  = [DIRMET, '/', fbit];

            fprintf(repmat('\b', 1, lenmsg));
            message = ['Reading MERRA-2 data from ', fbit, ' ...'];
            fprintf(message);
            lenmsg = length(message);

            m2rad = ncread(fm2, 'SWGDNCLR');
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
            fbit = [FHEAD, '_3hrly_', syear, smon, sday, '.', FEXT];
            dout = [MIROOT, '/3hrly/', syear, '/', smon];
            fout = [dout, '/', fbit];

            fprintf(repmat('\b', 1, lenmsg));
            message = ['Writing ', fbit, ' ...'];
            fprintf(message);
            lenmsg = length(message);

            % Make sure output folder exists 
            if ~isfolder(dout)
                [status, result] = system(['mkdir -p ', dout]);
            end

            times = datenum(nyear, nmon, nday) - DNUM0 + [0:3:21]'/24;

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

            nccreate(  fout, 'NEE', 'datatype','single', ...
                'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwriteatt(fout, 'NEE', 'units','kg m-2 s-1');
            ncwriteatt(fout, 'NEE', 'expressed_as','carbon');
            ncwriteatt(fout, 'NEE', 'long_name','Net ecosystem exchange');
            ncwrite(   fout, 'NEE', single(nee3hr));

            nccreate(  fout, 'NPP', 'datatype','single', ...
                'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwriteatt(fout, 'NPP', 'units','kg m-2 s-1');
            ncwriteatt(fout, 'NPP', 'expressed_as','carbon');
            ncwriteatt(fout, 'NPP', 'long_name','Net primary productivity');
            ncwrite(   fout, 'NPP', single(0.5*gpp3hr));
        end
    end
    fprintf('\n');
end
