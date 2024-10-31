[AA1, RR] = readgeoraster('sand_0-5cm_mean_0.1x0.1.tif');
[AA2, RR] = readgeoraster('sand_5-15cm_mean_0.1x0.1.tif');
[AA3, RR] = readgeoraster('sand_15-30cm_mean_0.1x0.1.tif');

AA1(AA1 < 0) = NaN;
AA2(AA2 < 0) = NaN;
AA3(AA3 < 0) = NaN;

t_sand = nansum(cat(3, AA1*5, AA2*10, AA3*15), 3)/30/1000;

[AA1, RR] = readgeoraster('silt_0-5cm_mean_0.1x0.1.tif');
[AA2, RR] = readgeoraster('silt_5-15cm_mean_0.1x0.1.tif');
[AA3, RR] = readgeoraster('silt_15-30cm_mean_0.1x0.1.tif');

AA1(AA1 < 0) = NaN;
AA2(AA2 < 0) = NaN;
AA3(AA3 < 0) = NaN;

t_silt = nansum(cat(3, AA1*5, AA2*10, AA3*15), 3)/30/1000;

[AA1, RR] = readgeoraster('clay_0-5cm_mean_0.1x0.1.tif');
[AA2, RR] = readgeoraster('clay_5-15cm_mean_0.1x0.1.tif');
[AA3, RR] = readgeoraster('clay_15-30cm_mean_0.1x0.1.tif');

AA1(AA1 < 0) = NaN;
AA2(AA2 < 0) = NaN;
AA3(AA3 < 0) = NaN;

t_clay = nansum(cat(3, AA1*5, AA2*10, AA3*15), 3)/30/1000;

%[AA, RR] = readgeoraster('sand_5-15cm_mean_0.1x0.1.tif');
%[AA, RR] = readgeoraster('sand_5-15cm_mean_0.1x0.1.tif');
%
%% In ???
%[SOCin, RR] = readgeoraster('soc_0-5cm_mean_1000_latlon.tif');
%SOCin = max(SOCin, 0);
%% In cm3/100*cm3
%[CFVOin, RR] = readgeoraster('cfvo_0-5cm_mean_1000_latlon.tif');
%CFVOhi(CFVOhi < 0) = 0;
%CFVOhi = CFVOhi/100;
%
%[BBhi, RR] = readgeoraster('soc_5-15cm_mean_1000_latlon.tif');
%%BBhi(BBhi < 0) = NaN;
%BBhi(BBhi < 0) = 0;
%AAhi = AAhi + BBhi;
%
%[BBhi, RR] = readgeoraster('soc_15-30cm_mean_1000_latlon.tif');
%%BBhi(BBhi < 0) = NaN;
%BBhi(BBhi < 0) = 0;
%AAhi = AAhi + BBhi;
%
%[BBhi, RR] = readgeoraster('soc_30-60cm_mean_1000_latlon.tif');
%%BBhi(BBhi < 0) = NaN;
%BBhi(BBhi < 0) = 0;
%AAhi = AAhi + BBhi;
%
%[BBhi, RR] = readgeoraster('soc_60-100cm_mean_1000_latlon.tif');
%%BBhi(BBhi < 0) = NaN;
%BBhi(BBhi < 0) = 0;
%AAhi = AAhi + BBhi;
%
%%%% Read spatial data (could read constants from .hdr file)
%
%AA3 = [];
%for jj = 1:NDOWN
%    for ii = 1:NDOWN
%        AA3 = cat(3, AA3, AAhi(ii:NDOWN:end,jj:NDOWN:end));
%    end
%end
%%clear AAhi;
%
%%AA = mode(AA3, 3);
%AA = nanmean(AA3, 3);
%
%dx = RR.CellExtentInLatitude*NDOWN;
%lat = [RR.LatitudeLimits( 1)+dx/2:dx:RR.LatitudeLimits( 2)-dx/2]';
%lon = [RR.LongitudeLimits(1)+dx/2:dx:RR.LongitudeLimits(2)-dx/2]';
%
%NLAT = numel(lat);
%NLON = numel(lon);
