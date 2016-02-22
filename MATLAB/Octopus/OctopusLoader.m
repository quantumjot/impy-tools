% Easy class definition for the OctopusLoader - massively simplifies
% dealing with data streams.
%
% Usage:
%   OData = OctopusLoader('/Users/ubcg83a/Data/STORM/Calibration9_')
%   frame = OData.get_frame(100)
%   frame,header = OData.get_frame(100)
%   header = OData.get_header(100)
%
%
% TODO:
%   (ARL 21/02/2016) - Contiguous/Non-contiguous image sequences
%
% ARL 2016/02/19

classdef OctopusLoader
    properties
        OInfo;
        initialised = 0;
        width = 0;
        height = 0;
        num_frames = 0;
        bit_depth = 16;
    end
    methods
        % class instantiation
        function obj = OctopusLoader(filename)
            if ischar(filename)
                % initialise the stack
                obj.OInfo = Octopus_stack_info(filename);
                obj.initialised = 1;
                
                % set some stack properties
                obj.height = obj.OInfo.height;
                obj.width = obj.OInfo.width;
                obj.num_frames = obj.OInfo.num_frames;
                obj.bit_depth = obj.OInfo.bit_depth;
            else
                error('OctopusLoader: file path and stem must be supplied');
            end
        end
        
        % methods to get frames
        function varargout = get_frame(obj, frame_number)
            if true(obj.initialised)
                
                % frame or frame + header info?
                switch nargout
                    case 1
                       [varargout{1}, ~] = Octopus_get_frame(obj.OInfo, frame_number);
                    case 2
                       [varargout{1}, varargout{2}] = Octopus_get_frame(obj.OInfo, frame_number);
                end
            else
                error('OctopusLoader: data stream not loaded');
            end
        end 
        
        function header = get_header(obj, frame_number)
            if true(obj.initialised)
                [~, header] = Octopus_get_frame(obj.OInfo, frame_number); 
            else
                error('OctopusLoader: data stream not loaded');
            end
        end 
    end
end


function [OInfo] = Octopus_stack_info(filename)
%OCTOPUS_STACK_INFO Load the octopus file stream and return a structure
%with details of the files
%   General usage is as follows:
%
%   Get the Octopus stream information:
%   >> OInfo = Octopus_stack_info('/Users/ubcg83a/Data/STORM/Calibration9_');
%
%   And grab frame 100 and the metadata from the stream:
%   >> [frame, header] = Octopus_get_frame(OInfo, 100);
%   >> [frame] = Octopus_get_frame(OInfo, 100);

% check that the path is well formed
[pth,file_stem,~] = fileparts(filename);

% start by making an Octopus_info structure
OInfo.path = pth;
OInfo.file_stem = file_stem;
OInfo.file_indices = [];

% get the path, search for files and return an info structure
all_files = dir(fullfile(OInfo.path,'*.dth'));

if length(all_files) < 1
    error('Warning: No Octopus data found in the directory specified');
end

% search pattern with identifiers
stem_pattern = strcat('(?<stem>',OInfo.file_stem,')_?(?<idx>[0-9]+)(?<type>\.dth)');

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
    error('Error: Octopus stream is empty.');
end

% now load the header files and generate the frame mapping
disp('Loading Octopus stream...')
headers = [];
for f = 1:OInfo.num_files
    file_idx = strcat(OInfo.file_stem, num2str(OInfo.file_indices(f)));
    [header_filename] = fullfile(OInfo.path, file_idx);
    [header] = Octopus_open_header(header_filename);
    headers = cat(1,headers, header);
end

% now set all of this info into the data structure
OInfo.width = headers(1).W;
OInfo.height = headers(1).H;
OInfo.num_frames = length(headers);
OInfo.headers = headers;
OInfo.bit_depth = '16'; % default from Andor cameras

if isfield(headers(1), 'bit_depth')
    OInfo.bit_depth = headers(1).bit_depth;
end

end



function [ headers ] = Octopus_open_header( filename )
%OCTOPUS_OPEN_HEADER Open and read the contents of an Octopus header file
%   Detailed explanation goes here

try
    header_file = fopen(strcat(filename,'.dth'), 'r');
catch
    error('Error: Cannot open header file %s', filename);
end


headers = [];

% regexp pattern for header data
header_pattern = '(?<key>(\w*)):\s?(?<value>(-?[0-9\.]+)|(True|False))';

% loop through the header extracting header info
while(1)
    
    % grab a line from the header
    header_line = fgetl(header_file);
    
    % have we have reached the end?
    if (header_line == -1)
        break
    end

    % get the header data
    header = regexp(header_line, header_pattern, 'names');
   
    % rearrange the data into something useful
    header_info = struct('filename',filename);
    for i = 1:length(header)
        header_info = setfield(header_info, header(i).key, header(i).value);
    end
    
    % concatenate if we have more than one frame in a stream block
    headers = cat(1,headers, header_info);
end

% close it
fclose(header_file);
end


function [ varargout ] = Octopus_get_frame( OInfo, frame_number )
%OCTOPUS_GET_FRAME Open and grab a frame from the Octopus stream
%   Detailed explanation goes here

if (frame_number < 1 || frame_number>OInfo.num_frames)
    error('Error: Invalid frame number specified (range: 1-%d) \n',OInfo.num_frames);
end

% get the header data for the frame number
header = OInfo.headers(frame_number);
frame_size = [str2double(header.W) str2double(header.H)]; %TODO: sort out types

% check to see whether there is a 'bit_depth' field
BIT_DEPTH = 'uint16=>uint16';   % default bit depth
if isfield(header, 'Bit_Depth')
    switch header.Bit_Depth
        case '8'
            BIT_DEPTH = 'uint8=>uint8';
        case '16'
            BIT_DEPTH = 'uint16=>uint16';
        otherwise
            BIT_DEPTH = 'uint16=>uint16';
    end
end

% get the offset, i.e. frame number within the file
file_offset = str2double(header.N)*frame_size(1)*frame_size(2);

try
    data_file = fopen(strcat(header.filename,'.dat'), 'r');
catch
    error('Error: Cannot open stream file: %s', header.filename);
end

% go to the correct area of the file and grab the data
fseek(data_file, file_offset, 'bof');
[frame] = rot90(fread(data_file, frame_size, BIT_DEPTH));
fclose(data_file);

% output it
varargout{1} = frame;
if nargout > 1
    varargout{2} = header;
end

end