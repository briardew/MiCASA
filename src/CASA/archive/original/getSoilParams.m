% get litter characteristic parameters and
% turnover times (leaf and rootage, woodage)

% 0  	water
% 1 	evergreen needleleaf forest
% 2 	evergreen broadleaf forest
% 3 	deciduous needleleaf forest
% 4 	deciduous broadleaf forest
% 5 	mixed forests
% 6 	shrublands
% 7 	savanna and grassalnd
% 8 	permanent wetlands
% 9 	croplands
% 10 	urban and built-up
% 11 	barren or sparsely vegetated
% 12 	permanent snow and ice 

io = VEG==1;  litcn(io) = 40; lignin(io) = 0.20; lrage(io) = 2.0; woodage(io) = 40;
io = VEG==2;  litcn(io) = 50; lignin(io) = 0.20; lrage(io) = 2.0; woodage(io) = 40;
io = VEG==3;  litcn(io) = 65; lignin(io) = 0.22; lrage(io) = 1.0; woodage(io) = 40;
io = VEG==4;  litcn(io) = 80; lignin(io) = 0.25; lrage(io) = 0.5; woodage(io) = 40;
io = VEG==5;  litcn(io) = 50; lignin(io) = 0.20; lrage(io) = 0.5; woodage(io) = 40;
io = VEG==6;  litcn(io) = 50; lignin(io) = 0.15; lrage(io) = 0.5; woodage(io) = 40;
io = VEG==7;  litcn(io) = 50; lignin(io) = 0.10; lrage(io) = 0.5; woodage(io) = 40;
io = VEG==8;  litcn(io) = 50; lignin(io) = 0.15; lrage(io) = 0.5; woodage(io) = 40;
io = VEG==9;  litcn(io) = 65; lignin(io) = 0.20; lrage(io) = 0.5; woodage(io) = 40;
io = VEG==10; litcn(io) = 50; lignin(io) = 0.15; lrage(io) = 0.5; woodage(io) = 40;
io = VEG==11; litcn(io) = 50; lignin(io) = 0.15; lrage(io) = 0.5; woodage(io) = 40;
io = VEG==12; litcn(io) = 40; lignin(io) = 0.10; lrage(io) = 0.5; woodage(io) = 40;
io = VEG==0 & maskfile(mask,mask)>0;
litcn(io) = 50; lignin(io) = 0.10; lrage(io) = 0.5; woodage(io) = 40;
disp(['!!! ' int2str(sum(io)) ' grid cells have no parameters in getSoilParams !!!'])


% Some of these numbers have been CHANGED from original CASA, according to an
% extensive study done for BIOME-BGC (see White, M. A., P. E. Thornton, S.
% W. Running, and R. R. Nemani. 2000. Parameterization and Sensitivity 
% Analysis of the BIOME-BGC Terrestrial Ecosystem Model: Net Primary Production Controls. 
% Earth Interactions 4(3):1-85.)

% here are the original values:
% io = VEG==1;  litcn(io) = 40; lignin(io) = 0.20; lrage(io) = 1.80; woodage(io) = 41;
% io = VEG==2;  litcn(io) = 50; lignin(io) = 0.20; lrage(io) = 1.20; woodage(io) = 58;
% io = VEG==3;  litcn(io) = 65; lignin(io) = 0.22; lrage(io) = 1.20; woodage(io) = 58;
% io = VEG==4;  litcn(io) = 80; lignin(io) = 0.25; lrage(io) = 5.00; woodage(io) = 42;
% io = VEG==5;  litcn(io) = 50; lignin(io) = 0.20; lrage(io) = 1.80; woodage(io) = 27;
% io = VEG==6;  litcn(io) = 50; lignin(io) = 0.15; lrage(io) = 1.80; woodage(io) = 25;
% io = VEG==7;  litcn(io) = 50; lignin(io) = 0.10; lrage(io) = 1.50; woodage(io) = 25;
% io = VEG==9;  litcn(io) = 65; lignin(io) = 0.20; lrage(io) = 1.00; woodage(io) = 5.5;
% io = VEG==10; litcn(io) = 50; lignin(io) = 0.15; lrage(io) = 2.80; woodage(io) = 40;
% io = VEG==11; litcn(io) = 50; lignin(io) = 0.15; lrage(io) = 1.00; woodage(io) = 25;
% io = VEG==12; litcn(io) = 40; lignin(io) = 0.10; lrage(io) = 1.00; woodage(io) = 25;

