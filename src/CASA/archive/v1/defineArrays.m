% ALLOCATE MEMORY

% in getSoilParams
arrayNames = {'litcn', 'lignin', 'lrage', 'woodage'};
for array = 1:length(arrayNames)
    eval([arrayNames{array},' = single(zeros(numberOfGridCells,1));'])
end

% in doPET
arrayNames = {'PET','AHI'};
for array = 1:length(arrayNames)
    eval([arrayNames{array},' = single(zeros(numberOfGridCells,1));'])
end

coef = [1.040   -4.00E-3    6.46E-6     -8.04E-7;
        0.944   -2.00E-3    2.71E-6     -4.32E-7;
        1.040   -4.49E-4    4.04E-6     -4.99E-8;
        1.010    2.00E-3    4.86E-6      2.97E-7;
        1.040    4.00E-3    2.89E-6      7.50E-7;
        1.010    4.00E-3    1.76E-6      9.28E-7;
        1.040    4.00E-3    6.46E-6      8.04E-7;
        1.040    3.00E-3    7.87E-6      3.85E-7;
        1.010    3.87E-4    5.32E-6      1.02E-7;
        1.040   -2.00E-3    7.20E-6     -2.95E-7;
        1.010   -4.00E-3    3.88E-6     -6.87E-7;
        1.040   -5.00E-3    3.61E-6     -9.49E-7];  
coef = single(coef);

% in doSoilMoisture
arrayNames = {'last_pack','pack','EET','NPPmoist_temp','bgmoist_temp','bgmoistpret','NPPmoistpret','soilm'};
for array = 1:length(arrayNames)
    eval([arrayNames{array},' = single(zeros(numberOfGridCells,1));'])
end

arrayNames = {'bgmoist','NPPmoist'};
for array = 1:length(arrayNames)
    eval([arrayNames{array},' = single(ones(numberOfGridCells,1).*0.5);'])
end

% in doOptimumTemperature
arrayNames = {'topt','maxFPAR'};
for array = 1:length(arrayNames)
    eval([arrayNames{array},' = single(zeros(numberOfGridCells,1));'])
end

% in getFireParams
CCratio_previous = zeros(numberOfGridCells,1,'single');

% in doTreeCarbon, doHerbCarbon, doDefoCarbon, and deRegrCarbon
woodPoolNames = {'abovewoodpool','belowwoodpool','leafpool','frootpool','cwdpool','surfstrpool','surfmetpool', ...
                 'surfmicpool','soilstrpool','soilmetpool','soilmicpool','slowpool','armoredpool'};
herbPoolNames = {'hleafpool','hfrootpool','hsurfstrpool','hsurfmetpool','hsurfmicpool','hsoilstrpool', ...
                 'hsoilmetpool','hsoilmicpool','hslowpool','harmoredpool'};
defoPoolNames = {'dleafpool','dfrootpool','dcwdpool','dsurfstrpool','dsurfmetpool', ...
                 'dsurfmicpool','dsoilstrpool','dsoilmetpool','dsoilmicpool','dslowpool','darmoredpool'};
regrPoolNames = {'rabovewoodpool','rbelowwoodpool','rleafpool','rfrootpool','rcwdpool','rsurfstrpool','rsurfmetpool', ...
                 'rsurfmicpool','rsoilstrpool','rsoilmetpool','rsoilmicpool','rslowpool','rarmoredpool'};
             
for pool = 1:length(woodPoolNames)
    eval([woodPoolNames{pool},' = single(zeros(numberOfGridCells,1));'])
end
for pool = 1:length(herbPoolNames)
    eval([herbPoolNames{pool},' = single(zeros(numberOfGridCells,1));'])
end
for pool = 1:length(defoPoolNames)
    eval([defoPoolNames{pool},' = single(zeros(numberOfGridCells,1));'])
end
for pool = 1:length(regrPoolNames)
    eval([regrPoolNames{pool},' = single(zeros(numberOfGridCells,1));'])
end

clear arrayNames array pool
