function [maskedfile] = maskfile(filetomask,mask)

% maskfile makes from a lat - lon worldmap a one column data file
% with only landpixels.
%
% in: maskfile(the file to mask, mask);
% out: the maskedfile (one column)

% CASA library, Guido van der Werf 2003
% guido@ltpmailx.gsfc.nasa.gov

% maskedfile = filetomask(mask==1);

% old
[x,y]=size(mask);
maskedfile=zeros(sum(mask(:)),1);

i=1;

for lat=1:x,
   for lon=1:y,
      if mask(lat,lon)==1,
         maskedfile(i,1)=filetomask(lat,lon);
         i=i+1;
      end
   end
end