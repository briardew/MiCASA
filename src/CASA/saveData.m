syear = int2str(year);
datasets = {fluxes{:}, 'COMdefo', 'COMpeat', 'NPPmoist', 'NPPtemp', ...
    'bgmoist', 'soilm', 'EET'};

if NSTEPS == 12
%    if year >= spinUpYear_2
%        for ii = 1:nflux
%            dd = [fluxes{ii}, syear];
%           eval(['temp_flux = ', dd, ';'])
%           temp_flux_globalannual = sum(sum(temp_flux,2) .* gridArea) / 1e15;
%           eval([fluxname, '_timeseries = [', fluxname, ...
%               '_timeseries, temp_flux_globalannual];'])
%           clear temp_flux temp_flux_globalannual
%
%            eval(['clear ', dd])
%        end
%    end
    if year >= startYear
        for ii = 1:length(datasets)
            dd = [datasets{ii}, syear];
            ff = [DIRCASA, '/', runname, '/native/', dd, '.mat'];

            % bweir: month hack
            if month > 1
                load(ff);
            else
                eval([dd, ' = [];']);
            end
            eval([dd, ' = cat(3, ', dd, ', dd);']);

            save(ff, dd, '-v7');
            eval(['clear ', dd])
        end
    end

else
    dstr = datestr(dnum, 'yyyymmdd');

    % Write summary files for analysis
    if year >= startYear
        for ii = 1:length(datasets)
            dd = datasets{ii};
            save([DIRCASA, '/', runname, '/native/', fluxname, ...
                dstr, '.mat'], fluxname, '-v7');
        end
    end
end
