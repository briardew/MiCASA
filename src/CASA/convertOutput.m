% TODO:
% 1. Add monthly metadata entries to colls structure
% 2. Finish monthly means of daily output
% 3. Add metadata to monthly output

defineConstants;

% Space-time details
TSTAMP  = ['days since ', num2str(startYearTime), '-01-01'];

% Directories and versioning
DIRIN   = [DIRRUN, '/native'];
DIROUT  = [DIRRUN, '/netcdf'];

% Herbivory settings
ADDHER = 1;					% Add herbivory to respiration?
VARHER = 'HER';					% Herbivory variable name

% Compress monthly files since they are final
if lower(do_daily(1)) ~= 'y'
    DEFLATE = 9;
    SHUFFLE = true;
end

% Collection definition structure
colls = [ ...
    struct( ...
        'name', 'flux', ...
        'long', 'NPP Rh ATMC NEE FIRE FUEL Fluxes', ...
        'comment', [ ...
            'Positive NPP indicates uptake by vegetation. Positive Rh ', ...
            'indicates emission to the atmosphere. NEE = Rh - NPP - ATMC, and ', ...
            'NBE = NEE + FIRE + FUEL. ATMC adjusts net exchange to account for ', ...
            'missing processes and better match long-term atmospheric budgets.' ...
        ] ...
    ), ...
    struct( ...
        'name', 'extra', ...
        'long', 'Extra Variables', ...
        'comment', '' ...
    ), ...
    struct( ...
        'name', 'fire', ...
        'long', 'Biomass Burning Components', ...
        'comment', '' ...
    ), ...
];

