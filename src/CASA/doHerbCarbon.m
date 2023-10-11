% herbaceous vegetation carbon fluxes

% NPP: calculate inputs from NPP to living pools following Hui and Jackson
% https://doi.org/10.1111/j.1469-8137.2005.01569.x
io = 0.85 - MAP;
io(io < 0.20) = 0.20; io(io > 0.80) = 0.80;

%ai
if (use_crop_ppt_ratio == 'y')
    io(crop_states_index) = 0.15;
end

frootinput = NPP .* io;
leafinput  = NPP .* (1-io);

% NPP: transfer NPP into living biomass pools
hfrootpool = hfrootpool + frootinput;
hleafpool  = hleafpool  + leafinput;

%ai 
% take out the sink from hleafpool as was done in Zhen's code
if lower(use_sink(1)) == 'y' && month == 9
    if NSTEPS == 12
        hleafpool = hleafpool - SINK;
    else
        hleafpool = hleafpool - SINK/30;
    end
end

% HERBIVORY
herbivory      = grass_herbivory .* herb_seasonality;			% yearly herbivory * seasonality scalar
io             = herbivory > hleafpool;					% check that herbivory does not exceed available leaf
herbivory(io)  = hleafpool(io);						% in case herbivory exceeds leaf, lower herbivory
hleafpool      = hleafpool - herbivory;					% deduct herbivory from the leafpool
carbonout_leaf = herbivory .* (1 - herbivoreEff);			% part of the consumed leaf will be returned as litter
herbivory      = herbivory - herbivory .* (1 - herbivoreEff);		% part of the consumed leaf for maintenance

hsurfstrpool   = hsurfstrpool   + carbonout_leaf .*(1 - metabfract);    
hsurfmetpool   = hsurfmetpool   + carbonout_leaf .* metabfract;    

% DECAY of biomass and litter, each of the following equations have the following basic form: 
% carbon pool size * rate constant * abiotic effect. Some may have more terms but all are first order
carbonout_leaf    = hleafpool    .* K_hleaf    .* litterscalar;
carbonout_froot   = hfrootpool   .* K_hfroot   .* litterscalar;
carbonout_surfmet = hsurfmetpool .* K_surfmet  .* abiotic;
carbonout_surfstr = hsurfstrpool .* K_surfstr  .* abiotic  .* lignineffect;
carbonout_soilmet = hsoilmetpool .* K_soilmet  .* abiotic;
carbonout_soilstr = hsoilstrpool .* K_soilstr  .* abiotic  .* lignineffect;
carbonout_surfmic = hsurfmicpool .* K_surfmic  .* abiotic;
carbonout_soilmic = hsoilmicpool .* K_soilmic  .* abiotic  .* soilmicDecayFactor;
carbonout_slow    = hslowpool    .* K_hslow    .* abiotic;
carbonout_armored = harmoredpool .* K_harmored .* abiotic;

% determine inputs into structural and metabolic pools from decaying living
% pools
hsurfstrpool = hsurfstrpool + carbonout_leaf  .* (1 - metabfract);    
hsoilstrpool = hsoilstrpool + carbonout_froot .* (1 - metabfract);
hsurfmetpool = hsurfmetpool + carbonout_leaf  .* metabfract;    
hsoilmetpool = hsoilmetpool + carbonout_froot .* metabfract;    

hleafpool    = hleafpool    - carbonout_leaf;
hfrootpool   = hfrootpool   - carbonout_froot;
hsurfstrpool = hsurfstrpool - carbonout_surfstr;

% empty respirationpools in beginning of month
resppools = {'resppool_surfstr','resppool_surfmet','resppool_surfmic','resppool_armored', ...
             'resppool_soilstr','resppool_soilmet','resppool_soilmic','resppool_slow'};

for pool = 1:length(resppools)
    eval([ resppools{pool} ' = zeros(numberOfGridCells,1);'])
end

