% Calculate Net Primary Production (NPP)

if mod(year,400) == 0 || (mod(year,4) == 0 && mod(year,100) > 0)
    modays = [31 29 31 30 31 30 31 31 30 31 30 31];
else
    modays = [31 28 31 30 31 30 31 31 30 31 30 31];
end

% Why the 15.778? ***FIXME***
SOLARCONVERSION = single(15.778 ./ 365);
if NSTEPS == 12
    % month_ is set in updateCASAinput
    SOLARCONVERSION = modays(month_) * SOLARCONVERSION;
end

IPAR = FPAR .* SOLRAD .* SOLARCONVERSION;

% T1 is the temperature effect relating for each site the optimal temperature
% for highest NDVI (TOPT) to the temperature considered to be generally the
% most optimal for photosynthesis, 20 degrees C. T2 is the effect of variable 
% air temperature throughout the year around TOPT.
T1     = 0.8 + (0.02 * topt) - (0.0005 * (topt.^2));
T2low  = 1./(1 + exp(0.2.*(topt - 10 - AIRT)));
T2high = 1./(1 + exp(0.3.*(AIRT - 10 - topt)));
    
NPPtemp = T1 .* (1.1919 .* T2low .* T2high);
NPPtemp(T1 < 0 | T2low < 0 | T2high < 0) = 0;
NPPtemp(AIRT < -10) = 0;
NPPtemp(NPPtemp > 1) = 1;

epsilon = EMAX .* NPPtemp .* NPPmoist;
% bweir: needs to account for total vegetated fraction
% Was a bug previously where FTC + FHC very often was maxed out at 1
NPP = epsilon .* IPAR ./ (FTC + FHC + FDC);

% Derive abiotic effect for each timestep in the cycle
% ---
% bweir: Change to Lloyd and Taylor approach
% A. Old, Q10-style
bgtemp = Q10.^((AIRT - TEMP0) ./ 10);
bgtemp(bgtemp > 1) = 1;

% B. Lloyd and Taylor (1994; )
%bgtemp = R10 * exp(308.56 * (1/56.02 - 1./(AIRT + 46.02)));
%bgtemp(AIRT <= -46.02) = 0;

abiotic = bgmoist .* bgtemp;

% Needed for herbivory (keep at spin-up values)
% bweir: month hack
if year == spinUpYear1
    NPPmo(:,month_) = NPP;
end
