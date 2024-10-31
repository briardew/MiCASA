% defines the optimum temperature; this is the air temperature in the
% month when FPAR is highest.

for month = 1:12
%   bweir, fixme: month hack
    fid = FPARmo(:,month);
    io = fid >= maxFPAR;
    maxFPAR(io) = fid(io);
%   bweir, fixme: month hack
    fid = AIRTmo(:,month);
    topt(io)   = fid(io);
end
topt(topt<0) = 0;
dump = max(AIRT,2);
topt(isnan(topt)) = dump(isnan(topt));
