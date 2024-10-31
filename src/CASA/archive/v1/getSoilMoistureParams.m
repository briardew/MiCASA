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

% See Potter et al. (1993; https://doi.org/10.1029/93GB02725) for all parameters
% except ssc; Says wp and fc for grass are half of tree values, but not quite
% Bouwman et al. (1993; https://doi.org/10.1029/93GB01186) cited, but not used?

if lower(do_deprecated(1)) == 'y'
    text = SOILTEXT;
    text(text == 7) = 6;

    % Grassland biomes
    io = text == 1 & VEG  > 5; wp(io) = 129; fc(io) = 232; ssc(io) = 455; alpha(io) = 0.002; beta(io) = -6.54; % peat => coarse/medium
    io = text == 2 & VEG  > 5; wp(io) =  81; fc(io) = 202; ssc(io) = 394; alpha(io) = 0.002; beta(io) = -5.48; % coarse
    io = text == 3 & VEG  > 5; wp(io) = 129; fc(io) = 232; ssc(io) = 455; alpha(io) = 0.002; beta(io) = -6.54; % coarse/medium
    io = text == 4 & VEG  > 5; wp(io) = 220; fc(io) = 393; ssc(io) = 642; alpha(io) = 0.013; beta(io) = -6.57; % medium
    io = text == 5 & VEG  > 5; wp(io) = 270; fc(io) = 405; ssc(io) = 527; alpha(io) = 0.006; beta(io) = -9.47; % medium/fine
    io = text == 6 & VEG  > 5; wp(io) = 275; fc(io) = 363; ssc(io) = 387; alpha(io) = 0.004; beta(io) = -13.8; % fine

    % Tree biomes
    io = text == 1 & VEG <= 5; wp(io) = 258; fc(io) = 463; ssc(io) = 909; alpha(io) = 0.002; beta(io) = -6.54; % peat => coarse/medium
    io = text == 2 & VEG <= 5; wp(io) = 203; fc(io) = 506; ssc(io) = 984; alpha(io) = 0.002; beta(io) = -5.48; % coarse
    io = text == 3 & VEG <= 5; wp(io) = 258; fc(io) = 463; ssc(io) = 909; alpha(io) = 0.002; beta(io) = -6.54; % coarse/medium
    io = text == 4 & VEG <= 5; wp(io) = 338; fc(io) = 604; ssc(io) = 987; alpha(io) = 0.013; beta(io) = -6.57; % medium
    io = text == 5 & VEG <= 5; wp(io) = 433; fc(io) = 647; ssc(io) = 843; alpha(io) = 0.006; beta(io) = -9.47; % medium/fine
    io = text == 6 & VEG <= 5; wp(io) = 472; fc(io) = 622; ssc(io) = 663; alpha(io) = 0.004; beta(io) = -13.8; % fine
else
    % Uses linear fits to above along with reported average sand and clay
    % values from Potter et al. (1993; https://doi.org/10.1029/93GB02725)
    % Log transform needed for alpha to behave

    % Grassland biomes
    z1wp  = [343.08; -325.73;   -6.21];
    z1fc  = [719.84; -613.16; -364.58];
    z1ssc = [144.48; -115.02; -129.63]*10;

    io = VEG > 5;
    wp(io)  = z1wp( 1) + z1wp( 2)*sand(io) + z1wp( 3)*clay(io);
    fc(io)  = z1fc( 1) + z1fc( 2)*sand(io) + z1fc( 3)*clay(io);
    ssc(io) = z1ssc(1) + z1ssc(2)*sand(io) + z1ssc(3)*clay(io);

    % Tree biomes
    z2wp  = [326.24; -187.17;  284.43];
    z2fc  = [687.33; -258.75;   -8.69];
    z2ssc = [152.15;  -55.47; -114.39]*10;

    io = VEG <= 5;
    wp(io)  = z2wp( 1) + z2wp( 2)*sand(io) + z2wp( 3)*clay(io);
    fc(io)  = z2fc( 1) + z2fc( 2)*sand(io) + z2fc( 3)*clay(io);
    ssc(io) = z2ssc(1) + z2ssc(2)*sand(io) + z2ssc(3)*clay(io);

    % All biomes
    zzal = [ -5.25; -304.68; -278.42]/100;
    zzbe = [ 46.02;  -96.52; -250.02]/10;

    alpha = 10.^(zzal(1) + zzal(2)*sand + zzal(3)*clay);
    beta  = zzbe(1) + zzbe(2)*sand + zzbe(3)*clay;
end

SMparams(:,1) = wp;
SMparams(:,2) = fc;
SMparams(:,3) = ssc;
SMparams(:,4) = alpha;
SMparams(:,5) = beta;

last_soilm = wp;	% begin soilmoisture set at wilting point
last_month = 0;         % begin month (to know when to update)

clear text wp fc ssc alpha beta
