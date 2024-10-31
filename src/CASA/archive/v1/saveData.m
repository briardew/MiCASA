% Write summary files for analysis
if year < startYear, return; end

syear = int2str(year);
datasets = {fluxes{:}, 'COMdefo', 'COMpeat', 'NPPmoist', 'NPPtemp', ...
    'bgmoist', 'soilm', 'EET'};

for ii = 1:length(datasets)
    dd  =  datasets{ii};
    dyr = [datasets{ii}, syear];

    if NSTEPS == 12
        if step == 1, eval([dyr, ' = [];']); end
        eval([dyr, ' = cat(3, ', dyr, ', ', dd, ');']);

        if step == 12
            dout = [DIRCASA, '/', runname, '/native'];

            if ~isfolder(dout)
                [status, result] = system(['mkdir -p ', dout]);
            end

            save([dout, '/', dyr, '.mat'], dyr, '-v7');
            eval(['clear ', dyr])
        end
    else
        sday = datestr(dnum, 'yyyy/mm/dd');
        dout = [DIRCASA, '/', runname, '/native/', sday];

        if ~isfolder(dout)
            [status, result] = system(['mkdir -p ', dout]);
        end

        save([dout, '/', dd, '.mat'], dd, '-v7');
    end
end
