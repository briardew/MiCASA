% bweir, fixme: month hack
month = step;
litterscalar = litterscalarmo(:,month);

% bweir, fixme: month hack
if year < startYear
    datasets = {'BAherb','BAwood','BAdefo','MORT','FP','PF','FPAR','PPT','AIRT','SOLRAD'};
    for ii = 1:length(datasets)
        eval([ datasets{ii} ' = ' datasets{ii} 'mo(:,month);'])
    end

else
    datasets = {'BAherb','BAwood','BAdefo','MORT','FP','PF'};
    data_dir = 'annual';
    for ii = 1:length(datasets)
        load([DIRCASA, '/', runname, '/', data_dir, '/', int2str(year), ...
            '/', datasets{ii}, '.mat'])
        eval([ datasets{ii} ' = mask12file(single(' datasets{ii} '),mask);'])
        % bweir, fixme: month hack
        eval([ datasets{ii} ' = ' datasets{ii} '(:,month);'])
    end

    %ai alt fpar
    datasets = {'FPAR'};
    if (use_alt_fpar == 'y'), data_dir = 'annual_alt_fpar'; else data_dir = 'annual'; end
    for ii = 1:length(datasets)
        load([DIRCASA, '/', runname, '/', data_dir, '/', int2str(year), ...
            '/', datasets{ii}, '.mat'])
        eval([ datasets{ii} ' = mask12file(single(' datasets{ii} '),mask);'])
        % bweir, fixme: month hack
        eval([ datasets{ii} ' = ' datasets{ii} '(:,month);'])
    end

    %ai
    %MERRa data can be used for these data sets
    datasets = {'PPT','AIRT','SOLRAD'};
    %if (use_merra == 'y'), data_dir = 'annual_merra'; else data_dir = 'annual'; end
    data_dir = 'annual';
    for ii = 1:length(datasets)
        load([DIRCASA, '/', runname, '/', data_dir, '/', int2str(year), ...
            '/', datasets{ii}, '.mat'])
        eval([ datasets{ii} ' = mask12file(single(' datasets{ii} '),mask);'])
        % bweir, fixme: month hack
        eval([ datasets{ii} ' = ' datasets{ii} '(:,month);'])
    end
end
