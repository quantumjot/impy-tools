function [OInfo] = Octopus_stack_info(path, file_stem)
%OCTOPUS_STACK_INFO Load the octopus file stream and return a structure
%with details of the files
%   General usage is as follows:
%
%   Get the Octopus stream information:
%   >> OInfo = Octopus_stack_info('/Users/ubcg83a/Data/STORM/', 'Calibration9_');
%
%   And grab frame 100 and the metadata from the stream:
%   >> [frame, header] = Octopus_get_frame(OInfo, 100);
%   >> [frame] = Octopus_get_frame(OInfo, 100);

% start by making an Octopus_info structure
OInfo.path = path;
OInfo.file_stem = file_stem;
OInfo.file_indices = [];

% get the path, search for files and return an info structure
all_files = dir(strcat(path,'/*.dth'));

if length(all_files) < 1
    disp('Warning: No Octopus data found in the directory specified');
    return
end

% search pattern with identifiers
stem_pattern = strcat('(?<stem>',file_stem,')_?(?<idx>[0-9]+)(?<type>\.dth)');

for f = 1:length(all_files)
    [filename] = all_files(f).name;
    [split_filename] = regexp(filename, stem_pattern, 'names');
    
    if ~isempty(split_filename)
        OInfo.file_indices = cat(1,OInfo.file_indices, str2num(split_filename.idx));
    end
end

% sort the file indices so that we load them in order
OInfo.file_indices = sort(OInfo.file_indices);
OInfo.num_files = length(OInfo.file_indices);

if OInfo.num_files < 1
    disp('Error: Octopus stream is empty.');
    return;
end

% now load the header files and generate the frame mapping
disp('Loading Octopus stream...')
headers = [];
for f = 1:OInfo.num_files
    [header_filename] = strcat(path, '/', file_stem, num2str(OInfo.file_indices(f)));
    [header] = Octopus_open_header(header_filename);
    % TODO: adjust the frame numbers
    headers = cat(1,headers, header);
end

% now set all of this info into the data structure
OInfo.width = headers(1).W;
OInfo.height = headers(1).H;
OInfo.num_frames = length(headers);
OInfo.headers = headers;

return