% Create the crop_states, EMAX, and SINK input arrays
%
% Oct 2010 Al Ivanoff		Initial version
% Sep 2023 Brad Weir		Now creates crop_states on its own
%				Upgraded to 0.1 degree
%
% TODO:
% * Move to CASA source
% * Add regrid
% * Add all states and annual variability

ff = 'gadm28_adm1_1800x3600.nc';

lat = double(ncread(ff, 'latitude'));
lon = double(ncread(ff, 'longitude'));
mask = ncread(ff, 'division_mask');

w_southdakota = find(mask == 24442);
w_nebraska    = find(mask == 24428);
w_kansas      = find(mask == 24417);
w_minnesota   = find(mask == 24424);
w_iowa        = find(mask == 24416);
w_missouri    = find(mask == 24426);
w_wisconsin   = find(mask == 24450);
w_illinois    = find(mask == 24414);
w_indiana     = find(mask == 24415);
w_ohio        = find(mask == 24436);

crop_states = ones(size(mask));
crop_states(mask == -255)  =  0;
crop_states(w_southdakota) = 11;
crop_states(w_nebraska)    = 12;
crop_states(w_kansas)      = 13;
crop_states(w_minnesota)   = 14;
crop_states(w_iowa)        = 15;
crop_states(w_missouri)    = 16;
crop_states(w_wisconsin)   = 17;
crop_states(w_illinois)    = 18;
crop_states(w_indiana)     = 19;
crop_states(w_ohio)        = 20;

EMAX = 0.55 * ones(size(mask));
EMAX(w_southdakota) = 0.65;
EMAX(w_nebraska)    = 0.71;
EMAX(w_kansas)      = 0.61;
EMAX(w_minnesota)   = 0.68;
EMAX(w_iowa)        = 0.89;
EMAX(w_missouri)    = 0.62;
EMAX(w_wisconsin)   = 0.64;
EMAX(w_illinois)    = 0.86;
EMAX(w_indiana)     = 0.78;
EMAX(w_ohio)        = 0.67;

SINK = zeros(size(mask));
SINK(w_southdakota) = 39;
SINK(w_nebraska)    = 94;
SINK(w_kansas)      = 24;
SINK(w_minnesota)   = 75;
SINK(w_iowa)        = 227;
SINK(w_missouri)    = 38;
SINK(w_wisconsin)   = 40;
SINK(w_illinois)    = 211;
SINK(w_indiana)     = 150;
SINK(w_ohio)        = 77;

ee = [0.65; 0.71; 0.61; 0.68; 0.89; 0.62; 0.64; 0.86; 0.78; 0.67] - 0.55;
ss = [  39;   94;   24;   75;  227;   38;   40;  211;  150;   77];

crop_states = flipud(crop_states');
EMAX = flipud(EMAX');
SINK = flipud(SINK');

save('crop_states.mat', 'crop_states', '-v7');
save('EMAX.mat', 'EMAX', '-v7');
save('SINK.mat', 'SINK', '-v7');
