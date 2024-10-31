addpath('/discover/nobackup/bweir/matlab/globutils');

DOPLOTS = 0;
USEYEAR = 2017;

ftiger = 'tiger/tl_2022_us_county';
fprods = {'usda/barley_corn_oats__20230929.csv', ...
    'usda/sorghum_soy_wheat__20230929.csv'};

counties = shaperead(ftiger, 'UseGeoCoords', true);

% Convert from bushel to kg
% https://www.ers.usda.gov/webdocs/publications/41880/33132_ah697_002.pdf
BARLEYKG  = 21.8;
CORNKG    = 25.4;
OATSKG    = 14.5;
SORGHUMKG = 25.4;
SOYKG     = 27.2;
WHEATKG   = 27.2;

if DOPLOTS
    figure; usamap('conus');
    geoshow(counties, 'facecolor', 'none');
end

% Can replace this with CASA defineConstants
dx = 0.1;
lat = [ -90 + dx/2:dx: 90 - dx/2]';
lon = [-180 + dx/2:dx:180 - dx/2]';
[LA, LO] = meshgrid(lat, lon);

disp('Finding USCB county ids ...');

geoid = zeros(size(LA));
icon  = find(23 <= LA & LA <= 50 & -127 <= LO & LO < -65);

for nn = 1:numel(counties)
    inme = inpolygon(LA(icon), LO(icon), counties(nn).Lat, counties(nn).Lon);
    geoid(icon(inme)) = str2num(counties(nn).GEOID);
end

disp('Reading USDA crop production data ...');

barley  = zeros(size(geoid));
corn    = zeros(size(geoid));
oats    = zeros(size(geoid));
sorghum = zeros(size(geoid));
soy     = zeros(size(geoid));
wheat   = zeros(size(geoid));

% State totals for comparison to old values
stateids  = [46; 31; 20; 27;  19; 29; 55;  17;  18; 39];
prevtots  = [39; 94; 24; 75; 227; 38; 40; 211; 150; 77];
statetots = zeros(size(stateids));

for nn = 1:numel(fprods)
    CC = readcell(fprods{nn});

    for ii = 2:size(CC,1)
        prodme = str2double(CC{ii,end-1});

        % Pick only valid records in the correct year
        % Excludes Alaska as it has no county data
        if (isnan(prodme) || ~isnumeric(CC{ii,2}) || CC{ii,2} ~= USEYEAR || ...
            CC{ii,7} == 2)
            continue;
        end

        % Update county totals
        inds = find(geoid == CC{ii,7}*1000 + CC{ii,11});

        % Converts prodme to kg, adds to the correct bin, and
        % zeros-out for comparison to old state data if not corn or soy
        if     strcmp(CC{ii,17}, 'BARLEY - PRODUCTION, MEASURED IN BU')
            prodme = BARLEYKG * prodme;	
            barley(inds) = barley(inds) + prodme;
            prodme = 0;
        elseif strcmp(CC{ii,17}, 'CORN, GRAIN - PRODUCTION, MEASURED IN BU')
            prodme = CORNKG * prodme;
            corn(inds) = corn(inds) + prodme;
            prodme = 0;
        elseif strcmp(CC{ii,17}, 'OATS - PRODUCTION, MEASURED IN BU')
            prodme = OATSKG * prodme;
            oats(inds) = oats(inds) + prodme;
            prodme = 0;
        elseif strcmp(CC{ii,17}, 'SORGHUM, GRAIN - PRODUCTION, MEASURED IN BU')
            prodme = SORGHUMKG * prodme;
            sorghum(inds) = sorghum(inds) + prodme;
            prodme = 0;
        elseif strcmp(CC{ii,17}, 'SOYBEANS - PRODUCTION, MEASURED IN BU')
            prodme = SOYKG * prodme;
            soy(inds) = soy(inds) + prodme;
        elseif strcmp(CC{ii,17}, 'WHEAT - PRODUCTION, MEASURED IN BU')
            prodme = WHEATKG * prodme;
            wheat(inds) = wheat(inds) + prodme;
            prodme = 0;
        end

        % Update state totals
        for mm = 1:numel(stateids)
            if CC{ii,7} == stateids(mm)
                statetots(mm) = statetots(mm) + prodme;
            end
        end
    end
end

area = globarea(lat, lon);
countyarea = zeros(size(area));
for nn = 1:numel(counties)
    inds = find(geoid == str2num(counties(nn).GEOID));
    countyarea(inds) = sum(area(inds));
end

total = (corn*(1 - 0.155)*0.447 + soy*(1 - 0.130)*0.540)./countyarea*1000;
total(isnan(total)) = 0;

for mm = 1:numel(stateids)
    inds = find(floor(geoid/1000) == stateids(mm));
    statetots(mm) = mean(total(inds));
end

if DOPLOTS
    addpath('/discover/nobackup/bweir/matlab');
    coast = load('coast');
    cmap = brewermap(128, 'Greens');
    states = shaperead('usastatehi', 'UseGeoCoords', true);

    figure; usamap('conus');
    pcolormx(lat, lon, SINK');
    plotm(coast.lat, coast.long, 'k');
    geoshow(states, 'facecolor', 'none');
    colormap(cmap); colorbar('horz');
    title('Total harvest (g C/m2)');
    caxis([0 300]);
end

% CASA specific stuff
SINK = flipud(total');
EMAX = 0.50 * ones(size(SINK)); % 0.50 or 0.55? Al's code had 0.55 and .mat files had 0.50
inds = find(SINK > 0);
EMAX(inds) = 0.58 + 0.0013*SINK(inds);

save('SINK.mat', 'SINK', '-v7');
save('EMAX.mat', 'EMAX', '-v7');
