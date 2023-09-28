% needs year, NSTEPS, & step defined
if NSTEPS == 12
    month = step;
    litterscalar = litterscalarmo(:,month);

    datasets = {'BAherb', 'BAwood', 'BAdefo', 'FPAR', 'PPT', 'AIRT', ...
        'SOLRAD', 'MORT', 'FP', 'PF'};

    if year < startYear
        for ii = 1:length(datasets)
            eval([ datasets{ii} ' = ' datasets{ii} 'mo(:,month);'])
        end
    else
        for ii = 1:length(datasets)
            load([DIRCASA, '/', runname, '/annual/', int2str(year), ...
                '/', datasets{ii}, '.mat'])
            eval([ datasets{ii} ' = mask12file(single(' datasets{ii} '),mask);'])
            % bweir, fixme: month hack
            eval([ datasets{ii} ' = ' datasets{ii} '(:,month);'])
        end
    end
else
    dnum = datenum(year, 01, 01) + step - 1;
    dvec = datevec(dnum);
    month = dvec(2);
    litterscalar = litterscalarmo(:,month);

    % needs dnum defined above
    loadDailyInput
end
