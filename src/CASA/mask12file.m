%MASK12FILE  Masks a lat-lon-month array
%
%   Y = MASK12FILE(X, M) reads a lat-lon-month array X, applies a lat-lon mask
%   M for each month, and returns a masked array Y with one column per month.

% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2018-06-07	Adding support for equal-area grids
%===============================================================================
function yy = mask12file(xx, mask)

yy = zeros(sum(mask(:)), 12);
for mm = 1:12
    yy(:,mm) = maskfile(xx(:,:,mm), mask);
end
