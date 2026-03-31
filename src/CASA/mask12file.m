function [result] = mask12file(file,mask);

% reads lat x lon maps, with 12 months and writes
% them as one column for each month

result=zeros(sum(sum(mask)),12);

for month=1:12
    result(:,month) = maskfile(file(:,:,month),mask);
end
