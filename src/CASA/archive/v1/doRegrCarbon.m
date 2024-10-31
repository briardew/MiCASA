% Woody vegetation carbon fluxes in regrowth areas

RA = zeros(size(BA));   
io = 0 < gridArea;
RF(io) = RA(io) ./ gridArea(io);     % convert burned fraction of whole grid cell to fraction forested part
% fid = FTC+FBC+FHC+FDC+FRC;
% maxRF = 1-FBC-FHC-FDC-FRC;
% RF(fid>1) = maxRF(fid>1);


% pools are based on weighted average from previously regrowing area [FHC] and this
% step added areas that were herbaceous before [RF] parts.

warning off
total = FRC + RF;
rleafpool       = (FRC .* rleafpool     + RF.* hleafpool)    ./ total;
rfrootpool      = (FRC .* rfrootpool    + RF.* hfrootpool)   ./ total;
rsurfmetpool    = (FRC .* rsurfmetpool  + RF.* hsurfmetpool) ./ total;
rsurfstrpool    = (FRC .* rsurfstrpool  + RF.* hsurfstrpool) ./ total;
rsurfmicpool    = (FRC .* rsurfmicpool  + RF.* hsurfmicpool) ./ total;
rsoilmetpool    = (FRC .* rsoilmetpool  + RF.* hsoilmetpool) ./ total;
rsoilstrpool    = (FRC .* rsoilstrpool  + RF.* hsoilstrpool) ./ total;
rsoilmicpool    = (FRC .* rsoilmicpool  + RF.* hsoilmicpool) ./ total;
rslowpool       = (FRC .* rslowpool     + RF.* hslowpool)    ./ total;
rarmoredpool    = (FRC .* rarmoredpool  + RF.* harmoredpool) ./ total;

rabovewoodpool  = (FRC .* rabovewoodpool)                    ./ total;
rbelowwoodpool  = (FRC .* rbelowwoodpool)                    ./ total;
rcwdpool        = (FRC .* rcwdpool)                          ./ total;
warning on

% if no regrowth has occurred yet then total is 0 and the pools become
% NaN, convert these to zero
for pool = 1:length(regrPoolNames)
    eval([regrPoolNames{pool},'(total==0) = 0;'])
end

%% NPP: calculate inputs from NPP to living pools
woodinput           = NPP .* (0.25 + 0.2 .* MAP);
frootinput          = NPP .* (0.25 + 0.2 .* (1 - MAP));
leafinput           = NPP .* 0.30;

%% NPP: transfer NPP into living biomass pools
rleafpool          = rleafpool      + leafinput;
rabovewoodpool     = rabovewoodpool + woodinput * aboveWoodFraction;
rbelowwoodpool     = rbelowwoodpool + woodinput * (1 - aboveWoodFraction);
rfrootpool         = rfrootpool     + frootinput;

%% DECAY of biomass and litter, each of the following equations have the following basic form: 
% carbon pool size * rate constant * abiotic effect. Some may have more terms but all are first order
carbonout_leaf      = rleafpool      .* K_leaf    .* litterscalar;
carbonout_abovewood = rabovewoodpool .* K_wood;
carbonout_belowwood = rbelowwoodpool .* K_wood;
carbonout_froot     = rfrootpool     .* K_froot   .* litterscalar;
carbonout_cwd       = rcwdpool       .* K_cwd     .* abiotic;
carbonout_surfmet   = rsurfmetpool   .* K_surfmet .* abiotic;
carbonout_surfstr   = rsurfstrpool   .* K_surfstr .* abiotic  .* lignineffect;
carbonout_soilmet   = rsoilmetpool   .* K_soilmet .* abiotic;
carbonout_soilstr   = rsoilstrpool   .* K_soilstr .* abiotic  .* lignineffect;
carbonout_surfmic   = rsurfmicpool   .* K_surfmic .* abiotic;
carbonout_soilmic   = rsoilmicpool   .* K_soilmic .* abiotic  .* soilmicDecayFactor;
carbonout_slow      = rslowpool      .* K_slow    .* abiotic;
carbonout_armored   = rarmoredpool   .* K_armored .* abiotic;

% determine inputs into structural and metabolic pools from decaying living
% pools
rsurfstrpool       = rsurfstrpool   + (carbonout_leaf  + carbonout_cwd)       .*(1 - metabfract);    
rsoilstrpool       = rsoilstrpool   + (carbonout_froot + carbonout_belowwood) .*(1 - metabfract);
rsurfmetpool       = rsurfmetpool   + (carbonout_leaf  + carbonout_cwd)       .* metabfract;    
rsoilmetpool       = rsoilmetpool   + (carbonout_froot + carbonout_belowwood) .* metabfract;    
rcwdpool           = rcwdpool       + carbonout_abovewood;

