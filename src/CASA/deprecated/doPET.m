% Calculate Potential Evapotranspiration (PET) and the Annual Heat Index
% (AHI)
YVAL = single(1.514);

% calculate Annual Heat Index, used for Thorntwaite's PET. See page 403 of
% 'Quantitative hydrogeology' by Ghislain De Marsily
if year == spinUpYear
    fid = AIRT;
    io  = fid > 0;
    AHI(io) = AHI(io) + (fid(io) ./ 5) .^ YVAL;
end


% Calculates PET from air temperature, Flambda, and the Annual Heat Index.
% Taken from Quantitative hydrogeology by Ghislain De Marsily, p 403 - 

exponent =  6.75E-7.* (AHI.^3) - ...
            7.71E-5.* (AHI.^2) + ...
            1.79E-2.*  AHI     + ...
            0.49239;

% bweir, fixme: month hack
month = step;

% This equation predicts from the month of the year and the latitude 
% what flambda should be. The coefficients above are from a cubic spline 
% of data, see p 404 of Quantitave Hydrogeology
Flambda = coef(month,1) + ...
         (coef(month,2) .* latitude) + ...
         (coef(month,3) .* (latitude.^2)) + ...
         (coef(month,4) .* (latitude.^3));
warning off MATLAB:divideByZero     
fid = 16.0 .* Flambda .* (10 .* AIRT ./ AHI) .^ exponent;
fid(AIRT <= 0 | AHI <= 0) = 0;
PET=fid;

clear Flambda exponent
