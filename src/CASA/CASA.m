% TODO
% * Read and write every day
% * Regrid or store (a couple TB) M2?
% * Think about parallelization (spatially trivial)
% * Be able to save/load current state (in netCDF)


% CASA = Carnegie-Ames-Stanford-Approach. biogeochemical model developed in
% the 1990s to simulate terrestrial carbon exchange. Further developed and
% accounted for fires; Global Fire Emissions Database (GFED)
clearvars -except runname
defineConstants

fluxes = {'NPP', 'RES', 'HER', 'FUE', 'COMwood', 'COMherb', ...
    }; 
%    'COMdefo', 'COMpeat'};
% Above doesn't work before COMdefo and COMpeat only begin after spinup (***FIXME***)
nflux = length(fluxes);
for ii = 1:nflux
    fluxname = fluxes{ii};
    eval([fluxname '_timeseries = [];']);
end

NSTEPS = 12; % Currently only support monthly spinup
if lower(do_spinup_stage1(1)) == 'y'
    % Read input datasets and set parameter values
    loadCASAinput
    defineArrays
    doLatitude
    getSoilParams
    getSoilMoistureParams
    doOptimumTemperature
    getFuelWood

    % Run soil moisture and NPP in equilibrium
    disp(['Running ', runname, ' ...']);
    for year = spinUpYear1:spinUpYear1+2
        tic;
        doLeafRootShedding
        for step = 1:NSTEPS
            updateCASAinput

            doPET
            doSoilMoisture
            doNPP
            doHerbivory
            getFireParams
            doTreeCarbon
            doHerbCarbon

            processData
        end
        disp(['Year ', int2str(year), ', time used = ', ...
            int2str(toc), ' seconds']);
    end

    % Run carbon pools in equilibrium
    for year = spinUpYear1+3:spinUpYear2-1
        tic;
        for step = 1:NSTEPS
            updateCASAinput

            doPET
            doSoilMoisture
            doNPP
            doHerbivory
            getFireParams
            doTreeCarbon
            doHerbCarbon
            doDefoCarbon

            processData
            saveData
        end

        disp(['Year ', int2str(year), ', time used = ', ...
            int2str(toc), ' seconds']);
    end

    save([DIRNAT, '/spinUp_stage1.mat'], '-v7');
else
    % The stage1 data only needs to be loaded if it is going to be used by stage2
    if lower(do_spinup_stage2(1)) == 'y'
        % Allows sharing of spinup/restart across runs
        load([DIRNAT, '/spinUp_stage1.mat'], '-regexp', '^(?!runname$|frestart$).');
        defineConstants
    end
end

if lower(do_spinup_stage2(1)) == 'y'
    for year = spinUpYear2:startYear-1
        tic;
        for step = 1:NSTEPS
            updateCASAinput

            doPET
            doSoilMoisture
            doNPP
            doHerbivory
            getFireParams
            doTreeCarbon
            doHerbCarbon
            doDefoCarbon

            processData
            saveData
            if year == startYear - SOCadjustYear  % adjust soil C pools + turnover rates
                adjustSoilC
            end
        end

        disp(['Year ', int2str(year), ', time used = ', ...
            int2str(toc), ' seconds']);
    end
    save([DIRNAT, '/spinUp_stage2.mat'], '-v7');
else
    % Allows sharing of spinup/restart across runs
    load([DIRNAT, '/spinUp_stage2.mat'], '-regexp', '^(?!runname$|frestart$).');
    defineConstants
end

% Begin from restart if requested
frestart = [DIRNAT, '/restart.mat'];
if lower(do_restart_load(1)) == 'y' && exist(frestart,'file')
    % Allows sharing of spinup/restart across runs
    load(frestart, '-regexp', '^(?!runname$|frestart$).');
    defineConstants;

    startYear = year;
end

% Run individual years with annual driver data
for year = startYear:endYear
    if lower(do_daily(1)) == 'y'
        NSTEPS = datenum(year+1,01,01) - datenum(year,01,01);

        % Scale rates set by getSoilParams and adjustSoilC to daily timestep
        K_wood     = K_woodmo     * (12/NSTEPS);
        K_froot    = K_frootmo    * (12/NSTEPS);
        K_leaf     = K_leafmo     * (12/NSTEPS);
        K_hleaf    = K_hleafmo    * (12/NSTEPS);
        K_hfroot   = K_hfrootmo   * (12/NSTEPS);
        K_surfmet  = K_surfmetmo  * (12/NSTEPS);
        K_surfstr  = K_surfstrmo  * (12/NSTEPS);
        K_soilmet  = K_soilmetmo  * (12/NSTEPS);
        K_soilstr  = K_soilstrmo  * (12/NSTEPS);
        K_cwd      = K_cwdmo      * (12/NSTEPS);
        K_surfmic  = K_surfmicmo  * (12/NSTEPS);
        K_soilmic  = K_soilmicmo  * (12/NSTEPS);
        K_slow     = K_slowmo     * (12/NSTEPS);
        K_hslow    = K_hslowmo    * (12/NSTEPS);
        K_armored  = K_armoredmo  * (12/NSTEPS);
        K_harmored = K_harmoredmo * (12/NSTEPS);

        % Redo fuel wood calculation with correct scale
        getFuelWood
    end

    % Begin from restart if requested
    startStep = 1;
    if year == startYear && lower(do_restart_load(1)) == 'y' ...
        && exist(frestart,'file')
        startStep = step + 1;
    end

    tic;
    doLeafRootShedding
    for step = startStep:NSTEPS
        % Allow for soft exiting when we've run out of input
        try
            updateCASAinput
        catch
            disp('Could not load input ...');
            return;
        end

        doPET
        doSoilMoisture
        doNPP
        doHerbivory
        getFireParams
        doTreeCarbon
        doDefoCarbon
        doHerbCarbon

        processData
        saveData
        if lower(do_restart_all(1)) == 'y'
            save(frestart, '-v7');
        end
    end

    % Save annual restart no matter what
    save(frestart, '-v7');

    disp(['Year ', int2str(year), ', time used = ', ...
        int2str(toc), ' seconds']);
end
