% calculate latitude, latitude matrix is used
% in the calculation of PET
[x,y] = size(mask);
latitude=zeros(x,y);
startLatitude = 90 - (180/x) / 2;
for i=1:x,
    latitude(i,:) = startLatitude;
    startLatitude = startLatitude - 180/x;
end
% all latitudes further north than 50N become 50, all latitudes further
% south than 50S become -50
for i=1:x,
    if latitude(i,1) > 50,
        latitude(i,1:y) = 50;
    elseif latitude(i,1) < -50,
        latitude(i,1:y) = -50;
    end
end        
latitude = maskfile(latitude,mask);
clear startLatitude x y
