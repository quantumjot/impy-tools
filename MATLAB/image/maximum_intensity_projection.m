function [mip] = maximum_intensity_projection(stack)
[mipm]    = reshape(stack,size(stack,1)*size(stack,2),size(stack,3));
[maxi]    = squeeze( max(mipm,[],2) );
[mip]     = reshape(maxi,size(stack,1),size(stack,2));
end