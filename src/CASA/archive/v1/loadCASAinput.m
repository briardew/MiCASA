% Loads input files. For global studies, these files should be given as,
% i.e. 180 by 360 matrix (for 1 by 1 degree resolution). Half degree would
% be 360 by 720 etc. This routine will construct a 'mask' with vegetated
% gridcells and will reshape them into a X by 1 matrix, where X is the
% total number of vegetated gridcells.
% The files which contain monthly varying parameters (i.e., precipitation)
% should be given as (for 1 by 1 degree:) 180 by 360 by 12, and will be
% reshaped to a X by 12 matrix, one column for each month.

datasets = {'FTC', 'FHC', 'FBC', 'VEG', 'POPDENS', 'FUELNEED', ...
    'ORGC_top', 'ORGC_sub', 'basisregions'};
if lower(do_deprecated(1)) == 'y'
    datasets = {datasets{:}, 'SOILTEXT', 'land_percent'};
end
for ii = 1:length(datasets)
    load([DIRCASA, '/', runname, '/maps/', datasets{ii}, '.mat']);
end

% In older versions, these were zero
if lower(do_deprecated(1)) == 'y'
    sand = zeros(NLAT, NLON, 'single');
    silt = zeros(NLAT, NLON, 'single');
    clay = zeros(NLAT, NLON, 'single');
else
    datasets = {'sand', 'silt', 'clay'};
    for ii = 1:length(datasets)
        load([DIRCASA, '/', runname, '/maps/', datasets{ii}, '.mat']);
    end
end

% Fraction deforested and regrowing cover are zero when started
FDC = zeros(NLAT, NLON, 'single');
FRC = zeros(NLAT, NLON, 'single');

% Data for spin-up
datasets = {'BAherb', 'BAwood', 'BAdefo', 'FP', 'PF', 'MORT', 'FPAR', ...
    'PPT', 'AIRT', 'SOLRAD'};
data_dir = 'annual';
for ii = 1:length(datasets)
    average = zeros(NLAT, NLON, 12);
    for year = startYearClim:endYearClim
        load([DIRCASA, '/', runname, '/', data_dir, '/', int2str(year), '/', ...
            datasets{ii}, '.mat']);
        eval(['average = average + ' datasets{ii} ';']);
    end
    eval([datasets{ii} ' = single(average./(endYearClim - startYearClim + 1));']);
end

PF = PF .* 0;
disp('!!!!!!!!! peat fraction set to zero for spin up!!!!!!!!!!!')

% make mask with only vegetated data
%mask = zeros(NLAT,NLON,'single');
%mask = single(sum(FPAR,3) > 0);
%mask = single(VEG>0);
% mask(basisregions~=13)=0;
%ai 

if lower(do_deprecated(1)) == 'y'
    mask = single(land_percent > 0);
else
    mask = single(FTC + FHC > 0);
end

% mask(156,355) = 1;      % Burkina Faso (Savadogo paper)
% mask(207,625) = 1;      % NT, Russell-Smith
% mask(209,625) = 1;      % NT, http://www.savanna.org.au/all/fuel.html
% mask(227,661) = 1;      % http://www.savanna.org.au/all/fuel.html
% mask(211,407) = 1;      % Hely et al., 2003
% mask(185,429) = 1;      % Mcnaughton
% mask(207,625) = 1;      % Kapalga experiment13?02?11?S 132?26?23?E
% mask(231,423) = 1;      % KNP (Shea et al., 1996)
% mask(205,421) = 1;      % Shea et al (Zambia)
% mask(159,403) = 1;      % Africa Savanna with high fire activity
% mask(198,259) = 1;      % Mato Grosso with high deforestation rates
% mask(187,590) = 1;      % Indo peat fires (S-Borneo)
% mask(42,56) = 1;         % Taiga
% mask(50,56) = 1;         % Taiga
% mask(VEG>0) = 1;
% mask(sum(FPAR,3)==0)=0;   % don't take ice / desert into account
% mask(basisregions~=13)=0;
% mask(sum(BAdefo,3)==0)=0;

numberOfGridCells = sum(mask(:));
gridArea = makeGridArea(NLAT, NLON);