% calculate lignin tot nitrogen ratio
ln = (litcn .* lignin) ./ 0.45;

% calculate the rate constants for each pool
annK_leaf       = single(1./lrage);
annK_wood       = single(1./woodage);
annK_froot      = single(1./lrage);
annK_hleaf      = single(6);
annK_hfroot     = single(6);

annK_surfmet    = single(14.8);
annK_surfstr    = single(3.9);
annK_surfmic    = single(6);

annK_soilmet    = single(18.5);
annK_soilstr    = single(4.8);
annK_soilmic    = single(7.3);

annK_cwd        = single(0.25);
annK_slow       = single(0.2);
annK_armored    = single(0.0045);

% scale the rate constants to their steply values (not just divided bij 12)
K_wood     = 1 - (exp(-annK_wood  ).^(1/NSTEPS));
K_froot    = 1 - (exp(-annK_froot ).^(1/NSTEPS));  
K_leaf     = 1 - (exp(-annK_leaf  ).^(1/NSTEPS));  

K_hleaf    = 1 - (exp(-annK_hleaf ).^(1/NSTEPS));
K_hfroot   = 1 - (exp(-annK_hfroot).^(1/NSTEPS));

K_surfmet  = 1 - (exp(-annK_surfmet)^(1/NSTEPS));
K_surfstr  = 1 - (exp(-annK_surfstr)^(1/NSTEPS));
K_soilmet  = 1 - (exp(-annK_soilmet)^(1/NSTEPS));
K_soilstr  = 1 - (exp(-annK_soilstr)^(1/NSTEPS));
K_cwd      = 1 - (exp(-annK_cwd    )^(1/NSTEPS));    
K_surfmic  = 1 - (exp(-annK_surfmic)^(1/NSTEPS));
K_soilmic  = 1 - (exp(-annK_soilmic)^(1/NSTEPS));
K_slow     = 1 - (exp(-annK_slow   )^(1/NSTEPS));
K_hslow    = 1 - (exp(-annK_slow   )^(1/NSTEPS));
K_armored  = 1 - (exp(-annK_armored)^(1/NSTEPS));
K_harmored = 1 - (exp(-annK_armored)^(1/NSTEPS));

% microbial afficiencies for particular flows
eff_surfstr2slow    = single(0.7);
eff_surfstr2surfmic = single(0.4);
eff_soilstr2slow    = single(0.7);
eff_soilstr2soilmic = single(0.45);
eff_cwd2slow        = single(0.7);
eff_cwd2surfmic     = single(0.4);
eff_surfmic2slow    = single(0.4);
eff_surfmet2surfmic = single(0.4);
eff_soilmet2soilmic = single(0.45);
eff_slow2soilmic    = single(0.45);
eff_armored2soilmic = single(0.45);
eff_soilmic2slow    = single(0.85 - (0.68.*(silt + clay)));

% determine what fraction of the litter will be metabolic
metabfract = 0.85 - (0.018 .* ln);
metabfract(metabfract<0) = 0;

% get the fraction of the carbon in the structural litter pools
% that will be from lignin
structuralLignin = ((lignin .* 0.65) ./ 0.45) ./ (1 - metabfract);

% estimate of the lignin content of wood carbon is 40%
woodligninfract  = single(0.4);
lignineffect     = exp(-3 .* structuralLignin);

% calculate VEGetation-dependent factors used in the belowground module
soilmicDecayFactor = (1 - (0.75 .* (silt + clay)));
slowDecayFactor    = ones(numberOfGridCells,1,'single');  
armoredDecayFactor = ones(numberOfGridCells,1,'single');

% decay is faster in agriculture gridcells (till etc)
io = (VEG==9);
soilmicDecayFactor(io) = soilmicDecayFactor(io) .* 1.25;
slowDecayFactor(io)    = slowDecayFactor(io)    .* 1.5;
armoredDecayFactor(io) = armoredDecayFactor(io) .* 1.5;

decayClayFactor = 0.003 - (0.009 .* clay);
decayClayFactor(decayClayFactor < 0) = 0;

