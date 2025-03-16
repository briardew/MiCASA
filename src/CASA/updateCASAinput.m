% * Needs year, NSTEPS, & step defined
% * month_ and molen_ are global variables added for running daily
% and monthly
if NSTEPS == 12
    month_ = step;
    molen_ = 1;			% Number of steps a month is

    datasets = {'BAherb', 'BAwood', 'BAdefo', 'FPAR', 'PPT', 'AIRT', ...
        'SOLRAD', 'MORT', 'FP', 'PF'};
    for ii = 1:length(datasets)
        dname = datasets{ii};
        if year < startYear
            eval([dname ' = ' dname 'mo(:,month_);'])
        else
            load([DIRCASA, '/', runname, '/maps/annual/', int2str(year), ...
                '/', dname, '.mat'])
            eval([dname ' = ' dname '(:,:,month_);'])
            eval([dname ' = maskfile(single(' dname '),mask);'])
        end
    end
else
    dnum = datenum(year, 01, 01) + step - 1;
    dvec = datevec(dnum);
    month_ = dvec(2);
    molen_ = datenum(year, month_+1, 1) - datenum(year, month_, 1);

    % Needs dnum defined above
    loadCASAdaily

    % Daily data sets (monthly for spin-up)
    datasets = {'BAherb', 'BAwood', 'BAdefo', 'FPAR', 'PPT', 'AIRT', ...
        'SOLRAD'};
    for ii = 1:length(datasets)
        dname = datasets{ii};
        if year < startYear
            eval([dname ' = ' dname 'mo(:,month_);'])
        else
            eval([dname ' = maskfile(single(' dname '),mask);'])
        end
    end

    % Data sets treated only as monthly climatologies
    % *** FIXME: Should be created by monthly spinup ***
    datasets = {'MORT', 'FP', 'PF'};
    for ii = 1:length(datasets)
        dname = datasets{ii};
        if year < startYear
            eval([dname ' = ' dname 'mo(:,month_);'])
        else
            load([DIRCASA, '/', runname, '/maps/climate/', dname, '.mat'])
            eval([dname ' = ' dname '(:,:,month_);'])
            eval([dname ' = maskfile(single(' dname '),mask);'])
        end
    end
end

litterscalar = litterscalarmo(:,month_);
