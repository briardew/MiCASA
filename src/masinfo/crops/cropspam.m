DOPLOTS = 0;

addpath('/discover/nobackup/bweir/matlab/globutils');

% VERY HACKY (***FIXME***)
%dxin = 1/12;
%latin = [-64-5/12 + dxin/2:dxin: 90 - dxin/2]';
%lonin = [    -180 + dxin/2:dxin:180 - dxin/2]';
%fcorn = '../data-aux/SPAM/2005/SPAM2005V3r2_global_P_TA_SOYB_A.tif';
%fsoy  = '../data-aux/SPAM/2005/SPAM2005V3r2_global_P_TA_MAIZ_A.tif';

dxin = 1/12;
latin = [ -90 + dxin/2:dxin: 90 - dxin/2]';
lonin = [-180 + dxin/2:dxin:180 - dxin/2]';
fcorn = '../data-aux/SPAM/2010/spam2010V2r0_global_P_MAIZ_A.tif';
fsoy  = '../data-aux/SPAM/2010/spam2010V2r0_global_P_SOYB_A.tif';

% Can replace this with CASA defineConstants
dx = 0.1;
lat = [ -90 + dx/2:dx: 90 - dx/2]';
lon = [-180 + dx/2:dx:180 - dx/2]';

totin = zeros(numel(lonin), numel(latin));

% P_TA = Production, All technologies
% conversion = (1 - % water/100) * % carbon/100
% Constants from Bernacchi et al. (2005; https://doi.org/10.1111/j.1365-2486.2005.01050.x)
corn = struct('name','corn', 'file',fcorn, 'values',totin, ...
    'conversion',(1 - 0.155) * 0.447);
soy  = struct('name','soy', 'file',fsoy, 'values',totin, ...
    'conversion',(1 - 0.130) * 0.540);

crops = [corn; soy];

for nn = 1:numel(crops)
    ff = crops(nn).file;

    [AA, RR] = readgeoraster(ff, 'outputtype', 'double');
    AA = max(AA, 0);

    crops(nn).values = crops(nn).conversion * flipud(AA)';
    totin = totin + crops(nn).values;
end

[LA, LO] = meshgrid(lat, lon);
weight = min(max((LA - 23)/(27 - 23), 0), 1);
areain = globarea(latin, lonin);

totre = 1e6 * avgarea(latin, lonin, totin./areain, lat, lon);
total = totre .* weight;

%% CASA-specific stuff
SINK = flipud(total');

EMAX = 0.55 * ones(size(SINK)); % 0.50 or 0.55? al's code had 0.55 and .mat files had 0.50
inds = find(SINK > 0);
EMAX(inds) = 0.55 + 0.0013*SINK(inds);
%EMAX = 0.75 * ones(size(SINK)); % 0.50 or 0.55? al's code had 0.55 and .mat files had 0.50
%inds = find(SINK > 0);
%EMAX(inds) = 0.75 + 0.0013*SINK(inds);

save('SINK.mat', 'SINK', '-v7');
save('EMAX.mat', 'EMAX', '-v7');

if DOPLOTS
    addpath('/discover/nobackup/bweir/matlab');
    coast = load('coast');
    cmap = brewermap(128, 'Greens');
    states = shaperead('usastatehi', 'UseGeoCoords', true);

    figure; usamap('conus');
%   figure; worldmap('world');
    pcolormx(lat, lon, total');
    plotm(coast.lat, coast.long, 'k');
    geoshow(states, 'facecolor', 'none');
    title('Total harvest (g C/m2)');
    colormap(cmap); colorbar('horz');
    caxis([0 300]);
end
