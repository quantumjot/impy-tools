function [ varargout ] = Octopus_get_frame( OInfo, frame_number )
%OCTOPUS_GET_FRAME Open and grab a frame from the Octopus stream
%   Detailed explanation goes here

if (frame_number < 1 || frame_number>OInfo.num_frames)
    disp('Error: Invalid frame number specified.')
    varargout{1} = [];
    if nargout > 1
        varargout{2} = [];
    end
    return;
end

% get the header data for the frame number
header = OInfo.headers(frame_number);
frame_size = [str2double(header.W) str2double(header.H)]; %TODO: sort out types
file_offset = (frame_number-1)*frame_size(1)*frame_size(2);

try
    data_file = fopen(strcat(header.filename,'.dat'), 'r');
catch
    disp('Error: Cannot open stream file.');
    return;
end

% go to the correct area of the file and grab the data
fseek(data_file, file_offset, 'bof');
[frame] = rot90(fread(data_file, frame_size,'uint16=>uint16'));
fclose(data_file);

% output it
varargout{1} = frame;
if nargout > 1
    varargout{2} = header;
end

return

