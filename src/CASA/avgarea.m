%AVGAREA  (Semi-)Conservatively transform from one lat-lon grid to another
%
%   VVq = AVGAREA(LAT, LON, VV, LATq, LONq) returns an array VVq defined on
%   the lat-lon grid specified by LATq and LONq that is an interpolant of the
%   array VV defined on the lat-lon grid specified by LAT and LON.  This
%   interpolation conserves global averages.

% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2018-06-07	Adding support for equal-area grids
%===============================================================================
function [aq, smx, smy, wq] = avgarea(xx, yy, aa, xq, yq)

% 1. Determine the fine and coarse scale coordinates
% --------------------------------------------------
xxv = unique(xx(:), 'sorted');
xqv = unique(xq(:), 'sorted');
yyv = unique(yy(:), 'sorted');
yqv = unique(yq(:), 'sorted');

if numel(xq) <= numel(xx)
  xf = xxv;
  xc = xqv;
else
  xf = xqv;
  xc = xxv;
end

if numel(yq) <= numel(yy)
  yf = yyv;
  yc = yqv;
else
  yf = yqv;
  yc = yyv;
end

% 2. Define (f) fine and (c) coarse grids
% ---------------------------------------
nxf = numel(xf);
nyf = numel(yf);

nxc = numel(xc);
nyc = numel(yc);

% Assumes equal-area grids
xfi = [-90; xf(1:end-1) + (xf(2:end) - xf(1:end-1))/2; 90];
xci = [-90; xc(1:end-1) + (xc(2:end) - xc(1:end-1))/2; 90];

dyf = yf(2) - yf(1);
dyc = yc(2) - yc(1);
yfi = [yf - dyf/2; yf(end) + dyf/2];
yci = [yc - dyc/2; yc(end) + dyc/2];

% 3. Create transformation matrix smx for x direction
% ---------------------------------------------------
smx = zeros(nxf, nxc);

i0 = 1;
for jj = 1:nxc
  smx(i0,jj) = (xfi(i0+1) - xci(jj))/(xfi(i0+1) - xfi(i0));

  for ii = i0+1:nxf
    if (xci(jj+1) <= xfi(ii+1)), break; end

    smx(ii,jj) = 1;
  end

  smx(ii,jj) = (xci(jj+1) - xfi(ii))/(xfi(ii+1) - xfi(ii));

  i0 = ii;
end

% 4. Create transformation matrix smy for y direction
% ---------------------------------------------------
% Preserve periodicty by adding copies to both longitudinal edges
yf   = [yf - 360; yf; yf + 360];
yfi  = [yf - dyf/2; yf(end) + dyf/2];
nyf0 = nyf;
nyf  = numel(yf);

smy  = zeros(nyf, nyc);

i0 = find(yfi < yci(1), 1, 'last');
if isempty(i0), i0 = 1; end

for jj = 1:nyc
  smy(i0,jj) = (yfi(i0+1) - yci(jj))/dyf;

  for ii = i0+1:nyf
    if (yci(jj+1) <= yfi(ii+1)), break; end

    smy(ii,jj) = 1;
  end

  smy(ii,jj) = (yci(jj+1) - yfi(ii))/dyf;

  i0 = ii;
end

% Second part of periodicity constraint
smy  = smy(1:nyf0,:) + smy(nyf0+1:2*nyf0,:) + smy(2*nyf0+1:end,:);
nyf  = nyf0;

% 5. Apply transformation matrices and rescale
% --------------------------------------------
if numel(xxv) < numel(xqv)
  smx = smx';
end

if numel(yyv) < numel(yqv)
  smy = smy';
end

% Rescale latitudinal averaging
for ii = 1:size(smx,1)
  smx(ii,:) = smx(ii,:)/sum(smx(ii,:));
end

% Rescale longitudinal averaging
for ii = 1:size(smy,1)
  smy(ii,:) = smy(ii,:)/sum(smy(ii,:));
end

% Treat NaNs
mask  = ones(size(aa));
imask = find(isnan(aa));
mask(imask) = 0;
aa(imask)   = 0;

% Use transformations to compute query weight (prevents ringing)
ww = mask.*globarea(xxv, yyv);
wq = smy' * ww * smx;
aq = (smy' * (aa.*ww) * smx)./wq;
