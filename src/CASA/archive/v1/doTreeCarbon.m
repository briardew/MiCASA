% Woody vegetation carbon fluxes

% first boost fire-induced tree mortality in areas outside the tropics
dump = MORT;
dump(MAT < 15) = 0.6;
MORT = dump;

%% NPP: calculate inputs from NPP to living pools
woodinput  = NPP .* (0.25 + 0.2 .* MAP);
frootinput = NPP .* (0.25 + 0.2 .* (1 - MAP));
leafinput  = NPP .* 0.30;

%% NPP: transfer NPP into living biomass pools
leafpool          = leafpool      + leafinput;
abovewoodpool     = abovewoodpool + woodinput * aboveWoodFraction;
belowwoodpool     = belowwoodpool + woodinput * (1 - aboveWoodFraction);
frootpool         = frootpool     + frootinput;

%% HERBIVORY
herbivory           = trees_herbivory .* herb_seasonality;                  % annual herbivory * seasonality scalar
io                  = herbivory > leafpool;                                 % check that herbivory does not exceed available leaf
herbivory(io)       = leafpool(io);                                         % in case herbivory exceeds leaf, lower herbivory
leafpool            = leafpool - herbivory;                                 % deduct herbivory from the leafpool
carbonout_leaf      = herbivory .* (1 - herbivoreEff);                      % part of the consumed leaf will be returned as litter
herbivory           = herbivory  - herbivory .* (1 - herbivoreEff);         % part of the consumed leaf for maintenance

surfstrpool         = surfstrpool   + carbonout_leaf .*(1 - metabfract);    
surfmetpool         = surfmetpool   + carbonout_leaf .* metabfract;    

%% DECAY of biomass and litter, each of the following equations have the following basic form: 
% carbon pool size * rate constant * abiotic effect. Some may have more terms but all are first order
carbonout_leaf      = leafpool      .* K_leaf    .* litterscalar;
carbonout_abovewood = abovewoodpool .* K_wood;
carbonout_belowwood = belowwoodpool .* K_wood;
carbonout_froot     = frootpool     .* K_froot   .* litterscalar;
carbonout_cwd       = cwdpool       .* K_cwd        .* abiotic;
carbonout_surfmet   = surfmetpool   .* K_surfmet    .* abiotic;
carbonout_surfstr   = surfstrpool   .* K_surfstr    .* abiotic  .* lignineffect;
carbonout_soilmet   = soilmetpool   .* K_soilmet    .* abiotic;
carbonout_soilstr   = soilstrpool   .* K_soilstr    .* abiotic  .* lignineffect;
carbonout_surfmic   = surfmicpool   .* K_surfmic    .* abiotic;
carbonout_soilmic   = soilmicpool   .* K_soilmic    .* abiotic  .* soilmicDecayFactor;
carbonout_slow      = slowpool      .* K_slow       .* abiotic;
carbonout_armored   = armoredpool   .* K_armored    .* abiotic;

% determine inputs into structural and metabolic pools from decaying living
% pools
surfstrpool       = surfstrpool   + (carbonout_leaf  + carbonout_cwd)       .*(1 - metabfract);    
soilstrpool       = soilstrpool   + (carbonout_froot + carbonout_belowwood) .*(1 - metabfract);
surfmetpool       = surfmetpool   + (carbonout_leaf  + carbonout_cwd)       .* metabfract;    
soilmetpool       = soilmetpool   + (carbonout_froot + carbonout_belowwood) .* metabfract;    
cwdpool           = cwdpool       + carbonout_abovewood;

leafpool          = leafpool      - carbonout_leaf;
abovewoodpool     = abovewoodpool - carbonout_abovewood;
belowwoodpool     = belowwoodpool - carbonout_belowwood;
frootpool         = frootpool     - carbonout_froot;
cwdpool           = cwdpool       - carbonout_cwd;
surfstrpool       = surfstrpool   - carbonout_surfstr;

% empty respiration pools in beginning of month
resppools = {'resppool_surfstr','resppool_surfmet','resppool_surfmic','resppool_armored', ...
             'resppool_soilstr','resppool_soilmet','resppool_soilmic','resppool_slow'};

for pool = 1:length(resppools)
    eval([ resppools{pool} ' = zeros(numberOfGridCells,1);'])
end

