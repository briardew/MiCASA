warning off% MATLAB:divideByZero
fuelwooddemand      = (1./FTC) .* POPDENS .* FUELNEED / NSTEPS;        
% population density * fuel need per capita per step (no seasonality)
% the 1 / tree is inserted to compensate for surrounding grassland and
% bare soil that do not generate CWD
fuelwooddemand(isnan(fuelwooddemand) | isinf(fuelwooddemand))=0;        

