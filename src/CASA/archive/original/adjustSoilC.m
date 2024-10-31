%% adjust turnover rates so CASA soil carbon is equal to measured soil
%% carbon

warning off
if step == NSTEPS
    K_slow = ones(sum(mask(:)),1) .* K_slow;
    K_hslow = ones(sum(mask(:)),1) .* K_hslow;
    K_armored = ones(sum(mask(:)),1) .* K_armored;
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
    slowpoolnew = slowpool;
    dump = K_slow .* (slowpoolnew./ORGC_topw);
    K_slow(     ORGC_topw>slowpoolnew) = dump(ORGC_topw>slowpoolnew);
    slowpoolnew(ORGC_topw>slowpoolnew) = ORGC_topw(ORGC_topw>slowpoolnew);
    slowpool = slowpoolnew;

    hslowpoolnew = hslowpool;
    dump = K_hslow .* (hslowpoolnew./ORGC_toph);
    K_hslow(     ORGC_toph>hslowpoolnew) = dump(ORGC_toph>hslowpoolnew);
    hslowpoolnew(ORGC_toph>hslowpoolnew) = ORGC_toph(ORGC_toph>hslowpoolnew);
    hslowpool = hslowpoolnew;

    
    % adjust armoredpool and turnover rate    
    armoredpoolnew = armoredpool;
    dump = K_armored .* (armoredpoolnew./ORGC_subw);
    K_armored(     ORGC_subw>armoredpoolnew) = dump(ORGC_subw>armoredpoolnew);
    armoredpoolnew(ORGC_subw>armoredpoolnew) = ORGC_subw(ORGC_subw>armoredpoolnew);
    armoredpool = armoredpoolnew;

    harmoredpoolnew = harmoredpool;
    dump = K_harmored .* (harmoredpoolnew./ORGC_subh);
    K_harmored(     ORGC_subh>harmoredpoolnew) = dump(ORGC_subh>harmoredpoolnew);
    harmoredpoolnew(ORGC_subh>harmoredpoolnew) = ORGC_subh(ORGC_subh>harmoredpoolnew);
    harmoredpool = harmoredpoolnew;
    
    
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
warning on




