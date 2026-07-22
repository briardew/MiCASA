%MAKE_SINK  Add atmospheric correction to MiCASA

% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2024-10-11	New version for MiCASA
%===============================================================================

RESWGT  = 0.0;						% Have tested 0.25 in the past
SINKWGT = 0.16;						% Hand-tuned, meant to be rough
SINKVAR = 'ATMC';

% INITIALIZE
%===============================================================================
lofi.setup;

% Build sink weights
lofi.make_sink_growth;
if lower(do_v1_bugs(1)) == 'n'
    lofi.make_sink_temp;
else
    lofi.make_sink_temp_v1;
end
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

    fprintf('\n');

    nnow = 1;
    nprv = 12;
    nday = 0;
    for nmon = 1:12
        smon = num2str(nmon, '%02u');
        monlen  = datenum(nyear,nmon+1,01) - datenum(nyear,nmon,01);
        monsink = 0;

        % Daily
        % ---
        for nd = 1:monlen
            % Always increment counters
            nday = nday + 1;
            if dnmids(nnow) < nday
                nprv = nnow;
                nnow = nnow + 1;
            end

            fbit = [FLUXHEAD, '_daily_', syear, smon, num2str(nd,'%02u'), '.', FEXT];
            fout = [DIROUT, '/daily/', syear, '/', smon, '/', fbit];

            if ~isfile(fout), continue; end

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

            % Skip if variable exists and not overwriting
            if hasvar && ~FORCE, continue; end

            disp(['Writing ', fbit, ' ...']);

            if ~hasvar
                nccreate(fout, SINKVAR, 'datatype','single', ...
                    'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            end
            ncwriteatt(fout, SINKVAR, 'long_name','Atmospheric correction');
            ncwriteatt(fout, SINKVAR, 'units','kg m-2 s-1');
            ncwriteatt(fout, SINKVAR, 'expressed_as','carbon');
            ncwrite(   fout, SINKVAR, single(sink));

            % Write NEE too for clarity
            try
                nccreate(fout, 'NEE', 'datatype','single', ...
                    'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            end
            ncwriteatt(fout, 'NEE', 'long_name','Net ecosystem exchange');
            ncwriteatt(fout, 'NEE', 'units','kg m-2 s-1');
            ncwriteatt(fout, 'NEE', 'expressed_as','carbon');
            ncwrite(   fout, 'NEE', single(hetr-sink-npp));
        end

        % Monthly
        % ---
        fbit = [FLUXHEAD, '_monthly_', syear, smon, '.', FEXT];
        fout = [DIROUT, '/monthly/', syear, '/', fbit];

        if ~isfile(fout), continue; end

        npp  = ncread(fout, 'NPP');
        hetr = ncread(fout, 'Rh');
        sink = monsink/monlen;

        % A little tricky since file should exist already
        hasvar = 0;
        try
            ncread(fout, SINKVAR);
            hasvar = 1;
        end

        % Skip if variable exists and not overwriting
        if hasvar && ~FORCE, continue; end

        disp(['Writing ', fbit, ' ...']);

        if ~hasvar
            nccreate(fout, SINKVAR, 'datatype','single', ...
                'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
        end
        ncwriteatt(fout, SINKVAR, 'long_name','Atmospheric correction');
        ncwriteatt(fout, SINKVAR, 'units','kg m-2 s-1');
        ncwriteatt(fout, SINKVAR, 'expressed_as','carbon');
        ncwrite(   fout, SINKVAR, single(sink));

        % Write NEE too for clarity
        try
            nccreate(fout, 'NEE', 'datatype','single', ...
                'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
        end
        ncwriteatt(fout, 'NEE', 'long_name','Net ecosystem exchange');
        ncwriteatt(fout, 'NEE', 'units','kg m-2 s-1');
        ncwriteatt(fout, 'NEE', 'expressed_as','carbon');
        ncwrite(   fout, 'NEE', single(hetr-sink-npp));
    end
end
