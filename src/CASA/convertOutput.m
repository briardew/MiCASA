% Don't bother fixing this too much as I'd like to move to the
% Python version

defineConstants;

% Timestamp settings
TSTAMP = ['days since ', num2str(startYearTime), '-01-01'];

% Directories and versioning
DIRIN   = [DIRCASA, '/', runname, '/native'];
DIROUT  = [DIRCASA, '/', runname, '/holding'];

% Herbivory settings
ADDHER  = 1;					% Add herbivory to respiration?
VARHER  = 'HER';				% Herbivory variable name

% Output file settings
% ---
% Shouldn't this be in defineConstants?
FEXT    = 'nc4';
FORMAT  = 'netcdf4';
% We do these afterwards since Matlab appears to have memory issues
% It is also quite long
%DEFLATE = 9;
%SHUFFLE = true;
DEFLATE = 0;
SHUFFLE = false;

TOKGCSEC = 1.E-3/(60.*60.*24.);

% Structure defining what to process
% EET defined in Field et al. (1995; https://doi.org/10.1016/0034-4257(94)00066-V)
fluxes = [ ...
    struct('orig','NPP', 'name','NPP',   'long_name','Net primary productivity', ...
        'units','kg m-2 s-1', 'scale',TOKGCSEC, 'expressed_as','carbon'); ...
    struct('orig','RES', 'name','Rh',    'long_name','Heterotrophic respiration', ...
        'units','kg m-2 s-1', 'scale',TOKGCSEC, 'expressed_as','carbon'); ...
    struct('orig','FIRE', 'name','FIRE', 'long_name','Fire emission', ...
        'units','kg m-2 s-1', 'scale',TOKGCSEC, 'expressed_as','carbon'); ...
    struct('orig','FUE',  'name','FUEL', 'long_name','Fuel wood emission', ...
        'units','kg m-2 s-1', 'scale',TOKGCSEC, 'expressed_as','carbon'); ...
];
extras = [ ...
    struct('orig','HER','name','HER', 'long_name','Herbivory emission', ...
        'units','kg m-2 s-1', 'scale',TOKGCSEC, 'expressed_as','carbon'); ...
    struct('orig','EET', 'name','ET', 'long_name','Evapotranspiration', ...
        'units','mm month-1', 'scale',1.0, 'expressed_as',''); ...
    struct('orig','soilm', 'name','SOILM', 'long_name','Soil moisture', ...
        'units','mm', 'scale', 1.0, 'expressed_as',''); ...
    struct('orig','NPPtemp', 'name','NPPtemp', ...
        'long_name','Net primary productivity temperature constraint', ...
        'units','kg m-2 s-1', 'scale',TOKGCSEC, 'expressed_as','carbon'); ...
    struct('orig','NPPmoist', 'name','NPPmoist', ...
        'long_name','Net primary productivity moisture constraint', ...
        'units','kg m-2 s-1', 'scale',TOKGCSEC, 'expressed_as','carbon'); ...
];

% RUN
%==============================================================================
if lower(do_reprocess(1)) == 'y'
    disp('Reprocessing ... Press any key to continue');
    pause;
end
if ADDHER, disp('Adding herbivory to respiration ...'); end

datasets = [fluxes; extras];

% For extracting variables
vaux = load([DIRCASA, '/', runname, '/spinup1.mat'], 'mask', 'latitude');
mask = vaux.mask';
inds = find(mask(:) == 1);
temp = single(zeros(size(mask)));

% For debugging
test = zeros(size(mask));
test(inds) = vaux.latitude;
test = fliplr(test);

for year = startYear:endYear
    tic;
    syear = num2str(year);

    % Daily
    % ---
    if lower(do_daily(1)) == 'y'
        for mon = 1:12
            smon  = num2str(mon, '%02u');
            molen = datenum(year,mon+1,01) - datenum(year,mon,01);

            % Read & create fluxes file
            % ---
            for nd = 1:molen
                dvec = datevec(datenum(year, mon, 1) + nd - 1);
                sday = num2str(dvec(3), '%02u');

                dnowin  = [DIRIN,  '/', syear, '/', smon, '/', sday];
                dnowout = [DIROUT, '/daily/', syear, '/', smon];

                fbit = ['MiCASA_v', VERSION, '_flux_', CASARES, ...
                    '_daily_', syear, smon, sday, '.', FEXT];
                fout = [dnowout, '/', fbit];

                % Skip if file exists and not reprocessing
                if isfile(fout)
                    if lower(do_reprocess(1)) == 'y'
                        [status, result] = system(['rm ', fout]);
                    else
                        continue;
                    end
                end

                % Check inputs exist before creating
                skip = 0;
                for nn = 1:numel(fluxes)
                    fin = [dnowin, '/', fluxes(nn).orig, '.mat'];
                    if ~isfile(fin) && ~strcmp(fluxes(nn).orig, 'FIRE')
                        skip = 1;
                    end
                end
                if skip, continue; end

                % Make sure output folder exists
                if ~isfolder(dnowout)
                    [status, result] = system(['mkdir -p ', dnowout]);
                end

                time = datenum(year, mon, 1) - datenum(startYearTime, 1, 1) + nd - 1;

                nccreate(fout,   'lat', 'dimensions',{'lat',NLAT}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                ncwriteatt(fout, 'lat', 'units','degrees_north');
                ncwriteatt(fout, 'lat', 'long_name','latitude');
                ncwrite(fout,    'lat', lat);

                nccreate(fout,   'lon', 'dimensions',{'lon',NLON}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                ncwriteatt(fout, 'lon', 'units','degrees_east');
                ncwriteatt(fout, 'lon', 'long_name','longitude');
                ncwrite(fout,    'lon', lon);

                nccreate(fout,   'time', 'dimensions',{'time',inf}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                ncwriteatt(fout, 'time', 'units',TSTAMP);
                ncwriteatt(fout, 'time', 'long_name','time');
                ncwriteatt(fout, 'time', 'bounds','time_bnds');
                ncwriteatt(fout, 'time', 'calendar','standard');
                ncwrite(fout,    'time', time);

                nccreate(fout,   'time_bnds', ...
                    'dimensions', {'nv',2, 'time',inf}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                ncwriteatt(fout, 'time_bnds', 'units',TSTAMP);
                ncwriteatt(fout, 'time_bnds', 'long_name','time bounds');
                ncwrite(fout,    'time_bnds', [time; time+1]);

                for nn = 1:numel(fluxes)
                    vin   = fluxes(nn).orig;
                    vout  = fluxes(nn).name;
                    units = fluxes(nn).units;
                    scale = fluxes(nn).scale;
                    lname = fluxes(nn).long_name;
                    expra = fluxes(nn).expressed_as;

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

                    % Add herbivory to respiration?
                    if strcmp(vin, 'RES') && ADDHER
                        tempin = tempin + load([dnowin, '/', VARHER, '.mat']).(VARHER);
                    end

                    % Reshape
                    temp(inds) = tempin;
                    xx = fliplr(temp);

                    % Write dataset
                    nccreate(fout,   vout, 'datatype','single', ...
                        'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                    ncwriteatt(fout, vout, 'units',units);
                    if numel(expra) > 0
                        ncwriteatt(fout, vout, 'expressed_as',expra);
                    end
                    ncwriteatt(fout, vout, 'long_name',lname);
                    ncwrite(fout,    vout, single(xx*scale));
                end
            end

            % Read & create extras file
            % ---
            for nd = 1:molen
                dvec = datevec(datenum(year, mon, 1) + nd - 1);
                sday = num2str(dvec(3), '%02u');

                dnowin  = [DIRIN,  '/', syear, '/', smon, '/', sday];
                dnowout = [DIROUT, '/daily/', syear, '/', smon];

                fbit = ['MiCASA_v', VERSION, '_extra_', CASARES, ...
                    '_daily_', syear, smon, sday, '.', FEXT];
                fout = [dnowout, '/', fbit];

                % Skip if file exists and not reprocessing
                if isfile(fout)
                    if lower(do_reprocess(1)) == 'y'
                        [status, result] = system(['rm ', fout]);
                    else
                        continue;
                    end
                end

                % Check inputs exist before creating
                skip = 0;
                for nn = 1:numel(extras)
                    fin = [dnowin, '/', extras(nn).orig, '.mat'];
                    if ~isfile(fin)
                        skip = 1;
                    end
                end
                if skip, continue; end

                % Make sure output folder exists
                if ~isfolder(dnowout)
                    [status, result] = system(['mkdir -p ', dnowout]);
                end

                time = datenum(year, mon, 1) - datenum(startYearTime, 1, 1) + nd - 1;

                nccreate(fout,   'lat', 'dimensions',{'lat',NLAT}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                ncwriteatt(fout, 'lat', 'units','degrees_north');
                ncwriteatt(fout, 'lat', 'long_name','latitude');
                ncwrite(fout,    'lat', lat);

                nccreate(fout,   'lon', 'dimensions',{'lon',NLON}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                ncwriteatt(fout, 'lon', 'units','degrees_east');
                ncwriteatt(fout, 'lon', 'long_name','longitude');
                ncwrite(fout,    'lon', lon);

                nccreate(fout,   'time', 'dimensions',{'time',inf}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                ncwriteatt(fout, 'time', 'long_name','time');
                ncwriteatt(fout, 'time', 'units',TSTAMP);
                ncwriteatt(fout, 'time', 'bounds','time_bnds');
                ncwrite(fout,    'time', time);

                nccreate(fout,   'time_bnds', ...
                    'dimensions', {'nv',2, 'time',inf}, ...
                    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                ncwriteatt(fout, 'time_bnds', 'units',TSTAMP);
                ncwriteatt(fout, 'time_bnds', 'long_name','time bounds');
                ncwrite(fout,    'time_bnds', [time; time+1]);

                for nn = 1:numel(extras)
                    vin   = extras(nn).orig;
                    vout  = extras(nn).name;
                    units = extras(nn).units;
                    scale = extras(nn).scale;
                    lname = extras(nn).long_name;
                    expra = extras(nn).expressed_as;

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

                    % Add herbivory to respiration?
                    if strcmp(vin, 'RES') && ADDHER
                        tempin = tempin + load([dnowin, '/', VARHER, '.mat']).(VARHER);
                    end

                    % Reshape
                    temp(inds) = tempin;
                    xx = fliplr(temp);

                    % Write dataset
                    nccreate(fout,   vout, 'datatype','single', ...
                        'dimensions',{'lon',NLON, 'lat',NLAT, 'time',inf}, ...
                        'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
                    ncwrite(fout,    vout, single(xx*scale));
                    ncwriteatt(fout, vout, 'units',units);
                    if numel(expra) > 0
                        ncwriteatt(fout, vout, 'expressed_as',expra);
                    end
                    ncwriteatt(fout, vout, 'long_name',lname);
                end
            end
        end

    % Monthly
    % ---
    else
        % Make sure output folder exists
        if ~isfolder(DIROUT)
            [status, result] = system(['mkdir -p ', DIROUT]);
        end

        NSTEPS = 12;
        for nn = 1:numel(datasets)
            vin   = datasets(nn).orig;
            vout  = datasets(nn).name;
            units = datasets(nn).units;
            scale = datasets(nn).scale*30.5;
            lname = datasets(nn).long_name;

            fout  = [DIROUT, '/', vout, '_', CASARES, ...
                '_monthly_', syear, '.', FEXT];

            xx = zeros(NLON, NLAT, NSTEPS);

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

            % Reshape
            for nt = 1:NSTEPS
                temp(inds) = tempin(:,nt);
                xx(:,:,nt) = fliplr(temp);
            end

            if lower(do_reprocess(1)) == 'y'
                [status, result] = system(['rm ', fout]);
            end

            nccreate(fout,   'lat', 'dimensions',{'lat',NLAT}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwriteatt(fout, 'lat', 'units','degrees_north');
            ncwriteatt(fout, 'lat', 'long_name','latitude');
            ncwrite(fout,    'lat', lat);

            nccreate(fout,   'lon', 'dimensions',{'lon',NLON}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwriteatt(fout, 'lon', 'units','degrees_east');
            ncwriteatt(fout, 'lon', 'long_name','longitude');
            ncwrite(fout,    'lon', lon);

            % Change this to a CF-compliant time with bounds (***FIXME***)
            nccreate(fout, 'month', 'dimensions',{'month',NSTEPS}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwrite(fout,  'month', [1:NSTEPS]');

            % 30.5 is month to day conversion (***FIXME***)
            nccreate(fout,   vout, 'datatype','single', ...
                'dimensions',{'lon',NLON, 'lat',NLAT, 'month',NSTEPS}, ...
                'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
            ncwrite(fout,    vout, single(xx*scale));
            ncwriteatt(fout, vout, 'units',units);
            ncwriteatt(fout, vout, 'long_name',lname);
        end
    end

    disp(['Year ', syear, ', time used = ', int2str(toc), ' seconds']);
end