rleafpool          = rleafpool      - carbonout_leaf;
rabovewoodpool     = rabovewoodpool - carbonout_abovewood;
rbelowwoodpool     = rbelowwoodpool - carbonout_belowwood;
rfrootpool         = rfrootpool     - carbonout_froot;
rcwdpool           = rcwdpool       - carbonout_cwd;
rsurfstrpool       = rsurfstrpool   - carbonout_surfstr;

% empty respirationpools in beginning of month
resppools = {'resppool_surfstr','resppool_surfmet','resppool_surfmic','resppool_armored', ...
             'resppool_soilstr','resppool_soilmet','resppool_soilmic','resppool_slow'};

for pool = 1:length(resppools)
    eval([ resppools{pool} ' = zeros(numberOfGridCells,1);'])
end

%% respiratory fluxes (temp)
%1
temp               = (carbonout_surfstr    .* structuralLignin)            .* eff_surfstr2slow;
rslowpool          = rslowpool              + temp;
resppool_surfstr   = resppool_surfstr      + (temp ./ eff_surfstr2slow)    .* (1 - eff_surfstr2slow);
%2
temp               = (carbonout_surfstr    .* (1 - structuralLignin))      .* eff_surfstr2surfmic;
rsurfmicpool       = rsurfmicpool          + temp;
resppool_surfstr   = resppool_surfstr      + (temp ./ eff_surfstr2surfmic) .* (1 - eff_surfstr2surfmic);
rsoilstrpool       = rsoilstrpool           - carbonout_soilstr;
%3
temp               = carbonout_soilstr     .* structuralLignin             .* eff_soilstr2slow;
rslowpool          = rslowpool               + temp;
resppool_soilstr   = resppool_soilstr       + (temp ./ eff_soilstr2slow)    .* (1 - eff_soilstr2slow);
%4
temp               = carbonout_soilstr     .* (1 - structuralLignin)       .* eff_soilstr2soilmic;
rsoilmicpool       = rsoilmicpool            + temp;
resppool_soilstr   = resppool_soilstr       + (temp ./ eff_soilstr2soilmic) .* (1 - eff_soilstr2soilmic);
%5
temp               = carbonout_surfmet      .* eff_surfmet2surfmic;
rsurfmetpool       = rsurfmetpool            - carbonout_surfmet;
rsurfmicpool       = rsurfmicpool           + temp;
resppool_surfmet   = (temp ./ eff_surfmet2surfmic) .* (1 - eff_surfmet2surfmic);
%6
temp               = carbonout_soilmet      .* eff_soilmet2soilmic;
rsoilmetpool       = rsoilmetpool            - carbonout_soilmet;
rsoilmicpool       = rsoilmicpool            + temp;
resppool_soilmet   = (temp ./ eff_soilmet2soilmic) .* (1 - eff_soilmet2soilmic);
%7
temp               = carbonout_surfmic      .* eff_surfmic2slow;
rsurfmicpool       = rsurfmicpool           - carbonout_surfmic;
rslowpool          = rslowpool               + temp;
resppool_surfmic   = (temp ./ eff_surfmic2slow)    .* (1 - eff_surfmic2slow);
%8
resppool_soilmic   = eff_soilmic2slow       .* carbonout_soilmic;
rsoilmicpool       = rsoilmicpool            - carbonout_soilmic;
%9
temp               = carbonout_soilmic      .* (0.003 + (0.032 .* clay));
rarmoredpool       = rarmoredpool            + temp;
%10
temp               = carbonout_soilmic      - temp   - resppool_soilmic;
rslowpool          = rslowpool              + temp;
%11
resppool_slow      = carbonout_slow        .* (1 - eff_slow2soilmic);
rslowpool          = rslowpool               - carbonout_slow;
%12
temp               = carbonout_slow        .* eff_slow2soilmic .* decayClayFactor;
rarmoredpool       = rarmoredpool          + temp;
%13
temp               = carbonout_slow        - resppool_slow     - temp;
rsoilmicpool       = rsoilmicpool          + temp;
%14
temp               = carbonout_armored     .* eff_armored2soilmic;
rarmoredpool       = rarmoredpool          - carbonout_armored;
rsoilmicpool       = rsoilmicpool          + temp;
%15
resppool_armored   = (temp ./ eff_armored2soilmic) .* (1 - eff_armored2soilmic);

% no FIRES in regrowth areas
rresp = resppool_surfstr + resppool_surfmet + resppool_surfmic + resppool_armored + resppool_soilstr + resppool_soilmet + resppool_soilmic + resppool_slow;  


