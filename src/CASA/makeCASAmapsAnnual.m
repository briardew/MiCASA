defineConstants;

% Compute monthly values of daily input data
% ---
datasets = {'FPAR', 'BAherb', 'BAwood', 'BAdefo', 'AIRT', 'PPT', 'SOLRAD'};
% Double cast needed for datenum :(
for year = double(startYear):double(endYear)
    for ii = 1:length(datasets)
        eval([datasets{ii}, 'mo = zeros(NLAT, NLON, 12);']);
    end

    for month = 1:12
        tic;
        ntot = 0;
        for dnum = datenum(year,month,01):datenum(year,month+1,01)-1
            loadCASAdaily

            % Increment monthly total
            ntot = ntot + 1;
            for ii = 1:length(datasets)
                dd = [datasets{ii}, 'mo(:,:,month)'];
                eval([dd, ' = ', dd, ' + ', datasets{ii}, ';']);
            end
        end

        for ii = 1:length(datasets)
            dname = datasets{ii};

            % Some datasets are totals and should only be summed
            if (   strcmp(dname, 'BAherb') || strcmp(dname, 'BAwood') ...
                || strcmp(dname, 'BAdefo') || strcmp(dname, 'PPT'))
                continue;
            end

            % Otherwise average
            dd = [dname, 'mo(:,:,month)'];
            eval([dd, ' = ', dd, '/ntot;']);
        end

        disp([int2str(year), '/', num2str(month,'%02u'), ', time used = ', ...
            int2str(toc), ' seconds']);
    end

    for ii = 1:length(datasets)
        dd = datasets{ii};

        % Check if file exists; skip if not reprocessing
        dout = [DIRCASA, '/', runname, '/maps/annual/', int2str(year)];
        fout = [dout, '/', dd, '.mat'];
        if isfile(fout) && ~REPRO, continue; end

        if ~isfolder(dout)
            [status, result] = system(['mkdir -p ', dout]);
        end

        eval([dd, ' = ', dd, 'mo;']);
        eval(['clear ',  dd, 'mo;']);
        save(fout, dd, '-v7');
    end
end
