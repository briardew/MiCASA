% calculates combustion completeness (CC, also called combustion factor)

% fuel is split into live wood, live leaves (includes grass), fine litter and coarse litter (cwd)
% 
%   min CC  max CC  fuel type
CC = [0.2     0.4     % live wood
      0.8     1.0     % live leaves 
      0.9     1.0     % fine litter 
      0.4     0.6];   % coarse litter

CC = single(CC);

PD = [0.00 0.15          % depth of organic soil burning [m](boreal forest regions)
      0.00 0.50];        % depth of peat burning [m](mostly Indonesia) 

% 20090806: all CC now scaled by PPt/PET ratio, previously the biomass
% pools were scaled based on the NPP moisture scalar. This takes out the
% variability in the boreal region

% scaling based on PPT/PET ratio with coarse fuels having memory from
% previous step

% calculate ratio
PET_current = PET;
PET_current(PET_current==0) = 0.1;  % prevent dividing by 0
CCratio_current = PPT ./ PET_current;
CCratio_current(CCratio_current>1) = 1;
CCratio_current = 1 - CCratio_current;

% CC for all fires except deforestation fires 
ccWood       = 0.4.*(CC(1,1)+(CC(1,2)-CC(1,1)).*CCratio_previous)+0.6.*(CC(1,1)+(CC(1,2)-CC(1,1)).*CCratio_current);
ccLeaf       = 0.1.*(CC(2,1)+(CC(2,2)-CC(2,1)).*CCratio_previous)+0.9.*(CC(2,1)+(CC(2,2)-CC(2,1)).*CCratio_current);
ccFineLitter = 0.1.*(CC(3,1)+(CC(3,2)-CC(3,1)).*CCratio_previous)+0.9.*(CC(3,1)+(CC(3,2)-CC(3,1)).*CCratio_current);
ccCwd        = 0.4.*(CC(4,1)+(CC(4,2)-CC(4,1)).*CCratio_previous)+0.6.*(CC(4,1)+(CC(4,2)-CC(4,1)).*CCratio_current);

% CC for deforestation fires are multiplied with fire persistence (FP) to
% account for repetetive burning. In the main deforestation regions 95% of
% FP is below 4 (weighted by deforestation rate) so this is take as the 
% maximum. If this maximum is reached all biomass should be combusted
fid = ccWood + (1-(CC(1,1))) .* ((FP-1)./3);   fid(fid>1)=1;   ccWoodDefo = fid;
fid = ccCwd  + (1-(CC(4,1))) .* ((FP-1)./3);   fid(fid>1)=1;   ccCwdDefo  = fid;

% mortality also changes based on fire persistence with 80% mortality in
% low persistence (conversions to pasture) and 100% in high persistence
% (conversions to agriculture, plantations)
mortality_deforestation = 0.8 + 0.2 * (FP-1) ./ 4;
mortality_deforestation(mortality_deforestation > 1) = 1;

dump = FP ./ 6; dump(dump>0.8)=0.8; % never burn deeper than 80 cm
% divide ccSOIL by 0.3 because layer is 30cm deep
ccSOIL = (0.3.*(PD(1,1)+(PD(1,2)-PD(1,1)).*CCratio_previous)+0.7.*(PD(1,1)+(PD(1,2)-PD(1,1)).*CCratio_current)) ./ 0.3;
ccPEAT = ((0.3.*(PD(2,1)+(PD(2,2)-PD(2,1)).*CCratio_previous)+0.7.*(PD(2,1)+(PD(2,2)-PD(2,1)).*CCratio_current)) .* ...
         dump).^0.5; % scaled by both moisture conditions and fire persistence

% keep current step's ratio for next step's run
CCratio_previous = CCratio_current;

% belowground herbaceous roots (they usually survive, and die only when the
% fire is extremely hot)
mortality_hfroot = single(0.1);
