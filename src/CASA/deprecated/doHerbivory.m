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

% bweir, fixme: month hack
% this one seems like an honest bug
grass_herbivory = 0.028 .* (35.5 .* sum(NPPmo,2) .* leafallo).^2.04 * 10.^-4.80;
trees_herbivory = 0.028 .* (35.5 .* sum(NPPmo,2) .* 0.3     ).^2.04 * 10.^-4.80;

% Seasonality in herbivory is calculated as in Randerson et al. (GBC, 1996)
% scaling linearly with NPP (66%) with a nonzero intercept (33%)
% representing a minimum consumption limit outside the growing season

warning off

% bweir, fixme: month hack
fid = 2/3 .* (NPP ./ sum(NPPmo,2)) + 1/3 .* 1/12;
fid(sum(NPPmo,2)==0) = 1/12;          % in case of zero NPP all steps get
herb_seasonality = fid;               % equal seasonality (although there 
                                      % is no herbivory anyway)
warning on
