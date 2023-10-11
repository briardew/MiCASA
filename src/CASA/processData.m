if NSTEPS == 12
    % bweir, fixme: month hack
    month = step;
    if year >= spinUpYear_2
        % So not neccessarily the actual values? (bweir, fixme)
        eval(['NPP' int2str(year) '(:,month) = (FTC + FHC + FDC)  .* NPP;'])
        eval(['RES' int2str(year) '(:,month) = FTC .* wresp + FHC .* hresp + FDC .* dresp;'])
        eval(['HER' int2str(year) '(:,month) = FTC .* wherb + FHC .* hherb + FDC .* dherb;'])
        eval(['FUE' int2str(year) '(:,month) = FTC .* wfuel;'])
    
        eval(['COMwood' int2str(year) '(:,month) = FTC .* wcomb;'])
        eval(['COMherb' int2str(year) '(:,month) = FHC .* hcomb + 0.5 .* FDC .* dcomb;']);
    end

    if year >= startYear
        eval(['COMdefo' int2str(year) '(:,month) = FTC .* wdefo + 0.5 .* FDC .* dcomb;']);
        eval(['COMpeat' int2str(year) '(:,month) = FTC .* wpeat + FHC .* hpeat + FDC .* dpeat;'])
    end
end

% bweir, fixme: put somewhere else
% now adjust the fractions forested and deforested
FTC = FTC - (BAdefo ./ gridArea);  FTC(FTC<0) = 0;   % Fraction tree cover decreases with the deforested fraction
FDC = FDC + (BAdefo ./ gridArea);  FDC(FDC>1) = 1;   % Fraction deforested cover increases with the deforested fraction
