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

if gpuDeviceCount > 0
    USE_GPU = 1;
    disp('Found a GPU device...');
else
    USE_GPU = 0;
end


% user parameters
bin_size = .1;              % fraction of a CCD pixel
frames_per_stack = 100;     % number of camera frames per intermediate image
max_drift = 1./bin_size;    % maximum drift in CCD pixels between frame stacks
CCD_size = 250.;            % CCD size

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
num_images_in_stack = 0;

for i = 1:stack_size
    [xy] = molecules(molecules(:,1)>=(i-1)*frames_per_stack & molecules(:,1)<=i*frames_per_stack,:);   
    [current_image] = quick_localisation_image(xy, bin_size, CCD_size);
    if sum(current_image(:)) > 0
        time_stack(:,:,num_images_in_stack+1) = current_image;
        num_images_in_stack=num_images_in_stack+1;
    end
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
for i = 2:num_images_in_stack

    % give the user a progress update
    disp(sprintf('Completed %d of %d stacks...',i,num_images_in_stack));
    
    compare_image = time_stack(:,:,i);
    % calculate the normalised cross correlation, and mask it
    if USE_GPU
        [c] = normxcorr2(gpuArray(compare_image), gpuArray(reference_image));
    else
        [c] = normxcorr2(compare_image, reference_image);
    end
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


function [output_image] = quick_localisation_image(molecules, bin_size, CCD_size)

% calculate the bins in a fast way
binx = 1+floor((1.0/bin_size)*(molecules(:,2)-0.5*bin_size));
biny = 1+floor((1.0/bin_size)*(molecules(:,3)-0.5*bin_size));
bins = [binx, biny];

% sanity check that we haven't exceeded bounds
min_bin = 1;
max_bin = [CCD_size./bin_size, CCD_size./bin_size];

% make some space for the new image
output_image = uint8(zeros(max_bin));

bins_to_exclude = (bins(:,1)<min_bin | bins(:,2)<min_bin | bins(:,1)>max_bin(1) | bins(:,2)>max_bin(2));
bins(bins_to_exclude,:) = [];

% now make the 2D histogram of the data, using the sparse matrix trick
[output_hist] = uint16(full(sparse(bins(:,1), bins(:,2), 1)));
output_image(1:size(output_hist,1),1:size(output_hist,2)) = output_hist;
return