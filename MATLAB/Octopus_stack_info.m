function [Octopus_info] = Octopus_stack_info(path, file_stem)
%OCTOPUS_STACK_INFO Load the octopus file stream and return a structure
%with details of the files
%   Detailed explanation goes here

% start by making an Octopus_info structure
Octopus_info.path = path;
Octopus_info.file_stem = file_stem;
Octopus_info.file_indices = [];

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
        Octopus_info.file_indices = cat(1,Octopus_info.file_indices, str2num(split_filename.idx));
    end
end

% sort the file indices so that we load them in order
Octopus_info.file_indices = sort(Octopus_info.file_indices);
Octopus_info.num_files = length(Octopus_info.file_indices);
Octopus_info.frame_map = [];

if Octopus_info.num_files < 1
    disp('Error: Octopus stream is empty.');
    return;
end

% now load the header files and generate the frame mapping
for f = 1:Octopus_info.num_files
    [header_filename] = strcat(path, '/', file_stem, num2str(Octopus_info.file_indices(f)),'.dth');
    [header] = Octopus_open_header(header_filename);
    
end

return