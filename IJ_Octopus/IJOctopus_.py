"""
ImageJ plugin to load Octopus camera streams files. 

Output from the microscope control software (Octopus) is saved as as stream
of two file types:

	.dth - header/metadata in plain text
	.dat - 16-bit unsigned raw binary image data

The streaming split the files into chunks of (usually, although not necessarily
always) 100 frame sequences. The metadata encodes the particulars of the
instrument at the moment the camera acquisition occurs.

Files are generally of the format: OctopusData_1.dat, where 'OctopusData_' is
considered the file stem, and 1 the sequence number. The corresponding .dth 
file contains the header information for these images. This plugin will load 
a sequence of 16-bit unsigned (short) images into ImageJ memory as a stack, 
and load the metadata into a results table for easy viewing.

Note that the plugin limits the number of frames into memory to prevent too
much memory being utilised.

Lowe, A.R. 2015
code@arlowe.co.uk

Functions:
	open_Octopus_file()


Notes:
	Would be nice to give the user some control over how many files loaded,
	the range etc.

Changes:
	150617 (ARL) Updated to include header info now.
"""


from ij.io import FileInfo, OpenDialog, FileOpener
from ij.ImageStack import *
from ij.gui import GenericDialog
from ij.measure import ResultsTable
from ij import ImagePlus, ImageStack
import re
from os.path import isfile
from os import listdir

MAX_FRAMES_TO_IMPORT = 9000
DISPLAY_HEADER = True

""" Open an Octopus file stream for ImageJ.
"""
def open_Octopus_file():

	# set up a file info structure
	fi = FileInfo()
	fi.fileFormat = fi.RAW
	fi.fileType=FileInfo.GRAY16_UNSIGNED
	fi.intelByteOrder = True
	fi.nImages = 1

	op = OpenDialog("Choose Octopus .dth file...", "")
	print "Opening file: " + op.getDirectory() + op.getFileName()

	# get the file extension
	file_extension = re.search('(\.[a-z][a-z][a-z])', op.getFileName()).group(1)
	
	if file_extension != ".dth":
		dlg = GenericDialog('Warning')
		dlg.addMessage('Please select an octopus .dth file')
		dlg.showDialog()
		return False

	# now strip the filename into a stem and index
	file_parse = re.match('([a-zA-z0-9_]*_)([0-9]+)\.dth', op.getFileName())
	file_stem = file_parse.group(1)
	file_index = int( file_parse.group(2) )

	# ok now we need to parse the header info
	header = get_Octopus_header(op.getDirectory(), file_stem, file_index)
	fi.nImages  = len(header['N'])

	# will assume that all files have the same size
	fi.width = int( header['W'][0] )
	fi.height = int( header['H'][0] )

	# make a results table for the metadata
	# NOTE: horrible looping at the moment, but works
	if DISPLAY_HEADER:
		rt = ResultsTable()
	
	# make a new imagestack to store the data
	stack = ImageStack(fi.width, fi.height)

	# finally, we need to make a list of files to import as sometimes we have
	# non contiguous file numbers
	try:
		files = listdir(op.getDirectory())
	except IOError:
		raise IOError( 'No files exist in directory: ' + op.getDirectory())

	filenums = []
	for f in files:
		# strip off the stem, and get the number
		targetfile = re.match('('+file_stem+')([0-9]+)\.dth', f)
		# only take thosefiles which match the formatting requirements
		if targetfile:
			filenums.append( int(targetfile.group(2)) )

	# sort the file numbers
	sorted_filenums = sorted(filenums)

	# if we've got too many, truncate the list
	if len(sorted_filenums) * fi.nImages > MAX_FRAMES_TO_IMPORT:
		sorted_filenums = sorted_filenums[0:int(MAX_FRAMES_TO_IMPORT / fi.nImages)]

	# ok now we can put the files together into the stack
	for i in sorted_filenums:

		# open the original .dat file and get the stack
		fi.fileName = get_Octopus_filename( op.getDirectory(), file_stem, i)
		
		if isfile( fi.fileName ):
			fo = FileOpener(fi)
			imp = fo.open(False).getStack() 
	
			# put the slices into the stack
			for im_slice in xrange( imp.getSize() ):
				ip = imp.getProcessor( im_slice+1 )
				bi = ip.get16BitBufferedImage() 
				stack.addSlice( file_stem,  ip )


			if DISPLAY_HEADER:
				header = get_Octopus_header(op.getDirectory(), file_stem, i)
				for n in xrange(len(header['N'])):
					rt.incrementCounter()
					for k in header.keys():
						rt.addValue(k, parse_header( header[k][n] ) )

		else:
			break

	# done!
	output = ImagePlus('Octopus ('+file_stem+')', stack)
	output.show()

	if DISPLAY_HEADER:
		rt.show("Octopus header metadata")

	return True





""" Function to return a complete Octopus filename
"""
def get_Octopus_filename(pth, stem, index, ext=".dat"):
	return pth + stem + str(index) + ext






""" Function to parse and return the Octopus header info as a dictionary
"""
def get_Octopus_header(pth, stem, index):
	# open the header file, read the lines and close it
	header_filename = get_Octopus_filename(pth, stem, index, ext=".dth")
	try:
		header_file = open(header_filename, 'r')
	except IOError:
		raise IOError("Cannot open header file")
	
	header_lines = header_file.readlines()
	header_file.close()

	# parse the header info
	header_vals = zip(* [ re.findall('\S+:\s*(\S+)',line) for line in header_lines ])
	header_keys = re.findall('(\w*)\s*:\s*',header_lines[0])

	headers = {}

	for k in header_keys:
		headers[k] = header_vals[header_keys.index(k)]
	return headers


""" Parse the header to deal with bool values.
"""
def parse_header(header_val):
	if header_val == "True":
		return 1
	elif header_val == "False":
		return 0
	else:
		return float(header_val)


open_Octopus_file()