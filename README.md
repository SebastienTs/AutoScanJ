# AutoScanJ
**A suite of ImageJ and Micro-Manager scripts to perform intelligent imaging.**

![](Robot.jpg)

Software documentation for use with Micro-Manager: https://bit.ly/2tFiDyD<br/>
software documentation for use with Leica LAS AF:  https://bit.ly/2DMxmMy<br/>

For details, refer to the article **AutoScanJ: A Suite of ImageJ Macros for Intelligent Microscopy** (to be published soon).

Don't have a microscope at hand but still want to test the macros?

Download test data here: https://bit.ly/3d25TYt

For fixed experiments:
- Unzip the data that you want to test to an empty folder
- Run the macro as usual and select the folder you unzipped the data to as experiment folder
- Untick "Send CAM scripts" so that the macro does not attempt to control the microscope

For live experiments:
- Unzip the data that you want to test to an empty folder
- Create an **empty** folder
- Set the variable **OfflineFilesPath** to the path to the data folder you unzipped
- Run the macro as usual and select the empty folder as experiment folder
- Untick "Send CAM scripts" so that the macro does not attempt to control the microscope
