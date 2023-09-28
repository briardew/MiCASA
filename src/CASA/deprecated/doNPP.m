% Calculate Net Primary Production (NPP)

if year == 1996 | year == 2000 | year == 2004 | year == 2008 | year == 2012
    molens = [31 29 31 30 31 30 31 31 30 31 30 31];
else
    molens = [31 28 31 30 31 30 31 31 30 31 30 31];        
end
% bweir, fixme: month hack
month = step;
SOLARCONVERSION = molens(month) * single(15.778 ./ 365);

% T1 is the temperature effect relating for each site the optimal temperature
% for highest NDVI (TOPT) to the temperature considered to be generally the
% most optimal for photosynthesis, 20 degrees C. T2 is the effect of variable 
% air temperature throughout the year around TOPT.
T1     = 0.8 + (0.02 * topt) - (0.0005 * (topt.^2));
T2low  = 1./(1 + exp(0.2.*(topt - 10 - AIRT)));
T2high = 1./(1 + exp(0.3.*(AIRT - 10 - topt)));
    
NPPtemp = T1 .* (1.1919 .* T2low .* T2high);
NPPtemp(T1 < 0 | T2low < 0 | T2high < 0)=0;
NPPtemp(AIRT < -10)=0;
NPPtemp(NPPtemp > 1) = 1;

%ai replace constant EMAX usage with spatially varying EMAX
%note: the equation remains the same whether EMAX is a constant or a column
%vector
%epsilon = EMAX .* NPPtemp .* NPPmoist;
epsilon = EMAX .* NPPtemp .* NPPmoist;


IPAR = FPAR .* SOLRAD .* SOLARCONVERSION;
NPP  = epsilon .* IPAR;

% derive abiotic effect for each timestep in the cycle
bgtemp = Q10.^((AIRT - 30) ./ 10);

bgtemp(bgtemp > 1) = 1;
abiotic = bgmoist .* bgtemp;  % abiotic effect

% bweir, fixme: month hack
month = step;
NPPmo(:,month) = NPP;
