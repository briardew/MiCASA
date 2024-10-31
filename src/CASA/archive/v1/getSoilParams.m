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
% extensive study done for BIOME-BGC
% [White et al. (2000)](https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2)

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

annK_cwd        = single(0.25);			% 0.1 in Zhou et al. (2020; https://doi.org/10.1029/2019JG005314)
annK_slow       = single(0.2);			% All others identical
annK_armored    = single(0.0045);

% scale the annual rate constants to their monthly values
K_wood     = 1 - exp(-annK_wood  ).^(1/12);
K_froot    = 1 - exp(-annK_froot ).^(1/12);
K_leaf     = 1 - exp(-annK_leaf  ).^(1/12);

K_hleaf    = 1 - exp(-annK_hleaf ).^(1/12);
K_hfroot   = 1 - exp(-annK_hfroot).^(1/12);

K_surfmet  = 1 - exp(-annK_surfmet)^(1/12);
K_surfstr  = 1 - exp(-annK_surfstr)^(1/12);
K_soilmet  = 1 - exp(-annK_soilmet)^(1/12);
K_soilstr  = 1 - exp(-annK_soilstr)^(1/12);
K_cwd      = 1 - exp(-annK_cwd    )^(1/12);
K_surfmic  = 1 - exp(-annK_surfmic)^(1/12);
K_soilmic  = 1 - exp(-annK_soilmic)^(1/12);
K_slow     = 1 - exp(-annK_slow   )^(1/12);
K_hslow    = 1 - exp(-annK_slow   )^(1/12);
K_armored  = 1 - exp(-annK_armored)^(1/12);
K_harmored = 1 - exp(-annK_armored)^(1/12);

% hold a copy for daily runs (see CASA and adjustSoilC)
K_woodmo     = K_wood;
K_frootmo    = K_froot;
K_leafmo     = K_leaf;
K_hleafmo    = K_hleaf;
K_hfrootmo   = K_hfroot;
K_surfmetmo  = K_surfmet;
K_surfstrmo  = K_surfstr;
K_soilmetmo  = K_soilmet;
K_soilstrmo  = K_soilstr;
K_cwdmo      = K_cwd;
K_surfmicmo  = K_surfmic;
K_soilmicmo  = K_soilmic;
K_slowmo     = K_slow;
K_hslowmo    = K_hslow;
K_armoredmo  = K_armored;
K_harmoredmo = K_harmored;

% Microbial afficiencies for particular flows
% [Parton et al. (1993)](https://doi.org/10.1029/93GB02042)
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
eff_soilmic2slow    = single(0.85 - 0.68*(silt + clay));

% Determine what fraction of the litter will be metabolic
metabfract = 0.85 - (0.018 .* ln);
metabfract(metabfract<0) = 0;

% get the fraction of the carbon in the structural litter pools
% that will be from lignin
structuralLignin = ((lignin .* 0.65) ./ 0.45) ./ (1 - metabfract);

% estimate of the lignin content of wood carbon is 40%
woodligninfract  = single(0.4);
lignineffect     = exp(-3 .* structuralLignin);

% calculate VEGetation-dependent factors used in the belowground module
soilmicDecayFactor = single(1.0 - 0.75*(silt + clay));
slowDecayFactor    = ones(numberOfGridCells,1,'single');
armoredDecayFactor = ones(numberOfGridCells,1,'single');

% decay is faster in agriculture gridcells (till etc)
io = (VEG==9);
soilmicDecayFactor(io) = soilmicDecayFactor(io) .* 1.25;
slowDecayFactor(io)    = slowDecayFactor(io)    .* 1.5;
armoredDecayFactor(io) = armoredDecayFactor(io) .* 1.5;

decayClayFactor = single(0.003 - 0.009*clay);
decayClayFactor(decayClayFactor < 0) = 0;
