datasets = {'FPAR', 'BAdefo', 'BAherb', 'BAwood', 'AIRT', 'PPT', 'SOLRAD'};

syear = datestr(dnum, 'yyyy');
smon  = datestr(dnum, 'mm');
sday  = datestr(dnum, 'dd');

fin = [DIRCASA, '/', runname, '/climate/spinup_inputs.x', num2str(NLON), ...
    '_y', num2str(NLAT), '.monthly.', num2str(startYear), '-', ...
    num2str(endYear), smon, '.nc'];

for ii = 1:length(datasets)
  eval([datasets{ii}, ' = ncread(fin, ', datasets{ii}, ';']);
end

% Will need to reproduce all the other variables in maps and averaging in
% loadCASAinput
