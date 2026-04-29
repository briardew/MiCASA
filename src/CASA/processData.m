if spinUpYear2 <= year
    % I know it looks weird, but internally NPP is stored as per m2 of
    % vegetated area. We want to output NPP as per m2 of total surface
    % area, thus the multiplication by FTC + FHC + FDC
    NPP = (FTC + FHC + FDC).*NPP;
    RES = FTC.*wresp + FHC.*hresp + FDC.*dresp;
    HER = FTC.*wherb + FHC.*hherb + FDC.*dherb;
    FUE = FTC.*wfuel;

    COMwood = FTC.*wcomb;
    COMherb = FHC.*hcomb + 0.5.*FDC.*dcomb;
    COMdefo = FTC.*wdefo + 0.5.*FDC.*dcomb;
    COMpeat = FTC.*wpeat + FHC.*hpeat + FDC.*dpeat;

    AGBD = FTC.*abovewoodpool; % g/m2
end

% bweir, fixme: put somewhere else
% now adjust the fractions forested and deforested
FTC = FTC - (BAdefo ./ gridArea);  FTC(FTC<0) = 0;   % Fraction tree cover decreases with the deforested fraction
FDC = FDC + (BAdefo ./ gridArea);  FDC(FDC>1) = 1;   % Fraction deforested cover increases with the deforested fraction