%% respiratory fluxes (temp)
%1
temp              = (carbonout_surfstr    .* structuralLignin)            .* eff_surfstr2slow;
slowpool          = slowpool              + temp;
resppool_surfstr  = resppool_surfstr      + (temp ./ eff_surfstr2slow)    .* (1 - eff_surfstr2slow);
%2
temp              = (carbonout_surfstr    .* (1 - structuralLignin))      .* eff_surfstr2surfmic;
surfmicpool       = surfmicpool           + temp;
resppool_surfstr  = resppool_surfstr      + (temp ./ eff_surfstr2surfmic) .* (1 - eff_surfstr2surfmic);
soilstrpool       = soilstrpool           - carbonout_soilstr;
%3
temp              = carbonout_soilstr     .* structuralLignin              .* eff_soilstr2slow;
slowpool          = slowpool               + temp;
resppool_soilstr  = resppool_soilstr       + (temp ./ eff_soilstr2slow)    .* (1 - eff_soilstr2slow);
%4
temp              = carbonout_soilstr     .* (1 - structuralLignin)        .* eff_soilstr2soilmic;
soilmicpool       = soilmicpool            + temp;
resppool_soilstr  = resppool_soilstr       + (temp ./ eff_soilstr2soilmic) .* (1 - eff_soilstr2soilmic);
%5
temp              = carbonout_surfmet      .* eff_surfmet2surfmic;
surfmetpool       = surfmetpool            - carbonout_surfmet;
surfmicpool       = surfmicpool            + temp;
resppool_surfmet  = (temp ./ eff_surfmet2surfmic) .* (1 - eff_surfmet2surfmic);
%6
temp              = carbonout_soilmet      .* eff_soilmet2soilmic;
soilmetpool       = soilmetpool            - carbonout_soilmet;
soilmicpool       = soilmicpool            + temp;
resppool_soilmet  = (temp ./ eff_soilmet2soilmic) .* (1 - eff_soilmet2soilmic);
%7
temp              = carbonout_surfmic      .* eff_surfmic2slow;
surfmicpool       = surfmicpool            - carbonout_surfmic;
slowpool          = slowpool               + temp;
resppool_surfmic  = (temp ./ eff_surfmic2slow)    .* (1 - eff_surfmic2slow);
%8
resppool_soilmic  = eff_soilmic2slow       .* carbonout_soilmic;
soilmicpool       = soilmicpool            - carbonout_soilmic;
%9
temp              = carbonout_soilmic      .* (0.003 + (0.032 .* clay));
armoredpool       = armoredpool            + temp;
%10
temp              = carbonout_soilmic      - temp   - resppool_soilmic;
slowpool          = slowpool              + temp;
%11
resppool_slow     = carbonout_slow        .* (1 - eff_slow2soilmic);
slowpool          = slowpool               - carbonout_slow;
%12
temp              = carbonout_slow        .* eff_slow2soilmic .* decayClayFactor;
armoredpool       = armoredpool          + temp;
%13
temp              = carbonout_slow        - resppool_slow     - temp;
soilmicpool       = soilmicpool          + temp;
%14
temp              = carbonout_armored     .* eff_armored2soilmic;
armoredpool       = armoredpool          - carbonout_armored;
soilmicpool       = soilmicpool          + temp;
%15
resppool_armored  = (temp ./ eff_armored2soilmic) .* (1 - eff_armored2soilmic);

%% FOREST FIRES
% FIRES consume part of the pools depending on burned fraction (BF),
% combustion completeness (CC), and tree mortality rate 
% Convert burned area to fraction of wooded land
% bweir: what if BAwood > 0 and FTC = 0? FIXME
BF = zeros(size(BAwood));
io = 0 < FTC;
BF(io) = BAwood(io) ./ (gridArea(io) .* FTC(io));
BF = min(1, max(0, BF));

combusted_leaf          = leafpool        .* BF  .* ccLeaf      .* MORT;
combusted_abovewood     = abovewoodpool   .* BF  .* ccWood      .* MORT;
combusted_belowwood     = belowwoodpool   .* BF  .* ccWood      .* MORT .* (taigatundra==1);
combusted_cwd           = cwdpool         .* BF  .* ccCwd;
combusted_surfstr       = surfstrpool     .* BF  .* ccFineLitter;
combusted_surfmet       = surfmetpool     .* BF  .* ccFineLitter;
combusted_surfmic       = surfmicpool     .* BF  .* ccFineLitter;

% Duff and organic soil carbon burning:
combusted_soilstr       = soilstrpool     .* BF  .* taigatundra;
combusted_soilmet       = soilmetpool     .* BF  .* taigatundra;
combusted_soilmic       = soilmicpool     .* BF  .* taigatundra;
combusted_slow          = slowpool        .* BF  .* taigatundra .* ccSOIL;

% Peat burning (Indonesia, based on Page et al. (2002) values for peat bulk density [0.1 g / cm3] and carbon content [57%])
peat_combusted          = 0.563*0.1*1E6   .* BF  .* PF .* ccPEAT;

% FIRE: the non-combusted parts
nonCombusted_leaf       = leafpool        .* BF  .* (1 - ccLeaf) .* MORT;
nonCombusted_abovewood  = abovewoodpool   .* BF  .* (1 - ccWood) .* MORT;
nonCombusted_belowwood  = belowwoodpool   .* BF  .* MORT;
nonCombusted_froot      = frootpool       .* BF  .* MORT;

