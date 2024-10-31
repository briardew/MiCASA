% Define the scalars that predict the seasonality of leaf shedding
% and root decay, based on changes in FPAR. Basically, leaf and root decay
% are faster when FPAR drops and the turnover time is thus given seasonality
% by giving it a monthly weight based on the FPAR seasonality

% Keep at spin-up values
if lower(do_deprecated(1)) ~= 'y' && year ~= spinUpYear1
    return;
end

% bweir: month hack
if year == spinUpYear1
    FPARdiff = diff([FPARmo(:,12) FPARmo], [], 2);
else
    FPARdiff = diff([FPARpm FPARmo], [], 2);
end
% Set December FPAR for next year's calculation (deprecated use only)
FPARpm = FPARmo(:,12);

FPARdiff(FPARdiff > 0) = 0;
fid = sum(FPARdiff, 2);
litterscalar = 1/12 * ones(size(FPARmo));
for month = 1:12
    io = fid < 0;
    litterscalar(io,month) = FPARdiff(io,month)./fid(io);
end

litterscalar = litterscalar .* 6;
litterscalar(litterscalar > 1) = 1;

% bweir: month hack
litterscalarmo = litterscalar;
clear litterscalar
