%MAKE_SINK  Add atmospheric correction to MiCASA

% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2024/05/16	Initial version
%===============================================================================

RESWGT  = 0.0;			% Have tested 0.25 in the past
SINKWGT = 0.16;
SINKVAR = 'ATMC';

% INITIALIZE
%===============================================================================
lofi.setup;
restag = ['x', num2str(NLON), '_y', num2str(NLAT)];

% Build sink weights
lofi.make_sink_prep1;
lofi.make_sink_prep2;
dtwgt = dtpos + RESWGT*dtneg;

% Make sure the NCO utilities are available
[status, result] = system('ncra --version');
if status ~= 0
    error(sprintf([...
        '*** Missing NCO utilities ***\n\n', ...
        'On NCCS Discover, run\n', ...
        '    > module load nco\n', ...
        'from the terminal before starting Octave/Matlab.']));
end

% READ FLUXES
%===============================================================================
for nyear = startYear:endYear
    syear = num2str(nyear);

    yrlen = datenum(nyear+1,01,01) - datenum(nyear,01,01);
    if yrlen == 365
        dnmids = [16.5; 46;   75.5; 106; 136.5; 167; 197.5; 228.5; ...
            259; 289.5; 320; 350.5; 367];
    else
        dnmids = [16.5; 46.5; 76.5; 107; 137.5; 168; 198.5; 229.5; ...
            260; 290.5; 321; 351.5; 368];
    end

    nnow = 1;
    nprv = 12;
    nday = 0;
    for nmon = 1:12
        smon = num2str(nmon, '%02u');
        monlen = datenum(nyear,nmon+1,01) - datenum(nyear,nmon,01);
        monsink = zeros(NLON, NLAT);

        % Daily
        % ---
        for nd = 1:monlen
            fout = [MIROOT, '/daily/', syear, '/', smon, ...
                '/MiCASA_v', VERSION, '_flux_', restag, '_daily_', ...
                syear, smon, num2str(nd,'%02u'), '.', FEXT];

            if ~isfile(fout), continue; end

            nday = nday + 1;
            if dnmids(nnow) < nday
                nprv = nnow;
                nnow = nnow + 1;
            end
            wwprv = (dnmids(nnow) - nday)/(dnmids(nnow) - dnmids(nprv));
            % Hack to avoid pasting January onto end of dtwgt
            dtnow = wwprv*dtwgt(:,:,nprv) + (1 - wwprv)*dtwgt(:,:,mod(nprv,12)+1);

            npp  = ncread(fout, 'NPP');
            hetr = ncread(fout, 'Rh');

            sink = SINKWGT * fsink(ao,nyear+nday/yrlen) * dtnow .* hetr;
            sink = min(hetr, single(sink));
            monsink = monsink + sink;

            % A little tricky since file should exist already        
            hasvar = 0;
            try
                ncread(fout, SINKVAR);
                hasvar = 1;
            end

            % Skip if not reprocessing and variable exists
            if hasvar && ~REPRO, continue; end

            if ~hasvar
                nccreate(fout, SINKVAR, 'datatype','single', ...
                    'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            end
            ncwriteatt(fout, SINKVAR, 'units','kg m-2 s-1');
            ncwriteatt(fout, SINKVAR, 'expressed_as','carbon');
            ncwriteatt(fout, SINKVAR, 'long_name','Atmospheric correction');
            ncwrite(fout,    SINKVAR, single(sink));

            % Write NEE too for clarity
            try
                nccreate(fout, 'NEE', 'datatype','single', ...
                    'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            end
            ncwriteatt(fout, 'NEE', 'units','kg m-2 s-1');
            ncwriteatt(fout, 'NEE', 'expressed_as','carbon');
            ncwriteatt(fout, 'NEE', 'long_name','Net ecosystem exchange');
            ncwrite(fout,    'NEE', single(hetr-sink-npp));
        end

        % Monthly
        % ---
        dnowout = [MIROOT, '/monthly/', syear];
        dnowin  = [MIROOT, '/daily/',   syear, '/', smon];
        fout = [dnowout, '/MiCASA_v', VERSION, '_flux_', restag, ...
            '_monthly_', syear, smon, '.', FEXT];
        fins = [dnowin,  '/MiCASA_v', VERSION, '_flux_', restag, ...
            '_daily_', syear, smon, '??.', FEXT];

        % Skip if file exists and not reprocessing
        if isfile(fout)
            if REPRO
                [status, result] = system(['rm ', fout]);
            else
                continue;
            end
        end

        % Skip if we don't have a whole month (brutal hack)
        [status, result] = system(['ls -1 ', fins, ' | wc -l']);
        if status ~= 0 || ~strcmp(result(1:2), num2str(monlen))
            continue;
        end

        % Make sure output folder exists
        if ~isfolder(dnowout)
            [status, result] = system(['mkdir -p ', dnowout]);
        end

        [status, result] = system(['ncra -O -h ', fins, ' ', fout]);

        time = datenum(nyear, nmon, 1) - datenum(startYearTime, 1, 1);

        % Fix time and time_bnds
        ncwriteatt(fout, 'time',      'cell_methods','time: minimum');
        ncwrite(fout,    'time', ...
             datenum(nyear, nmon, 1) - datenum(startYearTime, 1, 1));
        ncwriteatt(fout, 'time_bnds', 'cell_methods','time: minimum');
        ncwrite(fout,    'time_bnds', [time; time+monlen]);
    end
end
