% Define the scalars that predict the seasonality of leaf shedding
% and root decay, based on changes in FPAR. Basically, leaf and root decay
% are faster when FPAR drops and the turnover time is thus given seasonality
% by giving it a monthly weight based on the FPAR seasonality

if year == spinUpYear
    % bweir, fixme: month hack
    FPARdiff = diff([FPARmo(:,12) FPARmo],[],2);
else
    % bweir, fixme: month hack
    FPARdiff = diff([FPARpm FPARmo],[],2);
end

warning off     % some gridcells have no changes in FPAR so will divide by zero

FPARdiff(FPARdiff > 0) = 0;
for month = 1:12
    litterscalar(:,month) = abs(FPARdiff(:,month) ./ sum(FPARdiff,2));
end
litterscalar(isnan(litterscalar)) = 1/12;
% bweir, fixme: month hack
FPARpm = FPARmo(:,12);  % set December FPAR for next years calculation
litterscalar = litterscalar .* 6;
litterscalar(litterscalar > 1) = 1;
warning on

% bweir, fixme: month hack
litterscalarmo = litterscalar;
clear litterscalar
