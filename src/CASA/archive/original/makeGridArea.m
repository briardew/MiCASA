function gridArea = makeGridArea(lats,lons);

% makes a grid area map depending on the resolution 
% where x=# lat bands, y=# lon bands. So a 1 degree
% map would have 180 lats and 360 lons

% CASA library, Guido van der Werf 
% 2003 guido@ltpmail.gsfc.nasa.gov

radius      = 6378140;          % m at equator
gridArea    = zeros(lats,lons);

for lat=1:lats
    gridArea(lat,1) = (2*pi*radius./lons) * ((cos((-0.5 - 1/(2*lats) + lat/lats)*pi) * 2*pi*radius)/lons);
end

for lon=2:lons
    gridArea(:,lon)=gridArea(:,1);
end
