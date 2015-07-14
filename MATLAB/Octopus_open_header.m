function [ headers ] = Octopus_open_header( filename )
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

try
    header_file = fopen(filename, 'r');
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

    header_pattern = '(?<key>(\w*)):\s?(?<value_number>(-?[0-9\.]+))?(?<value_bool>(True|False))?';
    headers = regexp(header_line, header_pattern, 'names');
    
    %headers = [headers sscanf(header_line,'N:%d H:%d W:%d Time:%f')];
end

% close it
fclose(header_file);
end

