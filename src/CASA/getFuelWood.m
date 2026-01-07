% population density * fuel need per capita per step (no seasonality)
% the 1 / tree is inserted to compensate for surrounding grassland and
% bare soil that do not generate CWD
fuelwooddemand = zeros(size(FTC));
io = 0 < FTC;
% CF: Here and NPP divided by FHC + FTC + FDC in doNPP vs.
% SINK, ORGC_top, and ORGC_sub not being divided in makeCASAmapsClim
fuelwooddemand(io) = (1./FTC(io)) .* POPDENS(io) .* FUELNEED(io) / NSTEPS;        
