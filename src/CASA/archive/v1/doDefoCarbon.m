% carbon fluxes in deforested land

% pools are based on weighted average from previously deforested [FDC] and this
% step deforested [DF] parts.
dleafpool    = FDC .* dleafpool    + DF.* leafpool;
dfrootpool   = FDC .* dfrootpool   + DF.* frootpool;
dcwdpool     = FDC .* dcwdpool     + DF.* (cwdpool + nonCombusted_abovewood);
dsurfmetpool = FDC .* dsurfmetpool + DF.* (surfmetpool + nonCombusted_leaf .* metabfract);
dsurfstrpool = FDC .* dsurfstrpool + DF.* (surfstrpool + nonCombusted_leaf .* (1 - metabfract));
dsurfmicpool = FDC .* dsurfmicpool + DF.* surfmicpool;
dsoilmetpool = FDC .* dsoilmetpool + DF.* (soilmetpool + (nonCombusted_froot + nonCombusted_belowwood) .* metabfract);
dsoilstrpool = FDC .* dsoilstrpool + DF.* (soilstrpool + (nonCombusted_froot + nonCombusted_belowwood) .* (1 - metabfract));
dsoilmicpool = FDC .* dsoilmicpool + DF.* soilmicpool;
dslowpool    = FDC .* dslowpool    + DF.* slowpool;
darmoredpool = FDC .* darmoredpool + DF.* armoredpool;

total = FDC + DF;
io = 0 < total;

dleafpool(io)    = dleafpool(io)./total(io);
dfrootpool(io)   = dfrootpool(io)./total(io);
dcwdpool(io)     = dcwdpool(io)./total(io);
dsurfmetpool(io) = dsurfmetpool(io)./total(io);
dsurfstrpool(io) = dsurfstrpool(io)./total(io);
dsurfmicpool(io) = dsurfmicpool(io)./total(io);
dsoilmetpool(io) = dsoilmetpool(io)./total(io);
dsoilstrpool(io) = dsoilstrpool(io)./total(io);
dsoilmicpool(io) = dsoilmicpool(io)./total(io);
dslowpool(io)    = dslowpool(io)./total(io);
darmoredpool(io) = darmoredpool(io)./total(io);

% Now treat deforested pools as herbaceous including cwd

