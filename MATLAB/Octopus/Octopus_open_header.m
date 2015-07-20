function [ headers ] = Octopus_open_header( filename )
%OCTOPUS_OPEN_HEADER Open and read the contents of an Octopus header file
%   Detailed explanation goes here

try
    header_file = fopen(strcat(filename,'.dth'), 'r');
catch
    disp('Error: Cannot open header file.');
    return;
end


headers = [];

% loop through the header extracting header info
while(1)
    
    % grab a line from the header
    header_line = fgetl(header_file);
    
    % have we have reached the end?
    if (header_line == -1)
        break
    end

    %header_pattern = '(?<key>(\w*)):\s?(?<value_number>(-?[0-9\.]+))?(?<value_bool>(True|False))?';
    header_pattern = '(?<key>(\w*)):\s?(?<value>(-?[0-9\.]+)|(True|False))';
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
return