% FIRE flux from not combusted parts to other pools
surfstrpool           = surfstrpool +  nonCombusted_leaf .* (1 - metabfract);
surfmetpool           = surfmetpool +  nonCombusted_leaf .* metabfract;   
soilstrpool           = soilstrpool + (nonCombusted_froot + nonCombusted_belowwood) .* (1 - metabfract);
soilmetpool           = soilmetpool + (nonCombusted_froot + nonCombusted_belowwood) .* metabfract;   
cwdpool               = cwdpool     +  nonCombusted_abovewood;

% FIRE 
leafpool              = leafpool        - combusted_leaf        - nonCombusted_leaf;
abovewoodpool         = abovewoodpool   - combusted_abovewood   - nonCombusted_abovewood;
belowwoodpool         = belowwoodpool   - combusted_belowwood   - nonCombusted_belowwood;
frootpool             = frootpool                               - nonCombusted_froot;
cwdpool               = cwdpool         - combusted_cwd;
surfstrpool           = surfstrpool     - combusted_surfstr;
surfmetpool           = surfmetpool     - combusted_surfmet;
surfmicpool           = surfmicpool     - combusted_surfmic;
soilstrpool           = soilstrpool     - combusted_soilstr;
soilmetpool           = soilmetpool     - combusted_soilmet;
soilmicpool           = soilmicpool     - combusted_soilmic;
slowpool              = slowpool        - combusted_slow;


%% DEFORESTATION FIRES
% Convert burned fraction of whole grid cell to fraction forested part
% bweir: what if BAdefo > 0 and FTC = 0? FIXME
DF = zeros(size(BAdefo));
io = 0 < FTC;
DF(io) = BAdefo(io) ./ (gridArea(io) .* FTC(io));
DF = min(1, max(0, DF));

combusted_leaf_defo         = leafpool        .* DF  .* ccLeaf         .* mortality_deforestation;
combusted_abovewood_defo    = abovewoodpool   .* DF  .* ccWoodDefo     .* mortality_deforestation;
combusted_belowwood_defo    = belowwoodpool   .* DF  .* ccWoodDefo     .* mortality_deforestation .* (mortality_deforestation>0.9); % only in high persistence regions
combusted_cwd_defo          = cwdpool         .* DF  .* ccCwdDefo;
combusted_surfstr_defo      = surfstrpool     .* DF  .* ccFineLitter;
combusted_surfmet_defo      = surfmetpool     .* DF  .* ccFineLitter;
combusted_surfmic_defo      = surfmicpool     .* DF  .* ccFineLitter;

% FIRE: the non-combusted parts which are added to the FDC
nonCombusted_leaf_defo      = leafpool        .* DF  .* (1 - ccLeaf);
nonCombusted_abovewood_defo = abovewoodpool   .* DF  .* (1 - ccWood);
nonCombusted_belowwood_defo = belowwoodpool   .* DF  .* (1 - ccWood);
nonCombusted_froot_defo     = frootpool       .* DF;

% Peat burning (Indonesia, based on Page et al. (2002) values for peat bulk density [0.1 g / cm3] and carbon content [57%])
peat_combusted = peat_combusted + 0.563*0.1*1E6    .* DF  .* PF .* ccPEAT;

% other pools are transferred as a whole so don't need to be calculated


%% FUELWOOD collection
if year == spinUpYear1 && step == 1
    fuelshortage = zeros(size(fuelwooddemand),'single');
end
fuelwoodout         = fuelwooddemand + fuelshortage;                        % fuel wood demand 
io                  = fuelwoodout > cwdpool;                                % in case demand exceeds availability
fuelwoodout(io)     = cwdpool(io);                                          % demand becomes availability
fuelshortage(io)    = fuelshortage(io) - fuelwoodout(io) + cwdpool(io);     % and shortage increases
io                  = fuelwoodout < cwdpool;                                % in case availability exceeds demand
fuelshortage(io)    = fuelshortage(io) - cwdpool(io) + fuelwoodout(io);     % shortage decreases
io                  = fuelshortage < 0;
fuelshortage(io)    = 0;
cwdpool             = cwdpool - fuelwoodout;                                % fuel wood is taken out of the cwd pool

 
wcomb = combusted_leaf + combusted_abovewood + combusted_belowwood + combusted_cwd + combusted_surfstr + combusted_surfmet + ...
        combusted_surfmic + combusted_soilstr + combusted_soilmet + combusted_soilmic + combusted_slow;
wcobg = combusted_belowwood + combusted_soilstr + combusted_soilmet + combusted_soilmic + combusted_slow;% + combusted_armored;
wpeat = peat_combusted;
wdefo = combusted_leaf_defo + combusted_abovewood_defo + combusted_belowwood_defo + combusted_cwd_defo + combusted_surfstr_defo + ...
        combusted_surfmet_defo + combusted_surfmic_defo;
wresp = resppool_surfstr + resppool_surfmet + resppool_surfmic + resppool_armored + resppool_soilstr + resppool_soilmet + resppool_soilmic + resppool_slow;
wherb = herbivory;  
wfuel = fuelwoodout;
