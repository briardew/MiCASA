% Write summary files for analysis
if year < startYear, return; end

syear = int2str(year);
datasets = {fluxes{:}, 'COMdefo', 'COMpeat', 'NPPmoist', 'NPPtemp', ...
    'bgmoist', 'soilm', 'EET'};

for ii = 1:length(datasets)
    if NSTEPS == 12
        dd = [datasets{ii}, syear];

        % First create an empty array, then concatenate every step
        if step == 1, eval([dd, ' = [];']); end
        eval([dd, ' = cat(3, ', dd, ', ', datasets{ii}, ');']);

        if step == 12
            dout = [DIRCASA, '/', runname, '/native'];

            if ~isfolder(dout)
                [status, result] = system(['mkdir -p ', dout]);
            end

            fout = [dout, '/', dd, '.mat'];
            if ~isfile(fout) || lower(do_reprocess(1)) == 'y'
                save(fout, dd, '-v7');
            end
            eval(['clear ', dd]);
        end
    else
        dd =  datasets{ii};

        sday = datestr(dnum, 'yyyy/mm/dd');
        dout = [DIRCASA, '/', runname, '/native/', sday];

        if ~isfolder(dout)
            [status, result] = system(['mkdir -p ', dout]);
        end

        fout = [dout, '/', dd, '.mat'];
        if ~isfile(fout) || lower(do_reprocess(1)) == 'y'
            save(fout, dd, '-v7');
        end
    end
end
