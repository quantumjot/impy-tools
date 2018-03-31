"""
ImageJ plugin to export training data for generation of classifiers

Takes one to two image data streams, and crops out ROIs around
centroids defined by the ImageJ multipoint ROI. Packages these up
for use by the machine learning classifiers.

Functions:

Notes:

Changes:

Lowe, A.R. 2016
code@arlowe.co.uk
"""

__version__ = "0.02"
__author__ = "Alan R. Lowe"
__email__ = "code@arlowe.co.uk"


DEFAULT_CLASSES = ['interphase','prometaphase','metaphase','anaphase','apoptosis','none']


from ij.io import FileInfo, OpenDialog, FileOpener, ImageWriter, DirectoryChooser
from ij.gui import GenericDialog, Roi, PointRoi, TrimmedButton
from ij.measure import ResultsTable
from ij import ImagePlus, ImageStack, WindowManager
import ij.IJ as IJ
from ij.plugin.frame import RoiManager
from java.awt.event import ActionListener

import re
import os
import pickle
from datetime import datetime


DEFAULT_OUTPUT_PATH = "/home/arl/Documents/Data/CNN_Training_Anna/testing/"




def check_and_makedir(folder_name):
    """ Does a directory exist? if not create it. """
    if not os.path.isdir(folder_name):
    	print 'Creating output folder {0:s}...'.format(folder_name)
    	os.mkdir(folder_name)
    	return False
    else:
    	return True



class IJClassifier_(object):
    def __init__(self):
        self.path = DEFAULT_OUTPUT_PATH
        self.window_size = 40

        # make a unique session id
        self.session_id = datetime.utcnow().strftime("%Y-%m-%d--%H-%M-%S")
        print self.session_id

    def __call__(self):

        # open a dialog menu and get the options
        opts = self.dialog()

        # now grab the ROIs and write out the classifier
        ROIs = self.grab(opts)
        self.write(ROIs, opts)


    def dialog(self):
        """
        Open the classifier dialog window and return the paramters
        chosen.
        """

        # determine how many images are currently open
        image_count = WindowManager.getImageCount()
        image_titles = list(WindowManager.getImageTitles())
        image_titles.append("None")

        # now open a dialog to let the user set options
        path_listener = SetPathListener(self.path)
        path_button = TrimmedButton("Output directory",0)
        path_button.addActionListener(path_listener)

        dlg = GenericDialog("Create classifier data (v"+__version__+")")
        dlg.addMessage("Session ID: "+ str(self.session_id))
        dlg.addMessage("")
        dlg.addMessage("Select the ROI you want to save")
        dlg.addNumericField("Window size (pixels): ", self.window_size, 0)
        dlg.addChoice("Class label: ", DEFAULT_CLASSES+['Other...'], DEFAULT_CLASSES[0])
        dlg.addStringField("Class label (if other): ", "")
        dlg.addChoice("Image file #1 (BF):",image_titles,"None")
        dlg.addChoice("Image file #2 (GFP):",image_titles,"None")
        dlg.addChoice("Image file #3 (RFP):",image_titles,"None")
        dlg.addChoice("Mask file:",image_titles,"None")
        dlg.addCheckbox("Rename ROIs", True)
        dlg.addCheckbox("Exclude edges", True)
        dlg.addCheckbox("Save ROI zip", True)
        dlg.addCheckbox("Save classifier details", True)
        dlg.add(path_button)
        dlg.showDialog()

        # handle the cancelled dialog box
        if dlg.wasCanceled():
            return None


        label_option = dlg.getNextChoice()
        if label_option == 'Other...':
            label = dlg.getNextString()
        else:
            label = label_option



        # get the root path from the path listener
        root_path = path_listener.path

        if not os.path.isdir(root_path):
            w_dlg = GenericDialog("Warning")
            w_dlg.addMessage("Root path does not exist!!")
            w_dlg.showDialog()
            return None

        # try to make the directory for the label if it does not exist
        label_path = os.path.join(root_path, label)
        check_and_makedir(label_path)

		# get the options
        dialog_options = {'window_size': dlg.getNextNumber(),
                            'label': label,
                            'BF': dlg.getNextChoice(),
                            'GFP': dlg.getNextChoice(),
                            'RFP': dlg.getNextChoice(),
                            'mask': dlg.getNextChoice(),
                            'rename': dlg.getNextBoolean(),
                            'edges': dlg.getNextBoolean(),
                            'zip': dlg.getNextBoolean(),
                            'save': dlg.getNextBoolean(),
                            'path': label_path}

        # check that we actually selected an image file
        if all([dialog_options[d] == "None" for d in ['BF','GFP','RFP']]):
            w_dlg = GenericDialog("Warning")
            w_dlg.addMessage("You must select an image stream.")
            w_dlg.showDialog()
            return None

        # grab the contents and return these as a dictionary
        return dialog_options

    def grab(self, dialog_options=None):
        """ Get the image patches using the ROI manager.
        """

        if not dialog_options:
            return

        # get a refence to the ROI manager and check that we have ROIs!
        rm = RoiManager.getRoiManager()
        num_ROIs = rm.getCount()
        if num_ROIs < 1: return None

        if dialog_options['rename']:
            for r in xrange(num_ROIs):
                rm.getRoi(r).setName('{0:s}_{1:s}_{2:d}'.format(self.session_id,dialog_options['label'],r))

        return [ClassifierROI(rm.getRoi(r), path=dialog_options['path']) for r in xrange(num_ROIs)]



    def write(self, ROIs=None, dialog_options=None):
        """ Write out the classifier info
        """

        if not dialog_options or not isinstance(ROIs, list):
            return

        # get the data stack
        channels = ['BF', 'GFP', 'RFP']
        channels_to_use = [c for c in channels if dialog_options[c] != 'None']
        print channels_to_use


        for c in channels_to_use:
            for r in ROIs:
                IJ.log("Grabbing patches for ROI: "+ r.name)
                r.window_size = dialog_options['window_size']
                r.save = dialog_options['save']
                r(data=WindowManager.getImage(dialog_options[c]), channel=c)


        if dialog_options['zip']:
            roi_fn = os.path.join(dialog_options['path'], dialog_options['label']+'_'+str(self.session_id)+'_ROIset.zip')
            rm = RoiManager.getRoiManager()
            rm.runCommand('Select All')
            rm.runCommand('Save', roi_fn)

        # old style dictionary comprehension
        ROI_dict = dict((r.name,{'frame':r.index, 'x':r.x, 'y':r.y}) for r in ROIs)
        ROI_dict['opts'] = dialog_options

        # save out a pickled dictionary with all of the details
        if dialog_options['save']:
            pass
            # try:
            #     classifier_file = open(os.path.join(dialog_options['path'],dialog_options['data']+'_classifier.p'), 'wb')
            #     pickle.dump( ROI_dict, classifier_file, -1)
            #     classifier_file.close()
            # except IOError:
            #     IJ.log('Could not pickle classifier info file.')

        print ROI_dict





