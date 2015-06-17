%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Translational drift correction for Single-Molecule Localisation 
% Microscopy, based on normalised cross-correlation and template matching
%
% Bins the localisation data into images and then calculates the normalised
% cross correlation between subsequent images in time.  The maximum 
% correlation corresponds to the drfit offset.  The image is transformed 
% using a simple affine transformation, and summed with the reference 
% image, such that the final output image is corrected for instrument drift
%
% INPUT:
%   molecules data from impy (columns 2,3 are X,Y)
%
% OUTPUT:
%   corrected, binned image
%   drift vector
%
% Lowe, A.R. 2014
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function [varargout] = drift_correct_normxcorr(molecules)

% user parameters
bin_size = .2;              % fraction of a CCD pixel
frames_per_stack = 1500;     % number of camera frames per intermediate image
max_drift = 10;              % maximum drift in (bin_size) pixels between frame stacks
CCD_size = 512.;            % CCD size

%%
% set up some initial parameters
output_image_size = ceil(CCD_size/bin_size);
[molecules] = molecules(molecules(:,4)<5.,:); % optional filtering
stack_size = 1+ceil(max(molecules(:,1))/frames_per_stack);
drift_vector = [];

% set up some space for the time stack
time_stack = uint16(zeros(output_image_size ,output_image_size, stack_size));

%%
% calculate the frames of the image stack
disp(sprintf('Calculating image stack (%d x %d, binsize: %2.2f, localisations: %d)...',output_image_size,output_image_size,bin_size,size(molecules,1)));
num_images_in_stack = 1;

for i = 1:stack_size
    [xy] = molecules(find(molecules(:,1)>=(i-1)*frames_per_stack & molecules(:,1)<=i*frames_per_stack),:);
    current_image = uint8(zeros(output_image_size, output_image_size ));
    for k = 1:length(xy)
        binx = floor((1.0/bin_size)*(xy(k,2)-0.5*bin_size));
        biny = floor((1.0/bin_size)*(xy(k,3)-0.5*bin_size));
        current_image(binx,biny) = current_image(binx,biny) + 1; 
    end
    time_stack(:,:,i) = current_image;
    num_images_in_stack=num_images_in_stack+1; 
end

%%
% get the first reference image
reference_image = time_stack(:,:,1);
output_image = double(reference_image);

% make a mask to restrict possible offsets
mask = double(zeros(output_image_size *2-1,output_image_size *2-1));
mask(output_image_size-max_drift:output_image_size+max_drift,output_image_size-max_drift:output_image_size+max_drift) = 1.0;

%%
% now do a normalised cross correlation for each of the later images in the
% time stack
for i = 2:num_images_in_stack-1

    % give the user a progress update
    disp(sprintf('Completed %d of %d stacks...',i,num_images_in_stack-1));
    
    compare_image = time_stack(:,:,i);
    % calculate teh normalised cross correlation, and mask it
    [c] = normxcorr2(reference_image, compare_image);
    c = (c.* mask);
    
    % now calculate the position of the maximum and the offset required
    [max_c, imax] = max(abs(c(:)));
    [ypeak, xpeak] = ind2sub(size(c),imax(1));
    corr_offset = [(xpeak-size(reference_image,2)), (ypeak-size(reference_image,1))];
    
    % update the drift vector
    drift_vector = cat(1,drift_vector, [i corr_offset(1)*bin_size corr_offset(2)*bin_size]);
                        
     % now make an image transform
    t = [ 1 0 0; 0 1 0; -corr_offset(1) -corr_offset(2) 1;];
    tf = maketform('affine',t);
    [compare_image] = imtransform(compare_image, tf, 'Xdata',[1,size(reference_image,2)],'Ydata',[1,size(reference_image,1)]);
    
    reference_image = reference_image + compare_image;
    output_image = double(reference_image);
end

%%
% display the final image
figure
subplot(1,5,[1,2,3])
imagesc(output_image);
colormap(hot);
axis image;
subplot(1,5,4)
plot(drift_vector(:,2),drift_vector(:,1),'k-');
subplot(1,5,5)
plot(drift_vector(:,3),drift_vector(:,1),'k-');

%%
% send the output back to the user
varargout{1} = output_image;
if (nargout > 1)
    varargout{2} = drift_vector;
end

return