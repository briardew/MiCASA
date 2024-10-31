function gridArea = makeGridArea(lats, lons);

% makes a grid area map depending on the resolution 
% where x=# lat bands, y=# lon bands. So a 1 degree
% map would have 180 lats and 360 lons

% CASA library, Guido van der Werf 
% 2003 guido@ltpmail.gsfc.nasa.gov

%radius = 6378140;		% Original (m at equator)
%radius = 6371007.181;		% MODIS/VIIRS
radius = 6371000.000;		% GEOS

gridArea = zeros(lats, lons);

for lat = 1:lats
%   Original (wrong?)
%   ---
%   gridArea(lat,1) = (2*pi*radius./lons) * ((cos((-0.5 - 1/(2*lats) + lat/lats)*pi) * 2*pi*radius)/lons);

%   gridArea(lat,1) = radius^2 * 2*pi/lons * cos(0.5*pi - ((lat - 0.5)/lats)*pi) * 2*pi/lons;
%   gridArea(lat,1) = radius^2 * 2*pi/lons * sin((lat - 0.5)/lats*pi) * 2*pi/lons;
%   Assuming lons = 2*lats
%   gridArea(lat,1) = radius^2 * pi/lats * sin((lat - 0.5)/lats*pi) ...
%                              * 2*pi/lons;
%   Should match below to first order in Taylor series

%   Correct
%   ---
%   NB: 2/lons = dx/180
    gridArea(lat,1) = radius^2 * (cos((lat - 1)/lats*pi) - cos(lat/lats*pi)) ...
                               * 2*pi/lons;
end

for lon = 2:lons
    gridArea(:,lon) = gridArea(:,1);
end