% respiratory fluxes (temp)
%1
temp               = (carbonout_surfstr    .* structuralLignin)            .* eff_surfstr2slow;
hslowpool          = hslowpool             + temp;
resppool_surfstr   = resppool_surfstr      + (temp ./ eff_surfstr2slow)    .* (1 - eff_surfstr2slow);
%2
temp               = (carbonout_surfstr    .* (1 - structuralLignin))      .* eff_surfstr2surfmic;
hsurfmicpool       = hsurfmicpool          + temp;
resppool_surfstr   = resppool_surfstr      + (temp ./ eff_surfstr2surfmic) .* (1 - eff_surfstr2surfmic);
hsoilstrpool       = hsoilstrpool           - carbonout_soilstr;
%3
temp               = carbonout_soilstr     .* structuralLignin             .* eff_soilstr2slow;
hslowpool          = hslowpool             + temp;
resppool_soilstr   = resppool_soilstr      + (temp ./ eff_soilstr2slow)    .* (1 - eff_soilstr2slow);
%4
temp               = carbonout_soilstr     .* (1 - structuralLignin)       .* eff_soilstr2soilmic;
hsoilmicpool       = hsoilmicpool          + temp;
resppool_soilstr   = resppool_soilstr      + (temp ./ eff_soilstr2soilmic) .* (1 - eff_soilstr2soilmic);
%5
temp               = carbonout_surfmet     .* eff_surfmet2surfmic;
hsurfmetpool       = hsurfmetpool          - carbonout_surfmet;
hsurfmicpool       = hsurfmicpool          + temp;
resppool_surfmet   = (temp ./ eff_surfmet2surfmic) .* (1 - eff_surfmet2surfmic);
%6
temp               = carbonout_soilmet     .* eff_soilmet2soilmic;
hsoilmetpool       = hsoilmetpool          - carbonout_soilmet;
hsoilmicpool       = hsoilmicpool           + temp;
resppool_soilmet   = (temp ./ eff_soilmet2soilmic) .* (1 - eff_soilmet2soilmic);
%7
temp               = carbonout_surfmic     .* eff_surfmic2slow;
hsurfmicpool       = hsurfmicpool           - carbonout_surfmic;
hslowpool          = hslowpool              + temp;
resppool_surfmic   = (temp ./ eff_surfmic2slow)    .* (1 - eff_surfmic2slow);
%8
resppool_soilmic   = eff_soilmic2slow      .* carbonout_soilmic;
hsoilmicpool       = hsoilmicpool          - carbonout_soilmic;
%9
temp               = carbonout_soilmic     .* (0.003 + (0.032 .* clay));
harmoredpool       = harmoredpool          + temp;
%10
temp               = carbonout_soilmic     - temp   - resppool_soilmic;
hslowpool          = hslowpool             + temp;
%11
resppool_slow      = carbonout_slow        .* (1 - eff_slow2soilmic);
hslowpool          = hslowpool             - carbonout_slow;
%12
temp               = carbonout_slow        .* eff_slow2soilmic .* decayClayFactor;
harmoredpool       = harmoredpool          + temp;
%13
temp               = carbonout_slow        - resppool_slow     - temp;
hsurfmicpool       = hsurfmicpool          + temp;
%14
temp               = carbonout_armored     .* eff_armored2soilmic;
harmoredpool       = harmoredpool          - carbonout_armored;
hsurfmicpool       = hsurfmicpool          + temp;
%15
resppool_armored    = (temp ./ eff_armored2soilmic) .* (1 - eff_armored2soilmic);

% FIRES consume part of the pools depending on burned fraction (BF),
% combustion completeness (CC), and tree mortality rate 
warning off
BF = BAherb ./ (gridArea.*(FHC+FDC));    % convert burned area to fraction vegetation burned (same for herbaceous and deforested)
BF(BF>1)=1; BF(isnan(BF)) = 0;

combusted_leaf          = hleafpool        .* BF  .* ccLeaf;
combusted_surfstr       = hsurfstrpool     .* BF  .* ccFineLitter;
combusted_surfmet       = hsurfmetpool     .* BF  .* ccFineLitter;
combusted_surfmic       = hsurfmicpool     .* BF  .* ccFineLitter;
% Duff and organic soil carbon burning, only in boreal regions:
combusted_soilstr       = hsoilstrpool     .* BF  .* taigatundra; 
combusted_soilmet       = hsoilmetpool     .* BF  .* taigatundra;
combusted_soilmic       = hsoilmicpool     .* BF  .* taigatundra;
combusted_slow          = hslowpool        .* BF  .* taigatundra .* ccSOIL;

% Peat burning (Indonesia, based on Page et al., 2002 values for peat bulk density [0.1 g / cm3] and carbon content [57%])
peat_combusted          = 0.563*0.1*1E6     .* BF  .* PF .* ccPEAT;

% FIRE: the non-combusted parts
nonCombusted_leaf       = hleafpool        .* BF  .* (1 - ccLeaf) .* MORT;
nonCombusted_froot      = hfrootpool       .* BF  .* mortality_hfroot;

% FIRE flux from not combusted parts to other pools
hsurfstrpool           = hsurfstrpool + nonCombusted_leaf  .* (1 - metabfract);
hsurfmetpool           = hsurfmetpool + nonCombusted_leaf  .* metabfract;   
hsoilstrpool           = hsoilstrpool + nonCombusted_froot .* (1 - metabfract);
hsoilmetpool           = hsoilmetpool + nonCombusted_froot .* metabfract;   

% FIRE 
hleafpool              = hleafpool        - combusted_leaf        - nonCombusted_leaf;
hfrootpool             = hfrootpool                               - nonCombusted_froot;
hsurfstrpool           = hsurfstrpool     - combusted_surfstr;
hsurfmetpool           = hsurfmetpool     - combusted_surfmet;
hsurfmicpool           = hsurfmicpool     - combusted_surfmic;
hsoilstrpool           = hsoilstrpool     - combusted_soilstr;
hsoilmetpool           = hsoilmetpool     - combusted_soilmet;
hsoilmicpool           = hsoilmicpool     - combusted_soilmic;
hslowpool              = hslowpool        - combusted_slow;


% *************************************************************************

hcomb = combusted_leaf + combusted_surfstr + combusted_surfmet + combusted_surfmic + combusted_soilstr + combusted_soilmic + combusted_soilmet + combusted_slow;
hpeat = peat_combusted;
hresp = resppool_surfstr + resppool_surfmet + resppool_surfmic + resppool_armored + resppool_soilstr + resppool_soilmet + resppool_soilmic + resppool_slow;
hherb = herbivory;