% Mask and reshape datasets
datasets = {'AIRT', 'FPAR', 'PPT', 'BAherb', 'BAwood', 'BAdefo', 'FP', 'PF', ...
    'MORT', 'FTC', 'VEG', 'SOLRAD', 'POPDENS', 'FUELNEED', ...
    'ORGC_top', 'ORGC_sub', 'FDC', 'FHC', 'FBC', 'FRC', 'gridArea', ...
    'basisregions', 'sand', 'silt', 'clay'};
if lower(do_deprecated(1)) == 'y'
    datasets = {datasets{:}, 'SOILTEXT', 'land_percent'};
end

for ii = 1:length(datasets)
    eval(['dump = size(' datasets{ii} ');'])
    if length(dump) == 2
        eval([ datasets{ii} ' = single(maskfile(' datasets{ii} ',mask));'])
    else
        eval([ datasets{ii} ' = single(mask12file(' datasets{ii} ',mask));'])
    end
end

%% add bug fix 3/24/2011
% bug fix: FTC + FHC + FBC exceed 1 because FHC was not lowered when FTC
% was added moving backwards in time to simulate FTC in areas that were
% deforested during the study period but outside the humid tropical forest

total_fraction = FTC + FHC + FBC + FDC;
error_fraction = total_fraction > 1;                   
FHC = FHC - (error_fraction .* (total_fraction - 1));
% In some grid cells FHC is negative, subtract from FBC
error_fraction = zeros(size(total_fraction));
error_fraction(FHC < 0) = FHC(FHC < 0);
FBC = FBC + error_fraction;
FBC(FBC < 0) = 0;			% to prevent it being -0.000001...
FHC = FHC - error_fraction;

%ai
%load the spatially dependent EMAX which replaces the constant version
load([DIRCASA, '/', runname, '/maps/EMAX.mat']);
EMAX = single(maskfile(EMAX,mask));

%load sink data
if lower(use_sink(1)) == 'y'
    load([DIRCASA, '/', runname, '/maps/SINK.mat']);
    SINK = single(maskfile(SINK,mask));
end

%load crop moisture data
if lower(use_crop_moisture(1)) == 'y' || lower(use_crop_ppt_ratio(1)) == 'y'
    load([DIRCASA, '/', runname, '/maps/crop_states.mat']);
    crop_states = single(maskfile(crop_states,mask));
    %get list of indices for crop states
    %crop states have a flag value > 10
    crop_states_index = find(crop_states > 10);
end

% spinup without deforestation
BAdefo = BAdefo .* 0;

% average burned area over fraction tree cover bins and basisregions for
% spin up
BAtemp = zeros(size(BAwood));
for region = 1:14
    for FTCbin = 1:10
        io = basisregions==region & FTC >= (FTCbin-1)/10 & FTC < FTCbin/10;
        for month = 1:12
            dump = BAwood(:,month);
            if sum(dump(io))>0
                ba = mean(dump(io));
            else
                ba = 0;
            end
            dump = BAtemp(:,month);
            dump(io) = ba;
            BAtemp(:,month) = dump;
        end
    end
end
BAwood = BAtemp;
clear BAtemp

% make mean annual precipitation scalar for NPP allocation
MAP = sum(PPT, 2);
MAP = MAP ./ 3000;
MAP(MAP > 1) = 1;

% make mean annual temperature map for fire-induced mortality decision
MAT = mean(AIRT, 2);

% make approximate taiga and tundra map where organic soil burns
taigatundra = single(mean(AIRT,2)<0 & sum(PPT,2)>100);

% make maps where C4 vegetation may occur based on temperature and
% precipiation data, see Collatz et al., 1998, Oecologia
C4 = single(sum(AIRT>22 & PPT>25,2)>0);

FTC(isnan(FTC)) = 0;
FHC(isnan(FHC)) = 0;

disp(['Calculating fluxes for ' int2str(sum(mask(:))) ' grid cells'])

% bweir: month hack
if do_spinup_stage1 == 'y'
    datasets = {'BAherb', 'BAwood', 'BAdefo', 'MORT', 'FP', 'PF', 'FPAR', ...
        'PPT', 'AIRT', 'SOLRAD'};
    for ii = 1:length(datasets)
        eval([ datasets{ii} 'mo = ' datasets{ii} ';'])
        eval([ datasets{ii} ' = ' datasets{ii} 'mo(:,1);'])
    end
end