% NPP: calculate inputs from NPP to living pools following Hui and Jackson
% (http://www.blackwell-synergy.com/doi/pdf/10.1111/j.1469-8137.2005.01569.x)
io = max(0.20, min(0.80, 0.85 - MAP));
frootinput = NPP .* io;
leafinput  = NPP .* (1-io);

% NPP: transfer NPP into living biomass pools
dleafpool  = dleafpool  + leafinput;
dfrootpool = dfrootpool + frootinput;

% HERBIVORY
herbivory           = grass_herbivory .* herb_seasonality;                  % yearly herbivory * seasonality scalar
io                  = herbivory > dleafpool;                                % check that herbivory does not exceed available leaf
herbivory(io)       = dleafpool(io);                                        % in case herbivory exceeds leaf, lower herbivory
dleafpool           = dleafpool - herbivory;                                % deduct herbivory from the leafpool
carbonout_leaf      = herbivory .* (1 - herbivoreEff);                      % part of the consumed leaf will be returned as litter
herbivory           = herbivory  - herbivory .* (1 - herbivoreEff);         % part of the consumed leaf for maintenance

dsurfstrpool        = dsurfstrpool   + carbonout_leaf .*(1 - metabfract);    
dsurfmetpool        = dsurfmetpool   + carbonout_leaf .* metabfract;    

% DECAY of biomass and litter, each of the following equations have the following basic form: 
% carbon pool size * rate constant * abiotic effect. Some may have more terms but all are first order
carbonout_leaf    = dleafpool    .* K_hleaf    .* litterscalar;
carbonout_froot   = dfrootpool   .* K_hfroot   .* litterscalar;
carbonout_cwd     = dcwdpool     .* K_cwd      .* abiotic;
carbonout_surfmet = dsurfmetpool .* K_surfmet  .* abiotic;
carbonout_surfstr = dsurfstrpool .* K_surfstr  .* abiotic  .* lignineffect;
carbonout_soilmet = dsoilmetpool .* K_soilmet  .* abiotic;
carbonout_soilstr = dsoilstrpool .* K_soilstr  .* abiotic  .* lignineffect;
carbonout_surfmic = dsurfmicpool .* K_surfmic  .* abiotic;
carbonout_soilmic = dsoilmicpool .* K_soilmic  .* abiotic  .* soilmicDecayFactor;
carbonout_slow    = dslowpool    .* K_hslow    .* abiotic;
carbonout_armored = darmoredpool .* K_harmored .* abiotic;

% determine inputs into structural and metabolic pools from decaying living
% pools
dsurfstrpool = dsurfstrpool + (carbonout_leaf + carbonout_cwd)  .* (1 - metabfract);    
dsoilstrpool = dsoilstrpool + carbonout_froot .* (1 - metabfract);
dsurfmetpool = dsurfmetpool + (carbonout_leaf + carbonout_cwd)  .* metabfract;    
dsoilmetpool = dsoilmetpool + carbonout_froot .* metabfract;    

dcwdpool     = dcwdpool     - carbonout_cwd;
dleafpool    = dleafpool    - carbonout_leaf;
dfrootpool   = dfrootpool   - carbonout_froot;
dsurfstrpool = dsurfstrpool - carbonout_surfstr;


% empty respirationpools in beginning of month
resppools = {'resppool_surfstr','resppool_surfmet','resppool_surfmic','resppool_armored', ...
             'resppool_soilstr','resppool_soilmet','resppool_soilmic','resppool_slow'};

for pool = 1:length(resppools)
    eval([ resppools{pool} ' = zeros(numberOfGridCells,1);'])
end

% respiratory fluxes (temp)
%1
temp               = (carbonout_surfstr    .* structuralLignin)            .* eff_surfstr2slow;
dslowpool          = dslowpool            + temp;
resppool_surfstr   = resppool_surfstr      + (temp ./ eff_surfstr2slow)    .* (1 - eff_surfstr2slow);
%2
temp               = (carbonout_surfstr    .* (1 - structuralLignin))      .* eff_surfstr2surfmic;
dsurfmicpool       = dsurfmicpool         + temp;
resppool_surfstr   = resppool_surfstr      + (temp ./ eff_surfstr2surfmic) .* (1 - eff_surfstr2surfmic);
dsoilstrpool       = dsoilstrpool           - carbonout_soilstr;
%3
temp               = carbonout_soilstr     .* structuralLignin             .* eff_soilstr2slow;
dslowpool          = dslowpool             + temp;
resppool_soilstr   = resppool_soilstr       + (temp ./ eff_soilstr2slow)    .* (1 - eff_soilstr2slow);
%4
temp               = carbonout_soilstr     .* (1 - structuralLignin)       .* eff_soilstr2soilmic;
dsoilmicpool       = dsoilmicpool          + temp;
resppool_soilstr   = resppool_soilstr       + (temp ./ eff_soilstr2soilmic) .* (1 - eff_soilstr2soilmic);
%5
temp               = carbonout_surfmet     .* eff_surfmet2surfmic;
dsurfmetpool       = dsurfmetpool          - carbonout_surfmet;
dsurfmicpool       = dsurfmicpool          + temp;
resppool_surfmet   = (temp ./ eff_surfmet2surfmic) .* (1 - eff_surfmet2surfmic);
%6
temp               = carbonout_soilmet     .* eff_soilmet2soilmic;
dsoilmetpool       = dsoilmetpool          - carbonout_soilmet;
dsoilmicpool       = dsoilmicpool           + temp;
resppool_soilmet   = (temp ./ eff_soilmet2soilmic) .* (1 - eff_soilmet2soilmic);
%7
temp               = carbonout_surfmic     .* eff_surfmic2slow;
dsurfmicpool       = dsurfmicpool           - carbonout_surfmic;
dslowpool          = dslowpool              + temp;
resppool_surfmic   = (temp ./ eff_surfmic2slow)    .* (1 - eff_surfmic2slow);
%8
resppool_soilmic   = eff_soilmic2slow      .* carbonout_soilmic;
dsoilmicpool       = dsoilmicpool          - carbonout_soilmic;
%9
temp               = carbonout_soilmic     .* (0.003 + (0.032 .* clay));
darmoredpool       = darmoredpool          + temp;
%10
temp               = carbonout_soilmic     - temp   - resppool_soilmic;
dslowpool          = dslowpool             + temp;
%11
resppool_slow      = carbonout_slow        .* (1 - eff_slow2soilmic);
dslowpool          = dslowpool             - carbonout_slow;
%12
temp               = carbonout_slow        .* eff_slow2soilmic .* decayClayFactor;
darmoredpool       = darmoredpool          + temp;
%13
temp               = carbonout_slow        - resppool_slow     - temp;
dsurfmicpool       = dsurfmicpool          + temp;
%14
temp               = carbonout_armored     .* eff_armored2soilmic;
darmoredpool       = darmoredpool          - carbonout_armored;
dsurfmicpool       = dsurfmicpool          + temp;
%15
resppool_armored    = (temp ./ eff_armored2soilmic) .* (1 - eff_armored2soilmic);

% FIRES consume part of the pools depending on burned fraction (BF),
% combustion completeness (CC), and tree mortality rate 

combusted_leaf          = dleafpool        .* BF  .* ccLeaf;
combusted_surfstr       = dsurfstrpool     .* BF  .* ccFineLitter;
combusted_surfmet       = dsurfmetpool     .* BF  .* ccFineLitter;
combusted_surfmic       = dsurfmicpool     .* BF  .* ccFineLitter;
combusted_cwd           = dcwdpool         .* BF  .* ccCwd;

% Peat burning (Indonesia, based on Page et al., 2002 values for peat bulk density [0.1 g / cm3] and carbon content [57%])
peat_combusted          = 0.563*0.1*1E6     .* BF  .* ccFineLitter .* PF .* ccPEAT;

% FIRE: the non-combusted parts
nonCombusted_leaf       = dleafpool        .* BF  .* (1 - ccLeaf) .* MORT;
nonCombusted_froot      = dfrootpool       .* BF  .* mortality_hfroot;

% FIRE flux from not combusted parts to other pools
dsurfstrpool           = dsurfstrpool + nonCombusted_leaf  .* (1 - metabfract);
dsurfmetpool           = dsurfmetpool + nonCombusted_leaf  .* metabfract;   
dsoilstrpool           = dsoilstrpool + nonCombusted_froot .* (1 - metabfract);
dsoilmetpool           = dsoilmetpool + nonCombusted_froot .* metabfract;   

dleafpool              = dleafpool        - combusted_leaf        - nonCombusted_leaf;
dfrootpool             = dfrootpool                               - nonCombusted_froot;
dsurfstrpool           = dsurfstrpool     - combusted_surfstr;
dsurfmetpool           = dsurfmetpool     - combusted_surfmet;
dsurfmicpool           = dsurfmicpool     - combusted_surfmic;
dcwdpool               = dcwdpool         - combusted_cwd;

% *************************************************************************

dcomb = combusted_leaf + combusted_surfstr + combusted_surfmet + combusted_surfmic + combusted_cwd;
dpeat = peat_combusted;
dresp = resppool_surfstr + resppool_surfmet + resppool_surfmic + resppool_armored + resppool_soilstr + resppool_soilmet + resppool_soilmic + resppool_slow;
dherb = herbivory;
