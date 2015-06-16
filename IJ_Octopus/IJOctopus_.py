from ij.io import FileInfo, OpenDialog, FileOpener
from ij.ImageStack import *
from ij.gui import GenericDialog
from ij import ImagePlus, ImageStack

import re
from os.path import isfile

MAX_FILES_TO_IMPORT = 10

""" Open an Octopus file stream for ImageJ.
"""
def open_octopus_file():

	# set up a file info structure
	fi = FileInfo()
	fi.fileFormat = fi.RAW
	fi.fileType=FileInfo.GRAY16_UNSIGNED
	fi.intelByteOrder = True
	fi.nImages = 1

	op = OpenDialog("Choose Octopus .dth file...", "")
	print "Opening file: "+ op.getDirectory()+ op.getFileName()

	# get the file extension
	file_extension = re.search('(\.[a-z][a-z][a-z])', op.getFileName()).group(1)
	
	if file_extension != ".dth":
		dlg = GenericDialog('Warning')
		dlg.addMessage('Please select an octopus .dth file')
		dlg.showDialog()
		return False

	# ok now we need to parse the header info
	header_file = open(op.getDirectory()+ op.getFileName(), 'r')
	header_lines = header_file.readlines()
	header_file.close()
	fi.nImages  = len(header_lines)

	# will assume that all files have the same size
	fi.width = int( re.findall('W\:\s*(\S+)', header_lines[0])[0] )
	fi.height = int( re.findall('H\:\s*(\S+)', header_lines[0])[0] )

	# now strip the filename into a stem and index
	file_parse = re.match('([a-zA-z0-9_]*)_([0-9]+)\.dth', op.getFileName())
	file_stem = file_parse.group(1)
	file_index = int( file_parse.group(2) )

	# make a new imagestack to store the data
	stack = ImageStack(fi.width, fi.height)
	
	# ok now we can put the files together into the stack
	for i in xrange(file_index, file_index+MAX_FILES_TO_IMPORT):

		# open the original .dat file and get the stack
		fi.fileName = get_octopus_filename( op.getDirectory(), file_stem, i)
		
		if isfile(fi.fileName):
			fo = FileOpener(fi)
			imp = fo.open(False).getStack() 
	
			# put the slices into the stack
			for im_slice in xrange(1,1+imp.getSize()):
				ip = imp.getProcessor(im_slice)
				bi = ip.get16BitBufferedImage() 
				stack.addSlice( str(im_slice+(i-file_index)*100),  ip )
		else:
			break


	output = ImagePlus('Octopus ('+file_stem+')', stack)
	output.show()

	return True


""" Function to return a complete Octopus filename
"""
def get_octopus_filename(pth, stem, index, ext=".dat"):
	return pth + stem + "_" + str(index) + ext


open_octopus_file()