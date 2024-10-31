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

% Build sink weights
lofi.make_sink_prep1;
lofi.make_sink_prep2;
dtwgt = dtpos + RESWGT*dtneg;


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
            fname = [syear, '/', smon, ...
                '/MiCASA_v', VERSION, '_flux_x3600_y1800_daily_', ...
                syear, smon, num2str(nd,'%02u'), '.', FEXT];
            ff = [MIROOT, '/daily/', fname];

            if ~isfile(ff), continue; end

            nday = nday + 1;
            if dnmids(nnow) < nday
                nprv = nnow;
                nnow = nnow + 1;
            end
            wwprv = (dnmids(nnow) - nday)/(dnmids(nnow) - dnmids(nprv));
            % Hack to avoid pasting January onto end of dtwgt
            dtnow = wwprv*dtwgt(:,:,nprv) + (1 - wwprv)*dtwgt(:,:,mod(nprv,12)+1);

            npp  = ncread(ff, 'NPP');
            hetr = ncread(ff, 'Rh');

            sink = SINKWGT * fsink(ao,nyear+nday/yrlen) * dtnow .* hetr;
            sink = min(hetr, single(sink));
            monsink = monsink + sink;

            % A little tricky since file should exist already        
            hasvar = 0;
            try
                ncread(ff, SINKVAR);
                hasvar = 1;
            end

            % Skip if not reprocessing and variable exists
            if hasvar && ~REPRO, continue; end

            if ~hasvar
                nccreate(ff, SINKVAR, 'datatype','single', ...
                    'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            end
            ncwriteatt(ff, SINKVAR, 'units','kg m-2 s-1');
            ncwriteatt(ff, SINKVAR, 'expressed_as','carbon');
            ncwriteatt(ff, SINKVAR, 'long_name','Atmospheric correction');
            ncwrite(ff,    SINKVAR, single(sink));

           % Write NEE too for clarity
           try
                nccreate(ff, 'NEE', 'datatype','single', ...
                    'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            end
            ncwriteatt(ff, 'NEE', 'units','kg m-2 s-1');
            ncwriteatt(ff, 'NEE', 'expressed_as','carbon');
            ncwriteatt(ff, 'NEE', 'long_name','Net ecosystem exchange');
            ncwrite(ff,    'NEE', single(hetr-sink-npp));
        end

        % Monthly
        % ---
        fname = [syear, '/MiCASA_v', VERSION, '_flux_x3600_y1800_monthly_', ...
            syear, smon, '.', FEXT];
        ff = [MIROOT, '/monthly/', fname];

        if ~isfile(ff), continue; end

        monnpp  = ncread(ff, 'NPP');
        monhetr = ncread(ff, 'Rh');
        monsink = monsink/monlen;

        % A little tricky since file should exist already        
        hasvar = 0;
        try
            ncread(ff, SINKVAR);
            hasvar = 1;
        end

        % Skip if not reprocessing and variable exists
        if hasvar && ~REPRO, continue; end

        if ~hasvar
            nccreate(ff, SINKVAR, 'datatype','single', ...
                'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
        end
        ncwriteatt(ff, SINKVAR, 'units','kg m-2 s-1');
        ncwriteatt(ff, SINKVAR, 'expressed_as','carbon');
        ncwriteatt(ff, SINKVAR, 'long_name','Atmospheric correction');
        ncwrite(ff,    SINKVAR, single(monsink));

        % Write NEE too for clarity
        try
            nccreate(ff, 'NEE', 'datatype','single', ...
                'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
        end
        ncwriteatt(ff, 'NEE', 'units','kg m-2 s-1');
        ncwriteatt(ff, 'NEE', 'expressed_as','carbon');
        ncwriteatt(ff, 'NEE', 'long_name','Net ecosystem exchange');
        ncwrite(ff,    'NEE', single(monhetr-monsink-monnpp));
    end
end
