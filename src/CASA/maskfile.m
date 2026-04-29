%MASKFILE  Masks a lat-lon array
%
%   Y = MASKFILE(X, M) reads a lat-lon array X, applies a lat-lon mask M, and
%   returns a masked array Y.

% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2026-03-03	Rewrote for simplicity
%===============================================================================
function yy = maskfile(xx, mask)

% Life would be much easier without these transposes, but it breaks backward
% compatibility and is a big effort to fix. Maybe another day :(
mast = mask';
xt = xx';

% Needed for zero-diff, returns a double instead of type of xx
yy = zeros(sum(mask(:)), 1);
yy(:) = xt(mast(:) == 1);
