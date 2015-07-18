"""
ImageJ plugin to load Octopus camera stream files. 

Output from the microscope control software (Octopus) is saved as as stream
of two file types:

	.dth - header/metadata in plain text
	.dat - 16-bit unsigned raw binary image data

The software splits the stream into chunks of (usually, although not necessarily
always) 100 frames, appending a sequence number to the end of the filename:

 	OctopusData_1.dat
 	OctopusData_1.dth
 	OctopusData_2.dat
 	OctopusData_2.dth
 	...

Files are generally of the format: OctopusData_1.dat, where 'OctopusData_' is 
considered the file stem, and '1' the sequence number. The corresponding .dth 
file contains the header information for these images. Thiss encodes the 
particulars of the instrument at the moment the camera acquisition occurs. 

This plugin will load an Octopus stream into ImageJ as a 16-bit unsigned (short)
stack, and load the metadata into a results table for easy viewing.

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
	150622 (ARL) Added a dialog to allow more control over opening.
"""


from ij.io import FileInfo, OpenDialog, FileOpener
from ij.gui import GenericDialog
from ij.measure import ResultsTable
from ij import ImagePlus, ImageStack
import ij.IJ as IJ

import re
from os.path import isfile
from os import listdir
from time import strftime, gmtime

MAX_FRAMES_TO_IMPORT = 1000

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
	if op.wasCanceled(): return False

	# get the file extension
	file_extension = re.search('(\.[a-z][a-z][a-z])', op.getFileName()).group(1)
	
	if file_extension != ".dth":
		dlg = GenericDialog("Warning")
		dlg.addMessage("Please select an octopus .dth file")
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
	file_timestamp = strftime("%a, %d %b %Y %H:%M:%S", gmtime(float(header['Time'][0])) )
	

	# make a new imagestack to store the data
	stack = ImageStack(fi.width, fi.height)

	# finally, we need to make a list of files to import as sometimes we have
	# non contiguous file numbers
	try:
		files = listdir(op.getDirectory())
	except IOError:
		raise IOError( "No files exist in directory: " + op.getDirectory())

	filenums = []
	for f in files:
		# strip off the stem, and get the number
		targetfile = re.match(file_stem+'([0-9]+)\.dth', f)
		# only take thosefiles which match the formatting requirements
		if targetfile:
			filenums.append( int(targetfile.group(1)) )

	# sort the file numbers
	sorted_filenums = sorted(filenums)

	# make a file stats string
	file_stats_str = file_stem + '\n' + str(fi.width) +'x' + str(fi.height) + 'x' + \
		str(len(sorted_filenums)) +' (16-bit)\n' + file_timestamp


	# now open a dialog to let the user set options
	dlg = GenericDialog("Load Octopus Stream")
	dlg.addMessage(file_stats_str)
	dlg.addStringField("Title: ", file_stem)
	dlg.addNumericField("Start: ", 1, 0);
	dlg.addNumericField("End: ", length(sorted_filenums), 0)
	dlg.addCheckbox("Open headers", True)
	dlg.addCheckbox("Contiguous stream?", False)
	dlg.showDialog()

	# if we cancel the dialog, exit here
	if dlg.wasCanceled():
		return

	# set some params
	file_title = dlg.getNextString()
	file_start = dlg.getNextNumber()
	file_end = dlg.getNextNumber()
	DISPLAY_HEADER = bool( dlg.getNextBoolean() )

	# check the ranges
	if file_start > file_end: 
		file_start, file_end = file_end, file_start
	if file_start < 1: 
		file_start = 1
	if file_end > length(sorted_filenums): 
		file_end = length(sorted_filenums) 

	# now set these to the actual file numbers in the stream
	file_start = sorted_filenums[file_start-1]
	file_end = sorted_filenums[file_end-1]

	files_to_open = [n for n in sorted_filenums if n>=file_start and n<=file_end]

	# if we've got too many, truncate the list
	if (len(files_to_open) * fi.nImages * fi.width * fi.height) > (MAX_FRAMES_TO_IMPORT*512*512):
		dlg = GenericDialog("Warning")
		dlg.addMessage("This may use a lot of memory. Continue?")
		dlg.showDialog()
		if dlg.wasCanceled(): return False

	IJ.log( "Opening file: " + op.getDirectory() + op.getFileName() )
	IJ.log( file_stats_str + "\nFile range: " + str(files_to_open[0]) + \
		"-" + str(files_to_open[-1]) +"\n" )

	# make a results table for the metadata
	# NOTE: horrible looping at the moment, but works
	if DISPLAY_HEADER:
		rt = ResultsTable()

	# ok now we can put the files together into the stack
	for i in files_to_open:

		# open the original .dat file and get the stack
		fi.fileName = get_Octopus_filename( op.getDirectory(), file_stem, i)
		
		if isfile( fi.fileName ):
			fo = FileOpener(fi)
			imp = fo.open(False).getStack() 
	
			# put the slices into the stack
			for im_slice in xrange( imp.getSize() ):
				ip = imp.getProcessor( im_slice+1 )
				bi = ip.get16BitBufferedImage() 
				stack.addSlice( file_title,  ip )


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