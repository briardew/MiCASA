%MAKE_SINK_PREP1  Compute growth rates for atmospheric correction to MiCASA

% Author(s):	Brad Weir <brad.weir@nasa.gov>
%
% Changelog:
% 2024-05-16	Initial version
%===============================================================================

lofi.setup;

% Read Global Carbon Budget
% ---
fname = ['+lofi/data/co2_gcb__', GCBTAG, '.csv'];
fid   = fopen(fname);
disp(['Reading ', fname, ' ...']);
data = textscan(fid, '%d %f %f %f %f %f %f %f', 'headerlines', 1, ...
    'delimiter', ',');
fclose(fid);

yeargcb = double(data{1});			% Convert to double for datenum
fluxgcb = data{4};
fuelgcb = data{2};				% Conflicts with conventions elsewhere where this is anth (***FIXME***)
biofgcb = data{3};				% Really not biofuel
anthgcb = data{2} + data{3};
ocngcb  = data{5};
landgcb = data{6};
cmtgcb  = data{7};
imbgcb  = data{8};

yy = landgcb - biofgcb + RIVER;
inds = find(~isnan(yy));
xo = yeargcb(inds);
yo = yy(inds);

a0 = [0; 15; 1980; 40];

fsink = @(aa,xx) aa(1)/100 + aa(2)./(1 + exp((aa(3) - xx)/aa(4)));
[ao, rr] = lsqcurvefit(fsink, a0, xo, yo);

ao = round(ao, 0);
zz = fsink(ao,xo);
