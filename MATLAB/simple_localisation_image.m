%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Binned image creation for Single-Molecule Localisation Microscopy
%
% Generates a simple binned image from localisation microscopy data
%
% INPUT:
%   molecules data from impy (columns 2,3 are X,Y)
%
% OUTPUT:
%   uncorrected, binned image
%
% Lowe, A.R. 2014
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function [output_image] = simple_localisation_image(molecules)

% user parameters
bin_size = .3;              % fraction of a CCD pixel
CCD_size = 512.;            % CCD size
pixels_2_nm = 100.;         % conversion between CCD pixels and nm

output_image_size_x = ceil(max(molecules(:,2))/bin_size)+1;
output_image_size_y = ceil(max(molecules(:,3))/bin_size)+1;
output_image = uint16(zeros(output_image_size_x, output_image_size_y));

%%
% make the image
for i = 1:size(molecules,1)
    binx = floor((1.0/bin_size)*(molecules(i,2)-0.5*bin_size));
    biny = floor((1.0/bin_size)*(molecules(i,3)-0.5*bin_size));
    try
        output_image(binx,biny) = output_image(binx,biny) + 1; 
    catch err
        continue;
    end
end

%%
% display the image
figure
imagesc(output_image);
colormap(hot);
colorbar();
axis image;

%%
% TODO: add a scale bar

return