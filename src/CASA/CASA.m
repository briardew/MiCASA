% TODO
% * Read and write every day
% * Regrid or store (a couple TB) M2?
% * Think about parallelization (spatially trivial)
% * Be able to save/load current state (in netCDF)



% CASA = Carnegie-Ames-Stanford-Approach. biogeochemical model developed in
% the 1990s to simulate terrestrial carbon exchange. Further developed and
% accounted for fires; Global Fire Emissions Database (GFED)
clear

do_spinup_stage1 = 'y'; 
do_spinup_stage2 = 'y'; 

spinUpYear_stage1 = 250;
spinUpYear_stage2 = 1750;

use_cropstate_emax = 'y'; 
use_sink = 'y';
use_crop_moisture = 'y';
use_crop_ppt_ratio = 'y';

spinUpYear   = single(spinUpYear_stage1);
spinUpYear_2 = single(spinUpYear_stage2);

%fluxes = {'NPP','RES','HER','FUE','COMwood','COMherb','COMdefo','COMpeat'};
% Above doesn't work before COMdefo and COMpeat only begin after spinup (FIXME)
fluxes = {'NPP','RES','HER','FUE','COMwood','COMherb'}; 
nflux = length(fluxes);
for ii = 1:nflux
    fluxname = fluxes{ii};
    eval([fluxname '_timeseries= [];'])
end

NSTEPS = 12; % Currently only support monthly spinup
if lower(do_spinup_stage1(1)) == 'y'
    %% read input datasets and set parameter values
    defineConstants
    loadCASAinput
    defineArrays
    doLatitude
    getSoilParams
    getSoilMoistureParams
    doOptimumTemperature
    getFuelWood

    %% run soil moisture and NPP in equilibrium
    disp(' running...')
    for year = spinUpYear:spinUpYear+2
        tic
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
        disp([' Year ' int2str(year) ', time used = ' int2str(toc) ' seconds'])
    end

    %% run carbon pools in equilibrium
    for year = spinUpYear+3:spinUpYear_2-1
        tic
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

        disp([' Year ' int2str(year) ', time used = ' int2str(toc) ' seconds'])
    end

    save([DIRCASA, '/', runname, '/native/latestrunSpinUpData_stage1.mat'], '-v7');
else
    % the stage1 data only needs to be loaded if it is going to be used by stage2
    if lower(do_spinup_stage2(1)) == 'y'
        load([DIRCASA, '/', runname, '/native/latestrunSpinUpData_stage1.mat']);
    end
end

if lower(do_spinup_stage2(1)) == 'y'
    for year = spinUpYear_2:startYear-1
        tic
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

        disp([' Year ' int2str(year) ', time used = ' int2str(toc) ' seconds'])
    end
    save([DIRCASA, '/', runname, '/native/latestrunSpinUpData_stage2.mat'], '-v7');
else
    load([DIRCASA, '/', runname, '/native/latestrunSpinUpData_stage2.mat']);
end

%% run individual years with annual driver data
for year = startYear:endYear
    if lower(do_daily(1)) == 'y'
        NSTEPS = datenum(year+1,01,01) - datenum(year,01,01);
    end

    tic
    doLeafRootShedding
    for step = 1:NSTEPS
        updateCASAinput

        disp('o');
        doPET
        doSoilMoisture
        doNPP
        doHerbivory
        getFireParams
        doTreeCarbon
        doDefoCarbon
        doHerbCarbon

        disp('x');
        processData
        saveData
    end

    disp([' Year ' int2str(year) ', time used = ' int2str(toc) ' seconds'])
end

for ii = 1:nflux
    fluxname = fluxes{ii};
    save([DIRCASA, '/', runname, '/native/', fluxname, '_timeseries.mat'], ...
        [fluxname, '_timeseries'], '-v7');
end
