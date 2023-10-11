% PLAN to have different moisture scalars for grasses and trees

% relative drying rate (rdr) algorithm
rdr = (1 + SMparams(:,4)) ./ ((1 + (SMparams(:,4).* (last_soilm./SMparams(:,2)).^SMparams(:,5))));
rdr(PPT > PET) = 1;                % rdr is 1 if there is more PPT than PET

current_PPT = PPT;
io_freeze = AIRT < 0;                       % average temperure below zero
io_melt   = AIRT >= 0;                      % average temperure above zero

fid = last_pack + PPT;                      % add this step's PPT to last step's snowpack
pack(io_freeze) = fid(io_freeze);           % snowpack gets last step's snowpack and current PPT
current_PPT(io_freeze) = 0;                 % current PPT not available for plants (snow)

fid = current_PPT + last_pack;              % add last step's snowpack to this step's PPT
current_PPT(io_melt) = fid(io_melt);        % current PPT increases
pack(io_melt) = 0;                          % snowpack is melted

% begin estimating evapotranspiration and calculate new soil moisture

% if PET exceeds PPT, EET is limited
eeta = current_PPT + ((PET - current_PPT) .* rdr);
eetb = current_PPT + last_soilm - SMparams(:,1);

% EET becomes the smallest of EETa and EETb
io = eeta > eetb;  EET(io) = eetb(io);
io = eeta <= eetb; EET(io) = eeta(io);

% if PPT exceeds PET, EET is not limited
io = current_PPT >= PET;
fid = PET;
EET(io) = fid(io);

this_soilm = last_soilm + current_PPT - EET;

io = this_soilm > SMparams(:,2); % if estimated soil moisture exceeds field capacity, runoff will occur
fid = SMparams(:,2); this_soilm(io) = fid(io);

soilm = this_soilm;

io = PET > 0;
warning off% MATLAB:divideByZero
fid = 0.5 + (0.5.*(EET./PET));
NPPmoist_temp(io) = fid(io);

bgratio = (last_soilm - SMparams(:,1) + current_PPT) ./ PET;

% different bgratio values (too little water is limiting, too much also)
% water limited:
io = (bgratio >= 0 & bgratio <1);
fid = 0.1 + (0.9.*bgratio);
bgmoist_temp(io) = fid(io);

% also define peat burn depth
fid = bgratio;
fid(fid>1)=1;
fid(fid<0)=0;
fid = 1 - fid;
fid(isnan(fid)) = 0;
temp = 2 * fid;
% fid(boreal>0.5) = temp(boreal>0.5);
% fid(fid>1)=1;
% temp = 0.25 + 0.5 .* fid;
% fid(boreal<0.5) = temp(boreal<0.5);
% depthScalarSOC = fid;

% enough water
io = (bgratio >= 1 & bgratio <= 2);
bgmoist_temp(io) = 1;

% too much water
io = (bgratio > 2 & bgratio <= 30);
fid = (1+1/28) - ((0.5/28).*bgratio);
bgmoist_temp(io) = fid(io);

% way too much water
io = bgratio > 30;
bgmoist_temp(io) = 0.5;

% set up moisture factors for NPP calculation and BG run
% in case PET is zero
io = PET <= 0;
NPPmoist_temp(io) = NPPmoistpret(io);
bgmoist_temp(io)  = bgmoistpret(io);

NPPmoist = NPPmoist_temp;
bgmoist  = bgmoist_temp;

%ai Oct.2010
%set the NPPmoist and bgmoist to 1 for states with crops as was done in
%Zhen's code
if lower(use_crop_moisture(1)) == 'y'
%   NPPmoist(crop_states_index) = 1;
%   bgmoist(crop_states_index)  = 1;
    alpha = SINK/max(SINK(:));
    NPPmoist = (1 - alpha).*NPPmoist + alpha;
    bgmoist  = (1 - alpha).*bgmoist  + alpha;
end

% set snow pack, soil moisture, bgmoistpret, NPPmoistpret for next step
last_pack    = pack;
last_soilm   = soilm;
last_airt    = AIRT;
bgmoistpret  = bgmoist;
NPPmoistpret = NPPmoist;

NPPmoist(NPPmoist < 0) = 0; NPPmoist(NPPmoist > 1) = 1;
bgmoist (bgmoist  < 0) = 0; bgmoist (bgmoist  > 1) = 1;
