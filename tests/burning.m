% --- GFED5 iLCT ---
%  1 Water
%  2 Boreal forest
%  3 Tropical forest
%  4 Temperate forest
%  5 Temperate mosaic
%  6 Tropical shrublands
%  7 Temperate shrublands
%  8 Temperate grasslands
%  9 Woody savanna
% 10 Open savanna
% 11 Tropical grasslands
% 12 Wetlands
% 13 Tropical crop		(0 in Norm)
% 14 Urban
% 15 Temperate crop		(0 in Norm)
% 16 Snow/Ice
% 17 Barren
% 18 Sparse boreal forest
% 19 Tundra
% 20 Boreal crop		(0 in Norm)


addpath('/discover/nobackup/bweir/matlab/globutils');

YEAR0 = 2003;			% Start year
YEARF = 2020;			% End year: Comparison

% Read grid data
fmi = '../data/burn/2003/modvir_burn.x3600_y1800.monthly.200301.nc';
fgf = '../data-aux/GFED5/BA200301.nc';

latmi  = ncread(fmi, 'lat');
lonmi  = ncread(fmi, 'lon');
NLATMI = numel(latmi);
NLONMI = numel(lonmi);
areami = globarea(latmi, lonmi, 6371007.181);

latgf  = ncread(fgf, 'lat');
longf  = ncread(fgf, 'lon');
NLATGF = numel(latgf);
NLONGF = numel(longf);
areagf = globarea(latgf, longf, 6371007.181);

burnmi = zeros(NLONMI, NLATMI, 3);
burngf = zeros(NLONGF, NLATGF, 24);

for year = YEAR0:YEARF
    yrlen = datenum(year+1, 01, 01) - datenum(year, 01, 01);
    syear = num2str(year);
    for nm = 1:12
        smon = num2str(nm, '%02u');
        molen = datenum(year, nm+1, 01) - datenum(year, nm, 01);

        fmi = ['../data/burn/', syear, '/modvir_burn.x3600_y1800.monthly.', ...
            syear, smon, '.nc'];
        fgf = ['../data-aux/GFED5/BA', syear, smon, '.nc'];

        burnmi(:,:,1) = burnmi(:,:,1) + 12*molen/yrlen*1e-6*ncread(fmi, 'bawood');
        burnmi(:,:,2) = burnmi(:,:,2) + 12*molen/yrlen*1e-6*ncread(fmi, 'badefo');
        burnmi(:,:,3) = burnmi(:,:,3) + 12*molen/yrlen*1e-6*ncread(fmi, 'baherb');

        burngf(:,:,1:20) = burngf(:,:,1:20) + 12*molen/yrlen*ncread(fgf, 'Norm');
        burngf(:,:,  21) = burngf(:,:,  21) + 12*molen/yrlen*ncread(fgf, 'Defo');
        burngf(:,:,  22) = burngf(:,:,  22) + 12*molen/yrlen*ncread(fgf, 'Peat');
        burngf(:,:,  23) = burngf(:,:,  23) + 12*molen/yrlen*ncread(fgf, 'Crop');
        burngf(:,:,  24) = burngf(:,:,  24) + 12*molen/yrlen*ncread(fgf, 'Total');
    end
end
burnmi = burnmi/(YEARF - YEAR0 + 1);
burngf = burngf/(YEARF - YEAR0 + 1);

% Regrid after climatology (saves time); remember these are areas
burnmx = zeros(NLONGF, NLATGF, 3);
for nn = 1:3
    burnmx(:,:,nn) = avgarea(latmi, lonmi, burnmi(:,:,nn)./areami, ...
        latgf, longf).*areagf;
end

woodmx = burnmx(:,:,1);
defomx = burnmx(:,:,2);
herbmx = burnmx(:,:,3);

woodgf = sum(burngf(:,:,[1:7,9,12:20]),   3);
herbgf = sum(burngf(:,:,[8,10,11,22:23]), 3);
defogf =     burngf(:,:,21);
