# AutoScanJ
**A suite of ImageJ and Micro-Manager scripts to perform intelligent imaging.**

![](Robot.jpg)

For an overview of the technique, refer to the article **AutoScanJ: A Suite of ImageJ scripts for Intelligent Microscopy** (to be published soon).

Software documentation for use with Micro-Manager: https://bit.ly/2tFiDyD<br/>
software documentation for use with Leica LAS AF:  https://bit.ly/2DMxmMy<br/>

Don't have a compatible microscope at hand but still want to test the macros?

Download test data here: https://bit.ly/3d25TYt

For fixed experiments:
- Unzip the data that you want to test to an empty folder
- Run the corresponding IJ macro and select the folder you unzipped the data to as experiment folder
- Untick "Send CAM scripts" so that the macro does not attempt to control the microscope

For live experiments:
- Unzip the data that you want to test to an empty folder
- Create an **empty** folder
- Set the variable **OfflineFilesPath** in the IJ macro to the path of the folder you unzipped the data to
- Run the corresponding IJ macro and select the empty folder as experiment folder
- Untick "Send CAM scripts" so that the macro does not attempt to control the microscope
