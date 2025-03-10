%GLOBAREA  Compute array of cell areas for a lat-lon grid
%
%   AREA = GLOBAREA(LAT, LON) returns an array AREA of the cells in the grid
%   specified by LAT and LON in square meters.
%
%   This function follows the GEOS conventions used in the MAPL_Constants
%   module: the Earth is a sphere with a 6371 km radius.  This gives a total
%   surface area of 4*pi*6371^2*1e6 = 5.1006e14.  This should be the sum
%   of the returned array AREA.

% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2018-06-07	Adding support for equal-area grids
%===============================================================================
function area = globarea(lat, lon, radius)

% Note: this is supported, but as wasn't used in v1
if ~exist('radius', 'var')
    % Default value from GEOS in meters; NB: MODIS uses 6371007.181
    radius = 6371000.0;
end

% Old approach for constant dlat
dlat  = lat(2) - lat(1);
xlat0 = max(lat - dlat/2, -90);
xlat1 = min(lat + dlat/2,  90);

%% New approach for equal-area grids
%late  = [-90; lat(1:end-1) + (lat(2:end) - lat(1:end-1))/2; 90];
%xlat0 = late(1:end-1);
%xlat1 = late(2:end);

dlon  = lon(2) - lon(1);

[vlat0, vlon0] = meshgrid(xlat0, lon-dlon/2);
[vlat1, vlon1] = meshgrid(xlat1, lon+dlon/2);

area = 2*pi*radius^2  * abs(sind(vlat0) - sind(vlat1)) ...
                     .* abs(vlon0 - vlon1)/360;
