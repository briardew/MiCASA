% Write summary files for analysis
if year < startYear, return; end

DIRNAT = [DIRRUN, '/native'];				% Native CASA output dir
if ~isfolder(DIRNAT)
    [status, result] = system(['mkdir -p ', DIRNAT]);
end

syear = int2str(year);
datasets = {fluxes{:}, 'COMdefo', 'COMpeat', 'soilm', 'EET', 'AGBD', ...
    'NPPwood', 'NPPherb', 'NPPdefo', 'RESwood', 'RESherb', 'RESdefo',  ...
%   'NPPmoist', 'NPPtemp', 'bgmoist', ...
};

for ii = 1:length(datasets)
    if NSTEPS == 12
        dd = [datasets{ii}, syear];

        % First create an empty array, then concatenate every step
        if step == 1, eval([dd, ' = [];']); end
        eval([dd, ' = cat(2, ', dd, ', ', datasets{ii}, ');']);

        dout = DIRNAT;
        if ~isfolder(dout)
            [status, result] = system(['mkdir -p ', dout]);
        end

        if step == 12
            fout = [dout, '/', dd, '.mat'];
            if ~isfile(fout) || FORCE
                save(fout, dd, '-v7');
            end
            eval(['clear ', dd]);
        end
    else
        dd =  datasets{ii};

        % Note that the slashes in datestr give subdirs
        dout = [DIRNAT, '/', datestr(dnum, 'yyyy/mm/dd')];

        if ~isfolder(dout)
            [status, result] = system(['mkdir -p ', dout]);
        end

        fout = [dout, '/', dd, '.mat'];
        if ~isfile(fout) || FORCE
            save(fout, dd, '-v7');
        end
    end
end
