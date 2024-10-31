% Calculate Potential Evapotranspiration (PET) and the Annual Heat Index
% (AHI)
YVAL = single(1.514);

% calculate Annual Heat Index, used for Thorntwaite's PET. See page 403 of
% 'Quantitative hydrogeology' by Ghislain De Marsily
if year == spinUpYear1
    io = 0 < AIRT;
    AHI(io) = AHI(io) + (AIRT(io)/5).^YVAL;
end

% Calculates PET from air temperature, Flambda, and the Annual Heat Index.
% Taken from Quantitative hydrogeology by Ghislain De Marsily, p 403 - 

exponent =  6.75E-7.* AHI.^3 - ...
            7.71E-5.* AHI.^2 + ...
            1.79E-2.* AHI    + ...
            0.49239;

% This equation predicts from the month of the year and the latitude 
% what flambda should be. The coefficients above are from a cubic spline 
% of data, see p 404 of Quantitave Hydrogeology
% month_ is set in updateCASAinput
Flambda = coef(month_,1) + ...
         (coef(month_,2) .* latitude)    + ...
         (coef(month_,3) .* latitude.^2) + ...
         (coef(month_,4) .* latitude.^3);

PET = zeros(size(AIRT));
io  = 0 < AIRT & 0 < AHI;
PET(io) = 16 * Flambda(io) .* (10 * AIRT(io)./AHI(io)).^exponent(io);

clear Flambda exponent
