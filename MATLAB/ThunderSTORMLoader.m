% Function to load exported Single-Molecule Localisation data from 
% ThunderSTORM .csv files.
%
% Usage:
%   molecules = ThunderSTORMLoader('./SMLM/PALM_mEOS9M_.csv');
%
% ARL 2016/11/16

function [molecules] = ThunderSTORMLoader( filename )

molecules = [];

% error check to see whether the file exists!
if ~exist(filename, 'file')
    disp('Warning! File does not exist. Check the filename.');
    return;
end

% check to see whether this is a .CSV file
[~,~,ext] = fileparts(filename);
if ~strcmp(ext,'.csv')
    disp('Warning! This is not a .csv file.');
    return;
end

% now that we've confirmed that we have a good file, let's open it
% and READ the contents
fileID = fopen(filename, 'rt');

% the first line of the file, is the header information. Read it
C = textscan(fileID,'%s',1,'Delimiter',',');
num_headers = 0; header = {};

while test_header(C)
    num_headers = num_headers+1;
    header{num_headers} = char(C{1,1});
    C = textscan(fileID,'%s',1,'Delimiter',',');   
end

% reset the file pointer
frewind(fileID);

% read the headers again (but discard)
h = textscan(fileID, repmat('%s',[1,num_headers]),1,'Delimiter',',');

% OK - finally we have the headers, let's load the data
C_data1 = textscan(fileID,repmat('%f',[1,num_headers]),'Delimiter',',','CollectOutput',1);

% end this madness!
molecules.data = C_data1{1,1};
molecules.header = header;
molecules.filename = filename;

fclose(fileID);
return


%% TEST THE STRING FOR HEADER-LIKE QUALITIES
function header_flag = test_header(C)
header = char(C{1,1});
if strcmp(header(1),'"') && strcmp(header(end),'"')
    header_flag = 1;
else
    header_flag = 0;
end
return