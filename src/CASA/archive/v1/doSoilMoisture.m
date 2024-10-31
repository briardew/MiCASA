% PLAN to have different moisture scalars for grasses and trees

% TODO: Make consistent with defineArrays (***FIXME***)

if ~exist('mean_pack', 'var'), mean_pack  = last_pack;  end
if ~exist('mean_soilm','var'), mean_soilm = last_soilm; end
if ~exist('mean_bgmoist', 'var'), mean_bgmoist  = bgmoistpret;  end
if ~exist('mean_NPPmoist','var'), mean_NPPmoist = NPPmoistpret; end

if month_ ~= last_month
    % Set snow pack, soil moisture, bgmoistpret, NPPmoistpret for next step
    last_month = month_;
    last_pack  = mean_pack;
    last_soilm = mean_soilm;
    bgmoistpret  = mean_bgmoist;
    NPPmoistpret = mean_NPPmoist;

    pack0  = pack;
    soilm0 = soilm;
    bgmoist0  = bgmoist;
    NPPmoist0 = NPPmoist;

    mean_pack  = 0;
    mean_soilm = 0;
    mean_bgmoist  = 0;
    mean_NPPmoist = 0;
end

% Rescale precip to appear as month-1 (trust me)
% month_ and molen_ are set in updateCASAinput
PPT_keep = PPT;
PPT = PPT*molen_;

% relative drying rate (rdr) algorithm
rdr = (1 + SMparams(:,4)) ./ (1 + SMparams(:,4).*(last_soilm./SMparams(:,2)).^SMparams(:,5));
rdr(PPT > PET) = 1;                         % rdr is 1 if there is more PPT than PET

current_PPT = PPT;
io_freeze = AIRT < 0;                       % average temperure below zero
io_melt   = AIRT >= 0;                      % average temperure above zero

fid = last_pack + PPT;                      % add this step's PPT to last step's snowpack
new_pack = pack;
new_pack(io_freeze) = fid(io_freeze);       % snowpack gets last step's snowpack and current PPT
current_PPT(io_freeze) = 0;                 % current PPT not available for plants (snow)

fid = current_PPT + last_pack;              % add last step's snowpack to this step's PPT
current_PPT(io_melt) = fid(io_melt);        % current PPT increases
new_pack(io_melt) = 0;                      % snowpack is melted

% begin estimating evapotranspiration and calculate new soil moisture

% if PET exceeds PPT, EET is limited
eeta = current_PPT + (PET - current_PPT).*rdr;
eetb = current_PPT + last_soilm - SMparams(:,1);

% EET becomes the smallest of EETa and EETb
io = eeta >  eetb; EET(io) = eetb(io);
io = eeta <= eetb; EET(io) = eeta(io);

% if PPT exceeds PET, EET is not limited
io = current_PPT >= PET;
fid = PET;
EET(io) = fid(io);

new_soilm = last_soilm + current_PPT - EET;

io = new_soilm > SMparams(:,2); % if estimated soil moisture exceeds field capacity, runoff will occur
fid = SMparams(:,2);
new_soilm(io) = fid(io);

io = PET > 0;
NPPmoist_temp(io) = 0.5 + 0.5*EET(io)./PET(io);

bgratio = (last_soilm - SMparams(:,1) + current_PPT)./PET;

% different bgratio values (too little water is limiting, too much also)
% water limited:
io = 0 <= bgratio & bgratio < 1;
bgmoist_temp(io) = 0.1 + 0.9*bgratio(io);

% also define peat burn depth
fid  = 1 - min(1, max(0, bgratio));
temp = 2 * fid;
% fid(boreal>0.5) = temp(boreal>0.5);
% fid(fid>1)=1;
% temp = 0.25 + 0.5 .* fid;
% fid(boreal<0.5) = temp(boreal<0.5);
% depthScalarSOC = fid;

% enough water
io = 1 <= bgratio & bgratio <= 2;
bgmoist_temp(io) = 1;

% too much water
io = 2 < bgratio & bgratio <= 30;
bgmoist_temp(io) = 1 + 1/28 - 0.5/28*bgratio(io);

% way too much water
io = 30 < bgratio;
bgmoist_temp(io) = 0.5;

%ai Oct.2010
%set the NPPmoist and bgmoist to 1 for states with crops as was done in Zhen's code
%bweir: added second option as first is a little heavy handed
if lower(use_crop_moisture(1)) == 'y'
    NPPmoist_temp(crop_states_index) = 1;
    bgmoist_temp(crop_states_index)  = 1;
elseif lower(use_sink(1)) == 'y'
    alpha = SINK/max(SINK(:));
    NPPmoist_temp = (1 - alpha).*NPPmoist_temp + alpha;
    bgmoist_temp  = (1 - alpha).*bgmoist_temp  + alpha;
end

% set up moisture factors for NPP calculation and BG run
% in case PET is zero
io = PET <= 0;
NPPmoist_temp(io) = NPPmoistpret(io);
bgmoist_temp(io)  = bgmoistpret(io);

if molen_ == 1
    % Update monthly
    pack  = new_pack;
    soilm = new_soilm;
    NPPmoist = NPPmoist_temp;
    bgmoist  = bgmoist_temp;
else
    % Update daily (factor of 2 so midpoint is monthly mean)
    pack  = pack  + 2/molen_*(new_pack  - pack0);
    soilm = soilm + 2/molen_*(new_soilm - soilm0);
    NPPmoist = NPPmoist + 2/molen_*(NPPmoist_temp - NPPmoist0);
    bgmoist  = bgmoist  + 2/molen_*(bgmoist_temp  - bgmoist0);

    % This poorly vetted approach could go negative, testing consequences
    if lower(do_soilm_bug(1)) == 'n'
        pack  = max(0, pack);
        soilm = max(0, soilm);
    end
end

% May need to move this/apply to different vars if we do the above ***FIXME***
NPPmoist = min(1, max(0, NPPmoist));
bgmoist  = min(1, max(0, bgmoist));

% Average snow pack, soil moisture, bgmoistpret, NPPmoistpret for next step
mean_pack  = mean_pack  + pack/molen_;
mean_soilm = mean_soilm + soilm/molen_;
mean_bgmoist  = mean_bgmoist  + bgmoist/molen_;
mean_NPPmoist = mean_NPPmoist + NPPmoist/molen_;

% Return PPT to unscaled value
PPT = PPT_keep;

clear new_pack new_soilm PPT_keep;
