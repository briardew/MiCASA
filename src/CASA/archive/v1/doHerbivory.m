% Calculate herbivory analog to McNaughton (Science, 1989): as fraction
% of foliage NPP: 
%
% log C = 2.04 (log NFP) - 4.80
% --> C = NFP^ 2.04 * 10^ -4.80
%
% where C = comsumption, and NFP = Net Foliage Prodcution (NPP delivered to
% leaves). Units are in kJ / m2 / yr. 
% 
% converting kJ m-2 yr to g C / m2 / yr:
%
% NPP(J / m2 / yr) = NPP (g C / m2 / yr) * energy content / carbon content
% where energy content = 1.6*10^4
% and   carbon content = 0.45
%
% so 1 g C / m2 / yr = 35.5 Kj / m2 / yr
% 1 / 35.5 = 0.028
io       = 1 - 0.85 + MAP; io(io<0.2)=0.2; io(io>0.8)=0.8;
leafallo = 1 - io;

% bweir: month hack
grass_herbivory = 0.028 .* (35.5 .* sum(NPPmo,2) .* leafallo).^2.04 * 10.^-4.80;
trees_herbivory = 0.028 .* (35.5 .* sum(NPPmo,2) .* 0.3     ).^2.04 * 10.^-4.80;

% Seasonality in herbivory is calculated as in Randerson et al. (GBC, 1996)
% scaling linearly with NPP (66%) with a nonzero intercept (33%)
% representing a minimum consumption limit outside the growing season

% bweir: month hack
% month_ is set in updateCASAinput
fid = sum(NPPmo, 2);
io  = 0 < fid;
fid(io) = 2/3*(NPPmo(io,month_)./fid(io))*12/NSTEPS + 1/3*1/NSTEPS;
fid(fid==0) = 1/NSTEPS;               % in case of zero NPP all steps get
herb_seasonality = fid;               % equal seasonality (although there 
                                      % is no herbivory anyway)