class SetPathListener(ActionListener):
    """ ActionListener subclass to deal with button presses in the
    GUI. Returns the selected path from the DirectoryChooser
    function.
    """
    def __init__(self, path=DEFAULT_OUTPUT_PATH):
        self.path = path

    def actionPerformed(self, event):
        dlg = DirectoryChooser("Choose an output directory for the classifier")

        if os.path.exists(self.path):
            dlg.setDefaultDirectory(self.path)

        self.path = dlg.getDirectory()
        IJ.log("Added path: "+self.path)









class ClassifierROI(object):
    """
    ClassifierROI

    A wrapper class to deal with multipoint ROIs and extracting
    windows from image streams for use with the classifier.

    Notes:
        None
    """
    def __init__(self, ROI=None, path=None, label='None'):
        if isinstance(ROI, PointRoi):
            self.__ROI = ROI
        else:
            raise TypeError("ClassifierROI: Roi needs to be of type ImageJ PointROI")

        self.save = False
        self.window_size = 20
        self.bounds = self.__ROI.getBounds()
        self.label = label

        # is this a well formed path
        if not isinstance(path, basestring):
            raise TypeError("ClassifierROI: path must be specified as a string")

        # make sure that the directory name is the label name


        # check that the path exists
        if not os.path.exists(path):
            raise IOError("ClassifierROI: path does not exist ({0:s})".format(path))


        self.__classifier_path = path


    @property
    def name(self):
        return self.__ROI.getName()

    @property
    def index(self):
        return self.__ROI.getPosition()

    @property
    def datapath(self):
        return self.__classifier_path

    @property
    def x(self):
        return list(self.__ROI.getPolygon().xpoints)
    @property
    def y(self):
        return list(self.__ROI.getPolygon().ypoints)

    def __len__(self):
        return self.__ROI.getCount( self.__ROI.getCounter() )

    def __getitem__(self, pointID=None):
        if not isinstance(pointID, int):
            raise TypeError("ClassifierROI: point ID must be an integer")

        if pointID < 0 or pointID > len(self)-1:
            raise Exception("ClassifierROI: point ID must be in the range 0 to {0:d}".format(len(self)-1))

        return ( self.x[pointID], self.y[pointID] )


    def __call__(self, data=None, channel='BF'):
        """ Loop through all of the points, extract a window from the image stack
        and (optionally) this mask data. Crop a region and save the image out
        to the specified path.
        """


        if not isinstance(data, ImagePlus):
            raise TypeError("ClassiferROI: image stack data must be of type ImageStack")

        print self.name, len(self)

        for i in xrange(len(self)):

            x,y = self[i]

            temp_ROI = Roi(x-self.window_size, y-self.window_size, self.window_size*2, self.window_size*2)

            new_im = self.grab(data, temp_ROI)
            new_im.setTitle(channel+'_'+self.__ROI.name+"_"+str(i))
            self.write(new_im)

            if self.save:
                new_im.close()
            else:
                new_im.show()

        return

    def grab(self, data=None, temp_ROI=None):
        """ Grab the window around the ROI and return a new image
        """

        # go to the frame number, copy the region of the image, rename it then save it
        try:
            data.setPosition(self.index)
        except:
            print 'Not an image stack!'
        data.setRoi(temp_ROI, False)
        data.copy()

        # now create a new image for this cropped region
        return data.getClipboard()

    def write(self, patch=None):
        """ Write the patch to a file.
        """
        if self.save:
            IJ.save(patch, os.path.join(self.datapath, patch.getTitle()+".tif"))



c = IJClassifier_()
c()
