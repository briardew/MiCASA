%% adjust turnover rates so CASA soil carbon is equal to measured soil
%% carbon

if step == NSTEPS
    K_slow     = ones(sum(mask(:)),1) .* K_slow;
    K_hslow    = ones(sum(mask(:)),1) .* K_hslow;
    K_armored  = ones(sum(mask(:)),1) .* K_armored;
    K_harmored = ones(sum(mask(:)),1) .* K_harmored;
    
    % adjust rate constants and add carbon to pools so that slowpool equals
    % measured C in top 30 cm and armored matches measured C in 30-100 cm.

    % lower top 30 with carbon already in soil 
    ORGC_toph = ORGC_top - hsoilmetpool - hsoilstrpool - hsoilmicpool;
    ORGC_topw = ORGC_top -  soilmetpool -  soilstrpool -  soilmicpool;

    ORGC_toph(ORGC_toph < 0) = 0;
    ORGC_topw(ORGC_topw < 0) = 0;

    ORGC_subh = ORGC_sub - harmoredpool;
    ORGC_subw = ORGC_sub -  armoredpool;

    ORGC_subh(ORGC_subh < 0) = 0;
    ORGC_subw(ORGC_subw < 0) = 0;

    % adjust slowpool and turnover rate
    inds = slowpool < ORGC_topw;
    K_slow(inds)   = K_slow(inds).*slowpool(inds)./ORGC_topw(inds);
    slowpool(inds) = ORGC_topw(inds);

    inds = hslowpool < ORGC_toph;
    K_hslow(inds)   = K_hslow(inds).*hslowpool(inds)./ORGC_toph(inds);
    hslowpool(inds) = ORGC_toph(inds);

    % adjust armoredpool and turnover rate
    inds = armoredpool < ORGC_subw;
    K_armored(inds)   = K_armored(inds).*armoredpool(inds)./ORGC_subw(inds);
    armoredpool(inds) = ORGC_subw(inds);

    inds = harmoredpool < ORGC_subh;
    K_harmored(inds)   = K_harmored(inds).*harmoredpool(inds)./ORGC_subh(inds);
    harmoredpool(inds) = ORGC_subh(inds);

    %     % Soil C in wooded places
%     deficit                 = ORGC_top + ORGC_sub - mean(ORGC_CASA_Tree,2);     % calculate the difference between measured and modeled soil C
%     deficit(deficit < 0)    = 0;                                                % only adjust when measured soil C exceeds modelled soil C
%     ratio                   = deficit ./ armoredpool;                           % no need to take annual mean due to low seasonality in armoredpool content
%     armoredpool             = armoredpool + deficit;                            % fill armoredpool with difference between measurend and modeled soil C
%     temp                    = K_armored ./ ratio;
%     K_armored               = K_armored .* ones(sum(mask(:)),1);
%     K_armored(deficit > 0)  = temp(deficit > 0);                                % adjust armored turnover rate
%     
%     % same for herbaceous vegetation
%     deficit                 = ORGC_top + ORGC_sub - mean(ORGC_CASA_Herb,2);     % calculate the difference between measured and modeled soil C
%     deficit(deficit < 0)    = 0;                                                % only adjust when measured soil C exceeds modelled soil C
%     ratio                   = deficit ./ harmoredpool;                          % no need to take annual mean due to low seasonality in armoredpool content
%     harmoredpool            = harmoredpool + deficit;                          % fill armoredpool with difference between measurend and modeled soil C
%     temp                    = K_harmored ./ ratio;
%     K_harmored              = K_harmored .* ones(sum(mask(:)),1);
%     K_harmored(deficit > 0) = temp(deficit > 0);                                % adjust armored turnover rate
end

% hold a copy for daily runs (see CASA and adjustSoilC)
K_slowmo     = K_slow;
K_hslowmo    = K_hslow;
K_armoredmo  = K_armored;
K_harmoredmo = K_harmored;
