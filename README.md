# impy-tools

A set of tools for manipulating and converting data using ImageJ and MATLAB. These should be relatively
intuitive in their use.

## Functions/Loaders

+ MATLAB scripts and functions to manipulated Octopus data streams, or load single-molecule data from ThunderSTORM.
+ ImageJ (Python) plugins to import Octopus streams and create image datasets for machine learning.

## Notes

MATLAB scripts can be used as follows:

### OctopusLoader.m
A class for loading Octopus streams into MATLAB

```sh

% load the Octopus stream
OData = OctopusLoader('./SMLM/Calibration9_');

% grab frame 100
frame = OData.get_frame(100)

% grab the frame and header information
frame,header = OData.get_frame(100)

% grab only the header information
header = OData.get_header(100)
```

### ThunderSTORMLoader.m

A function to load exported ThunderSTORM localisation data into MATLAB. It should be agnostic as to the localisation 
method used, and should label all headers correctly in the results table. Can be used as follows:

```sh
molecules = ThunderSTORMLoader('./SMLM/PALM_mEOS9M_.csv');
```

