% Defines the optimum temperature: the air temperature in the month when
% fPAR is highest (only run once at initialization)

for month = 1:12
    fid = FPARmo(:,month);	% bweir: month hack
    io = fid >= maxFPAR;
    maxFPAR(io) = fid(io);

    fid = AIRTmo(:,month);	% bweir: month hack
    topt(io) = fid(io);
end
topt(topt < 0) = 0;

% This seems like it does nothing? (***FIXME***)
dump = max(AIRTmo, 2);
topt(isnan(topt)) = dump(isnan(topt));
