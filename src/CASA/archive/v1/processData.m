if spinUpYear2 <= year
    % So not neccessarily the actual values? (bweir, fixme)
    NPP = (FTC + FHC + FDC) .* NPP;
    RES = FTC .* wresp + FHC .* hresp + FDC .* dresp;
    HER = FTC .* wherb + FHC .* hherb + FDC .* dherb;
    FUE = FTC .* wfuel;

    COMwood = FTC .* wcomb;
    COMherb = FHC .* hcomb + 0.5 .* FDC .* dcomb;
    COMdefo = FTC .* wdefo + 0.5 .* FDC .* dcomb;
    COMpeat = FTC .* wpeat + FHC .* hpeat + FDC .* dpeat;
end

% bweir, fixme: put somewhere else
% now adjust the fractions forested and deforested
FTC = FTC - (BAdefo ./ gridArea);  FTC(FTC<0) = 0;   % Fraction tree cover decreases with the deforested fraction
FDC = FDC + (BAdefo ./ gridArea);  FDC(FDC>1) = 1;   % Fraction deforested cover increases with the deforested fraction
