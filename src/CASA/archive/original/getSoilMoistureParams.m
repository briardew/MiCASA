% getSoilMoistureParameters
%
% makes a matrix for each gridcell with:
% column    1   2   3   4   5
% parameter wp  fc  ssc a   b
%
% where wp  = wilting point
%       fc  = field capacity
%       ssc = soil water storage capacity
%       a   = alpha = value used to determine relative drying rate (rdr)
%       b   = beta  = value used to determine relative drying rate (rdr)

wp    = zeros(numberOfGridCells,1,'single');
fc    = zeros(numberOfGridCells,1,'single');
ssc   = zeros(numberOfGridCells,1,'single');
alpha = zeros(numberOfGridCells,1,'single');
beta  = zeros(numberOfGridCells,1,'single');

text = SOILTEXT;
text(text==7)=6;

% grassland biomes:
fid = VEG>5;
io = text==1 & fid==1; wp(io) = 129; fc(io) = 232; ssc(io) = 455; alpha(io) = 0.002; beta(io) = -6.54;
io = text==2 & fid==1; wp(io) =  81; fc(io) = 202; ssc(io) = 394; alpha(io) = 0.002; beta(io) = -5.48;
io = text==3 & fid==1; wp(io) = 129; fc(io) = 232; ssc(io) = 455; alpha(io) = 0.002; beta(io) = -6.54;
io = text==4 & fid==1; wp(io) = 220; fc(io) = 393; ssc(io) = 642; alpha(io) = 0.013; beta(io) = -6.57;
io = text==5 & fid==1; wp(io) = 270; fc(io) = 405; ssc(io) = 527; alpha(io) = 0.006; beta(io) = -9.47;
io = text==6 & fid==1; wp(io) = 275; fc(io) = 363; ssc(io) = 387; alpha(io) = 0.004; beta(io) = -13.8;

% tree biomes
io = text==1 & fid~=1; wp(io) = 258; fc(io) = 463; ssc(io) = 909; alpha(io) = 0.002; beta(io) = -6.54;
io = text==2 & fid~=1; wp(io) = 203; fc(io) = 506; ssc(io) = 984; alpha(io) = 0.002; beta(io) = -5.48;
io = text==3 & fid~=1; wp(io) = 258; fc(io) = 463; ssc(io) = 909; alpha(io) = 0.002; beta(io) = -6.54;
io = text==4 & fid~=1; wp(io) = 338; fc(io) = 604; ssc(io) = 987; alpha(io) = 0.013; beta(io) = -6.57;
io = text==5 & fid~=1; wp(io) = 433; fc(io) = 647; ssc(io) = 843; alpha(io) = 0.006; beta(io) = -9.47;
io = text==6 & fid~=1; wp(io) = 472; fc(io) = 622; ssc(io) = 663; alpha(io) = 0.004; beta(io) = -13.8;

SMparams(:,1) = wp;
SMparams(:,2) = fc;
SMparams(:,3) = ssc;
SMparams(:,4) = alpha;
SMparams(:,5) = beta;

last_soilm = wp;  % begin soilmoisture set at wilting point
last_airt  = NaN;  % begin airtemperature set at NaN

clear text wp fc ssc alpha beta