% Dataset definition structure
% EET defined in Field et al. (1995; https://doi.org/10.1016/0034-4257(94)00066-V)
datasets = [ ...
    struct('coll','flux', 'orig','NPP', 'name','NPP', ...
        'long_name','Net primary productivity', ...
        'units','kg m-2 s-1', 'scale',1.0E-3/DAYSEC, 'rate',1, ...
        'expressed_as','carbon'); ...
    struct('coll','flux', 'orig','RES', 'name','Rh', ...
        'long_name','Heterotrophic respiration', ...
        'units','kg m-2 s-1', 'scale',1.0E-3/DAYSEC, 'rate',1, ...
        'expressed_as','carbon'); ...
    struct('coll','flux', 'orig','FIRE', 'name','FIRE', ...
        'long_name','Fire emission', ...
        'units','kg m-2 s-1', 'scale',1.0E-3/DAYSEC, 'rate',1, ...
        'expressed_as','carbon'); ...
    struct('coll','flux', 'orig','FUE',  'name','FUEL', ...
        'long_name','Fuel wood emission', ...
        'units','kg m-2 s-1', 'scale',1.0E-3/DAYSEC, 'rate',1, ...
        'expressed_as','carbon'); ...
    struct('coll','extra', 'orig','HER','name','HER', ...
        'long_name','Herbivory emission', ...
        'units','kg m-2 s-1', 'scale',1.0E-3/DAYSEC, 'rate',1, ...
        'expressed_as','carbon'); ...
    struct('coll','extra', 'orig','EET', 'name','ET', ...
        'long_name','Evapotranspiration', ...
        'units','mm s-1', 'scale',1.0/DAYSEC, 'rate',1, ...
        'expressed_as',''); ...
    struct('coll','extra', 'orig','soilm', 'name','SOILM', ...
        'long_name','Soil moisture', ...
        'units','mm', 'scale',1.0, 'rate',0, 'expressed_as',''); ...
    struct('coll','extra', 'orig','AGBD', 'name','AGBD', ...
        'long_name','Aboveground (woody) Biomass Density', ...
        'units','g m-2', 'scale',1.0, 'rate',0, 'expressed_as',''); ...
    struct('coll','fire', 'orig','COMherb', 'name','FIREherb', ...
        'long_name','Fire emission (herbaceous)', ...
        'units','kg m-2 s-1', 'scale',1.0E-3/DAYSEC, 'rate',1, ...
        'expressed_as','carbon'); ...
    struct('coll','fire', 'orig','COMwood', 'name','FIREwood', ...
        'long_name','Fire emission (woody)', ...
        'units','kg m-2 s-1', 'scale',1.0E-3/DAYSEC, 'rate',1, ...
        'expressed_as','carbon'); ...
    struct('coll','fire', 'orig','COMdefo', 'name','FIREdefo', ...
        'long_name','Fire emission (deforestation)', ...
        'units','kg m-2 s-1', 'scale',1.0E-3/DAYSEC, 'rate',1, ...
        'expressed_as','carbon'); ...
    struct('coll','fire', 'orig','COMpeat', 'name','FIREpeat', ...
        'long_name','Fire emission (peat)', ...
        'units','kg m-2 s-1', 'scale',1.0E-3/DAYSEC, 'rate',1, ...
        'expressed_as','carbon'); ...
%   struct('coll','debug', 'orig','NPPtemp', 'name','NPPtemp', ...
%       'long_name','Net primary productivity temperature constraint', ...
%       'units','kg m-2 s-1', 'scale',1.0E-3/DAYSEC, 'rate',1, ...
%       'expressed_as','carbon'); ...
%   struct('coll','debug', 'orig','NPPmoist', 'name','NPPmoist', ...
%       'long_name','Net primary productivity moisture constraint', ...
%       'units','kg m-2 s-1', 'scale',1.0E-3/DAYSEC, 'rate',1, ...
%       'expressed_as','carbon'); ...
];

% RUN
%==============================================================================
% Make sure the NCO utilities are available
[status, result] = system('ncra --version');
if status ~= 0
    error(sprintf([...
        '*** Missing NCO utilities ***\n\n', ...
        'On NCCS Discover, run\n', ...
        '    > module load nco\n', ...
        'from the terminal before starting Octave/Matlab.']));
end

if FORCE
    disp('Force overwriting ... Press any key to continue');
    pause;
end
if ADDHER, disp('Adding herbivory to respiration ...'); end

% For extracting variables
fspinup = [DIRRUN, '/spinup2.mat'];
if ~isfile(fspinup)
    fspinup = [DIRRUN, '/spinup/spinup2.mat'];
end
vaux = load(fspinup, 'mask', 'latitude');
mast = vaux.mask';
inds = find(mast(:) == 1);
temp = zeros(size(mast));

% For debugging
test = zeros(size(mast));
test(inds) = vaux.latitude;
test = fliplr(test);

for year = startYear:endYear
    tic;
    syear = num2str(year);

    % Daily output
    % ===
    if lower(do_daily(1)) == 'y'
        for mon = 1:12
            smon = num2str(mon, '%02u');
            monlen = datenum(year,mon+1,01) - datenum(year,mon,01);

            for nd = 1:monlen
                sday = num2str(nd, '%02u');

                dnowin  = [DIRIN,  '/', syear, '/', smon, '/', sday];
                dnowout = [DIROUT, '/daily/', syear, '/', smon];

                % Check for inputs before creating anything
                skip = 1;
                for nn = 1:numel(datasets)
                    fin = [dnowin, '/', datasets(nn).orig, '.mat'];
                    if isfile(fin)
                        skip = 0;
                    end
                end
                if skip, continue; end

                % Make sure output folder exists
                if ~isfolder(dnowout)
                    [status, result] = system(['mkdir -p ', dnowout]);
                end

                for nn = 1:numel(colls)
                    fbit = [PRODUCT, '_v', VERSION, '_', colls(nn).name, '_', ...
                        CASARES, '_daily_', syear, smon, sday, '.', FEXT];
                    fout = [dnowout, '/', fbit];

                    % Skip if file exists and not overwriting
                    if isfile(fout)
                        if FORCE
                            [status, result] = system(['rm ', fout]);
                        else
                            continue;
                        end
                    end

                    dnum = datenum(year, mon, nd);
                    time = dnum - datenum(startYearTime, 1, 1);

                    nccreate(  fout, 'time', 'dimensions',{'time',inf}, ...
                        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                    ncwriteatt(fout, 'time', 'long_name','time');
                    ncwriteatt(fout, 'time', 'units',TSTAMP);
                    ncwriteatt(fout, 'time', 'calendar','proleptic_gregorian');
                    ncwriteatt(fout, 'time', 'bounds','time_bnds');
                    ncwrite(   fout, 'time', time);

                    nccreate(  fout, 'time_bnds', ...
                        'dimensions', {'nv',2, 'time',inf}, ...
                        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                    ncwriteatt(fout, 'time_bnds', 'long_name','time bounds');
                    ncwrite(   fout, 'time_bnds', [time; time+1]);

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

                    shortname = [upper(PRODUCT), '_', upper(colls(nn).name), '_D'];
                    longname  = [PRODUCT, ' Daily ', colls(nn).long, ' ', RESLONG];
                    ncwriteatt(fout, '/', 'ShortName',   shortname);
                    ncwriteatt(fout, '/', 'LongName',    longname);
                    ncwriteatt(fout, '/', 'title',       [longname, ' v', VERSION]);
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
                    if numel(colls(nn).comment) > 0
                        ncwriteatt(fout, '/', 'comment', colls(nn).comment);
                    end
                    ncwriteatt(fout, '/', 'GranuleID',   fbit);
                    ncwriteatt(fout, '/', 'history',     ...
                        ['Created on ', datestr(now, 'yyyy-mm-ddTHH:MM:SS.FFF000')]);
                    ncwriteatt(fout, '/', 'stage', 'intermediate');
                end

                for nn = 1:numel(datasets)
                    coll  = datasets(nn).coll;
                    vin   = datasets(nn).orig;
                    vout  = datasets(nn).name;
                    units = datasets(nn).units;
                    scale = datasets(nn).scale;
                    lname = datasets(nn).long_name;
                    expra = datasets(nn).expressed_as;

                    fbit = [PRODUCT, '_v', VERSION, '_', coll, '_', CASARES, ...
                        '_daily_', syear, smon, sday, '.', FEXT];
                    fout = [dnowout, '/', fbit];

                    % Allow for backwards compatibility if dataset wasn't output
                    try
                        if strcmp(vin, 'FIRE')
                            vdefo = 'COMdefo';
                            vherb = 'COMherb';
                            vpeat = 'COMpeat';
                            vwood = 'COMwood';
                            tempin = load([dnowin, '/', vdefo, '.mat']).(vdefo) ...
                                   + load([dnowin, '/', vherb, '.mat']).(vherb) ...
                                   + load([dnowin, '/', vpeat, '.mat']).(vpeat) ...
                                   + load([dnowin, '/', vwood, '.mat']).(vwood);
                        else
                            tempin = load([dnowin, '/', vin, '.mat']).(vin);
                        end
                    catch
                        continue
                    end

                    % Add herbivory to respiration?
                    if strcmp(vin, 'RES') && ADDHER
                        tempin = tempin + load([dnowin, '/', VARHER, '.mat']).(VARHER);
                    end

                    % Reshape & scale
                    temp(inds) = tempin;
                    xx = scale * fliplr(temp);

                    % Write dataset
                    try
                        ncread(fout, vout);
                    catch
                        nccreate(  fout, vout, 'datatype','single', ...
                            'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                            'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                        ncwriteatt(fout, vout, 'long_name',lname);
                        ncwriteatt(fout, vout, 'units',units);
                        if numel(expra) > 0
                            ncwriteatt(fout, vout, 'expressed_as',expra);
                        end
                        ncwrite(   fout, vout, single(xx));
                    end
                end
            end

            % Monthly means of daily output
            % ---
            for nn = 1:numel(colls)
                dnowin  = [DIROUT, '/daily/',   syear, '/', smon];
                dnowout = [DIROUT, '/monthly/', syear];
                fhead = [PRODUCT, '_v', VERSION, '_', colls(nn).name, '_', CASARES];
                fins  = [dnowin,  '/', fhead, '_daily_', syear, smon, '??.', FEXT];
                fbit  = [fhead, '_monthly_', syear, smon, '.', FEXT];
                fout  = [dnowout, '/', fbit];

                % Skip if file exists and not overwriting
                if isfile(fout)
                    if FORCE
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
                % The above will fail on the flux file if it doesn't have the sink
                % but other days do, for now we let it fail and come back later.
                % Presumably this only happens in NRT mode when you're running every
                % day. The monthly average will generate the next day (brutal hack)
                if status ~= 0
                    [status, result] = system(['rm ', fout, '.*.tmp']);
                    continue;
                end

                % Delete unwanted attributes and all global (to keep order)
                [status, result] = system(['ncatted -O -h -a cell_methods,,d,, ', fout]);
                [status, result] = system(['ncatted -O -h -a ,global,d,, ', fout]);

                dnum = datenum(year, mon, 1);
                time = dnum - datenum(startYearTime, 1, 1);

                % Fix time and time_bnds
                ncwrite(fout, 'time',      time);
                ncwrite(fout, 'time_bnds', [time; time+monlen]);

                % Fix metadata
                % NB: Changing an attribute's length will change its order
                % Delete all global attributes (above) and redefine to keep order
                shortname = [upper(PRODUCT), '_', upper(colls(nn).name), '_M'];
                longname  = [PRODUCT, ' Monthly ', colls(nn).long, ' ', RESLONG];
                ncwriteatt(fout, '/', 'ShortName',   shortname);
                ncwriteatt(fout, '/', 'LongName',    longname);
                ncwriteatt(fout, '/', 'title',       [longname, ' v', VERSION]);
                ncwriteatt(fout, '/', 'Conventions', CONVENTIONS);
                ncwriteatt(fout, '/', 'ProcessingLevel', '4');
                ncwriteatt(fout, '/', 'institution', INSTITUTION);
                ncwriteatt(fout, '/', 'contact',     CONTACT);
                ncwriteatt(fout, '/', 'SouthernmostLatitude', LATMIN);
                ncwriteatt(fout, '/', 'NorthernmostLatiude',  LATMAX);
                ncwriteatt(fout, '/', 'WesternmostLongitude', LONMIN);
                ncwriteatt(fout, '/', 'EasternmostLongitude', LONMAX);
                ncwriteatt(fout, '/', 'RangeBeginningDate',   ...
                    datestr(dnum, 'yyyy-mm-dd'));
                ncwriteatt(fout, '/', 'RangeBeginningTime',   '00:00:00.000000');
                ncwriteatt(fout, '/', 'RangeEndingDate',      ...
                    datestr(dnum+monlen-1, 'yyyy-mm-dd'));
                ncwriteatt(fout, '/', 'RangeEndingTime',      '23:59:59.999999');
                if numel(colls(nn).comment) > 0
                    ncwriteatt(fout, '/', 'comment', colls(nn).comment);
                end
                ncwriteatt(fout, '/', 'GranuleID',   fbit);
                ncwriteatt(fout, '/', 'history',     ...
                    ['Created on ', datestr(now, 'yyyy-mm-ddTHH:MM:SS.FFF000')]);
                ncwriteatt(fout, '/', 'stage', 'intermediate');
            end
        end

    % Monthly output
    % ===
    else
        monlens = zeros(12, 1);
        for mon = 1:12
            monlens(mon) = datenum(year,mon+1,01) - datenum(year,mon,01);
        end

        % Make sure output folder exists
        if ~isfolder(DIROUT)
            [status, result] = system(['mkdir -p ', DIROUT]);
        end

        for nn = 1:numel(datasets)
            vin   = datasets(nn).orig;
            vout  = datasets(nn).name;
            units = datasets(nn).units;
            scale = datasets(nn).scale;
            lname = datasets(nn).long_name;
            expra = datasets(nn).expressed_as;

            fout = [DIROUT, '/', vout, '_', CASARES, '_monthly_', syear, '.', FEXT];

            xx = zeros(NLON, NLAT, 12);

            % Read
            if strcmp(vin, 'FIRE')
                vdefo = ['COMdefo', syear];
                vherb = ['COMherb', syear];
                vpeat = ['COMpeat', syear];
                vwood = ['COMwood', syear];
                tempin = load([DIRIN, '/', vdefo, '.mat']).(vdefo) ...
                       + load([DIRIN, '/', vherb, '.mat']).(vherb) ...
                       + load([DIRIN, '/', vpeat, '.mat']).(vpeat) ...
                       + load([DIRIN, '/', vwood, '.mat']).(vwood);
            else
                vyear = [vin, syear];
                tempin = load([DIRIN, '/', vyear, '.mat']).(vyear);
            end

            % Add herbivory to respiration?
            if strcmp(vin, 'RES') && ADDHER
                vyear = [VARHER, syear];
                tempin = tempin + load([DIRIN, '/', vyear, '.mat']).(vyear);
            end

            % Compatibility bug fix: was catting on 3rd dim instead of 2nd
            tempin = squeeze(tempin);

            % Reshape & scale
            for nt = 1:12
                temp(inds) = tempin(:,nt);
                xx(:,:,nt) = scale * fliplr(temp);
                % Apply additional month to day conversion for fields that are rates
                % NB: This was wrong before and multiplied instead of divided
                if datasets(nn).rate
                    xx(:,:,nt) = xx(:,:,nt) / monlens(nt);
                end
            end

            if FORCE
                [status, result] = system(['rm ', fout]);
            end

            time = datenum(year, 1, 1) - datenum(startYearTime, 1, 1) ...
                + [0; cumsum(monlens(1:end-1))]';

            nccreate(  fout, 'time', 'dimensions',{'time',inf}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwriteatt(fout, 'time', 'long_name','time');
            ncwriteatt(fout, 'time', 'units',TSTAMP);
            ncwriteatt(fout, 'time', 'calendar','proleptic_gregorian');
            ncwriteatt(fout, 'time', 'bounds','time_bnds');
            ncwrite(   fout, 'time', time);

            nccreate(  fout, 'time_bnds', ...
                'dimensions', {'nv',2, 'time',inf}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwriteatt(fout, 'time_bnds', 'long_name','time bounds');
            ncwrite(   fout, 'time_bnds', [time; time+monlens']);

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

            nccreate(  fout, vout, 'datatype','single', ...
                'dimensions',{'lon',NLON, 'lat',NLAT, 'time',12}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwriteatt(fout, vout, 'long_name',lname);
            ncwriteatt(fout, vout, 'units',units);
            if numel(expra) > 0
                ncwriteatt(fout, vout, 'expressed_as',expra);
            end
            ncwrite(   fout, vout, single(xx));

            shortname = [upper(PRODUCT), '_', upper(colls(nn).name), '_M'];
            longname  = [PRODUCT, ' Monthly ', colls(nn).long, ' ', RESLONG];
            ncwriteatt(fout, '/', 'ShortName',   shortname);
            ncwriteatt(fout, '/', 'LongName',    longname);
            ncwriteatt(fout, '/', 'title',       [longname, ' v', VERSION]);
            ncwriteatt(fout, '/', 'Conventions', CONVENTIONS);
            ncwriteatt(fout, '/', 'ProcessingLevel', '4');
            ncwriteatt(fout, '/', 'institution', INSTITUTION);
            ncwriteatt(fout, '/', 'contact',     CONTACT);
            ncwriteatt(fout, '/', 'SouthernmostLatitude', LATMIN);
            ncwriteatt(fout, '/', 'NorthernmostLatiude',  LATMAX);
            ncwriteatt(fout, '/', 'WesternmostLongitude', LONMIN);
            ncwriteatt(fout, '/', 'EasternmostLongitude', LONMAX);
            ncwriteatt(fout, '/', 'RangeBeginningDate',   [syear, '-01-01']);
            ncwriteatt(fout, '/', 'RangeBeginningTime',   '00:00:00.000000');
            ncwriteatt(fout, '/', 'RangeEndingDate',      [syear, '-12-31']);
            ncwriteatt(fout, '/', 'RangeEndingTime',      '23:59:59.999999');
            if numel(colls(nn).comment) > 0
                ncwriteatt(fout, '/', 'comment', colls(nn).comment);
            end
            ncwriteatt(fout, '/', 'GranuleID',   fbit);
            ncwriteatt(fout, '/', 'history',     ...
                ['Created on ', datestr(now, 'yyyy-mm-ddTHH:MM:SS.FFF000')]);
        end
    end

    disp(['Year ', syear, ', time used = ', int2str(toc), ' seconds']);
end
