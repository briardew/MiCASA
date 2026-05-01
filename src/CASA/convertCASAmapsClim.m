defineConstants;

% DIRMAPS is also the read directory, so it needs to exist
fout = [DIRMAPS, '/MiCASA_v', VERSION, '_maps_', CASARES, '_climate.nc4'];

% Datasets to convert
% Could be fancy here and also create a data structure of attributes
% like units and long names
datasets = {'basisregions', 'FUELNEED', 'FP', 'MORT', 'PF', ...
    'POPDENS', 'VEG', 'FTC', 'FHC', 'FBC', 'EMAX', 'SINK', ...
    'ORGC_top', 'ORGC_sub', 'sand', 'silt', 'clay'};

% Output file settings
% ---
% Shouldn't this be in defineConstants?
FEXT    = 'nc4';
FORMAT  = 'netcdf4';
DEFLATE = 9;
SHUFFLE = true;

if isfile(fout)
    if lower(do_reprocess(1)) == 'y'
        [status, result] = system(['rm ', fout]);
    else
        disp(['File ', fout, ' exists and not reprocessing']);
        return;
    end
end

% Support lon-lat and lon-lat-month
NREC = 12;
time = [1:NREC]';

% Create file and dimensions
nccreate(fout,   'lat', 'dimensions',{'lat',NLAT}, ...
    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
ncwriteatt(fout, 'lat', 'units','degrees_north');
ncwriteatt(fout, 'lat', 'long_name','latitude');
ncwrite(fout,    'lat', lat);

nccreate(fout,   'lon', 'dimensions',{'lon',NLON}, ...
    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
ncwriteatt(fout, 'lon', 'units','degrees_east');
ncwriteatt(fout, 'lon', 'long_name','longitude');
ncwrite(fout,    'lon', lon);

nccreate(fout,   'time', 'dimensions',{'time',NREC}, ...
    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
ncwriteatt(fout, 'time', 'long_name','time');
ncwriteatt(fout, 'time', 'units','month');
ncwriteatt(fout, 'time', 'bounds','time_bnds');
ncwrite(fout,    'time', time);

nccreate(fout,   'time_bnds', ...
    'dimensions', {'nv',2, 'time',NREC}, ...
    'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
ncwriteatt(fout, 'time_bnds', 'long_name','time bounds');
ncwriteatt(fout, 'time_bnds', 'units','month');
ncwrite(fout,    'time_bnds', [time, mod(time,NREC)+1]');

for ii = 1:length(datasets)
    dname = datasets{ii};

    fin = [DIRMAPS, '/climate/', dname, '.mat'];
    vin = load(fin).(dname);

    % Supports lon-lat and lon-lat-month
    if size(vin, 3) == 1
        nccreate(fout,   dname, 'datatype','double', ...
            'dimensions',{'lon',NLON, 'lat',NLAT}, ...
            'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
        ncwriteatt(fout, dname, 'long_name',dname);
        % Recall flipud(A)' goes from CASA to output
        ncwrite(fout,    dname, flipud(vin)');
    else
        if size(vin, 3) ~= NREC
            disp(['Output file has a time dimension of ' NREC, ', but']);
            disp(['size(', dname, ') = ', size(vin)]);
            error('Incompatible input/output files ...');
        end

        vout = zeros(NLON, NLAT, NREC);

        for nn = 1:NREC
            % Recall flipud(A)' goes from CASA to output
            vout(:,:,nn) = flipud(vin(:,:,nn))';
        end

        nccreate(fout,   dname, 'datatype','double', ...
            'dimensions',{'lon',NLON, 'lat',NLAT, 'time',NREC}, ...
            'format',FORMAT, 'deflate',DEFLATE, 'shuffle',SHUFFLE);
        ncwriteatt(fout, dname, 'long_name',dname);
        ncwrite(fout,    dname, vout);
    end
end
