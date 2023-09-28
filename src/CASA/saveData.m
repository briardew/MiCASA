% bweir, fixme: month hack
if NSTEPS == 12 && step == 12
    % Write summary files for analysis
    if year >= spinUpYear_2
        for ii = 1:nflux
            fluxname = fluxes{ii};
            if year >= startYear
                save([DIRCASA, '/', runname, '/native/', fluxname, ...
                    int2str(year), '.mat'], [fluxname, int2str(year)], '-v7');
            end

            eval(['temp_flux = ', fluxname, int2str(year), ';'])
            temp_flux_globalannual = sum(sum(temp_flux,2) .* gridArea) / 1e15;
            eval([fluxname, '_timeseries = [', fluxname, ...
                '_timeseries, temp_flux_globalannual];'])
            clear temp_flux temp_flux_globalannual

            eval(['clear ', fluxname, int2str(year)])
        end
    end

    if year >= startYear
        % Computed in processData
        datasets = {'COMdefo', 'COMpeat'};
        for ii = 1:length(datasets)
            dd = datasets{ii};
            save([DIRCASA, '/', runname, '/native/', dd, int2str(year), '.mat'], ...
                [dd, int2str(year)], '-v7');
            eval(['clear ', dd, int2str(year)])
        end

        % Computed in components
        datasets = {'NPPmoist', 'NPPtemp', 'bgmoist', 'soilm', 'EET'};
        for ii = 1:length(datasets)
            dd = datasets{ii};
            eval([dd, int2str(year), ' = ', dd, ';']);
            save([DIRCASA, '/', runname, '/native/', dd, int2str(year), '.mat'], ...
                [dd, int2str(year)], '-v7');
            eval(['clear ', dd, int2str(year)])
        end
    end
end
