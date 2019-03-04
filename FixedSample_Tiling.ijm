//////////////////////////////////////////////////////////////////////////////////////////////////
//
// Name:	FixedSample_Tiling
// Author: 	Sebastien Tosi (IRB/ADMCF)
// Date:	27-06-2013	
//	
// Pre-requisites (see documentation for more details): 
// This macro is meant to be used either with Micro-Manager or Leica LAS AF software 
// with matrix screener and CAM modules. It requires that the LASAF_client plugin is
// copied to ImageJ plugins folder. The macro can be runned from any computer connected to a 
// network from  which the server is visible. The microscope x/y references must be set 
// identically in the LAS AF and in the macro (parameters xyFlip, xSign and ySign). It is necessary
// to finely adjust the field of view rotation so that the borders of the image are parallel to x 
// or y stage moves (this angle is fixed for a given microscope so that this setting as to
// be done once for all). The experiment folder required by the macro must match the folder
// set as the LAS AF data export. The analysis functions should be written in an external file
// which path is properly configured in the default parameters. Timestamp naming in the matrix 
// screener exportation options is necessary since the macro is opening the images from the 
// last scan subfolder.  
// 
// Description: 
// The macro first launches the main scan (primary scan - low resolution job) and opens the images 
// from the experiment folder when this scan finished. 
// The macro accepts multiple channels (up to 3) and multiple z slices but not multiple fields of 
// view per well. The images will be displayed by RGB mixing the channels, intensity z-projecting and
// tiling the wells according to their physical position. 
// In the next step the user can select some points of interest to get high resolution views 
// centered at these positions. Alternatively it is possible to use an automatic image analysis function
// to generate these points of interest. The secondary scans made up of these views is then launched 
// and the images can be displayed in a stack browser. The order of appearance of the images is first 
// the well order and THEN only the order of acquisition.
//	
// Note: All the channels must have the same number of z planes
//
// IRB SP5 config:          	xyFlip = 1 xSign = -1 ySign = 1
// IBMB AF7000 config:     	xyFlip = 0 xsign = 1 ySign = 1
//		          
//////////////////////////////////////////////////////////////////////////////////////////////////

// Default parameters for the microscope configuration //////////
xyFlip = 0;
xSign = 1;	
ySign = 1;
LasafIP = "127.0.0.1";
LasafPort = 8895;
JobHigh = "Job high";
AnalysisFunctionsPath = getDirectory("macros")+"AnalysisFunctions_Fixed_Tiling.ijm";
Filter = 0;
/////////////////////////////////////////////////////////////////////////////////////////////

// Initialization
run("Options...", "iterations=1 count=1 edm=Overwrite");
run("Point Tool...", "mark=0 label selection=yellow");

// Store analysis functions to string
if(File.exists(AnalysisFunctionsPath))AnalysisFunctionsFile = File.openAsString(AnalysisFunctionsPath);
else exit("Could not find the analysis functions file,\nplease check the path to the file");
AnalysisFunctions = RegisterFunctions(AnalysisFunctionsFile);

// Macro parameters dialog box
ExpPath = getDirectory("Path to the LASAF experiment folder");
Dialog.create("AutoScanJ FixedSample_Tiling");
Dialog.addMessage("Scans");
Dialog.addCheckbox("Perform primary scan", true);
Dialog.addCheckbox("Send CAM scripts (un-tick for debugging)", true);
Dialog.addCheckbox("Micro-manager mode", true);
Dialog.addCheckbox("AF drift compensation", false);
Dialog.addMessage("Display");
Dialog.addCheckbox("Display quick view montage", true);
Dialog.addNumber("QuickView secondary/primary scans zoom ratio", 10);
Dialog.addNumber("QuickView scale", 1);
Dialog.addCheckbox("Display secondary scan images", false);
Dialog.addMessage("Analysis");
Dialog.addChoice("Automatic pre-analysis",AnalysisFunctions,"None");
Dialog.addMessage("Specific modes");
Dialog.addCheckbox("No scan, no analysis, only open secondary scan images", false);
Dialog.addCheckbox("No primary scan, only resend secondary scan", false);
Dialog.show();

// Recover parameters from dialog box
LowScan = Dialog.getCheckbox();
CAMEnable = Dialog.getCheckbox();
Umanager = Dialog.getCheckbox();
AFDrift = Dialog.getCheckbox();
QuickView = Dialog.getCheckbox();
ZoomRatio = Dialog.getNumber();
QuickViewScale = Dialog.getNumber();
HighDisp = Dialog.getCheckbox();
Analysis = Dialog.getChoice();
OpenExperiment = Dialog.getCheckbox();
Resend = Dialog.getCheckbox();

if(OpenExperiment==true)
{
	waitForUser("Make sure the experiment montage is currently opened and active");
	ImagesSize = newArray(2);
	Str = getMetadata("Info");
	Str = split(Str,"\n");
	foundmeta = false;
	for(i=0;i<lengthOf(Str);i++)
	{
		if(substring(Str[i],0,8)=="xMontage")
		{
			xFields = parseInt(substring(Str[i],9,lengthOf(Str[i])));
			foundmeta = true;
		}
		if(substring(Str[i],0,8)=="yMontage")yFields = parseInt(substring(Str[i],9,lengthOf(Str[i])));
	}
	if(foundmeta == false)
	{
		xFields = getNumber("Could not find montage metadata, Number of x fields?",1);
		yFields = getNumber("Could not find montage metadata, Number of y fields?",1);
	}
	ImagesSize[0] = getWidth()/xFields;
	ImagesSize[1] = getHeight()/yFields;
	print("Montage image format: "+d2s(xFields,0)+" x "+d2s(yFields,0)+" , "+d2s(ImagesSize[0],0)+" x "+d2s(ImagesSize[1],0));
	FixedExperimentOpener(ExpPath,ImagesSize);
	exit("Experiment opened");
}

// Close all opened images
run("Close All");
run("Clear Results");

// Launch primary scan (low resolution)
if((LowScan==true)&&(Resend==false))
{
	// Generate the low resolution CAM script in log window
	LogWindowCloser();
	print("/cli:ipa-ws /app:matrix /cmd:startscan");
	if(Umanager == true)print("_endmessage_");
	selectWindow("Log");
	ScriptName1 = ExpPath+"CAMScript1.txt";
	
	// Save log window to file
	run("Text...", "save=["+ScriptName1+"]");
	run("Close");
	
	// Send CAM script
	if(CAMEnable==1)run("LASAFClient","filepath=["+ScriptName1+"] serverip="+LasafIP+" serverport="+LasafPort);
}

if(Resend==false)
{

// Find out images path (last folder in the experiment folder)
MyList 	= getFileList(ExpPath);
Array.sort(MyList);
for(i=0;i<lengthOf(MyList);i++)if(endsWith(MyList[i],"/"))ImagesPath = ExpPath+MyList[i];	

// Display the images (Filter = filter the images, "SCAN" = images montage)
ImagesSize=ParseAndDisplayImages(ImagesPath,Filter,"SCAN");

// Call to the automatic points selection function (it must return points selection)
eval("_"+Analysis+"("+d2s(ImagesSize[0],0)+");\n"+AnalysisFunctionsFile);
MontageID = getImageID();

run("Clear Results");
if(selectionType()==10)
{
	run("Set Measurements...", "centroid redirect=None decimal=2");
	run("Measure");
}

// QuickView montage around the selected positions
QuickViewID = 0;
if((QuickView==true)&&(nResults>0))
{
	getSelectionCoordinates(OriginalXCoordinates, OriginalYCoordinates);
	CurrentID = getImageID();
	run("Duplicate...", "title=Tmp");
	TmpID = getImageID();
	Lx = round(ImagesSize[0]/ZoomRatio);
	Ly = round(ImagesSize[1]/ZoomRatio);
	if(bitDepth==8)newImage("PositionsStack", "8-bit Black", Lx, Ly, nResults);
	if(bitDepth==16)newImage("PositionsStack", "16-bit Black", Lx, Ly, nResults);
	if(bitDepth==24)newImage("PositionsStack", "RGB Black", Lx, Ly, nResults);
	PositionsStackID = getImageID();
	setBatchMode(true);
	for(i=0;i<nResults;i++)
	{
		selectImage(TmpID);
		makeRectangle(getResult("X",i)-round(Lx/2),getResult("Y",i)-round(Ly/2),Lx,Ly);
		run("Copy");
		selectImage(PositionsStackID);
		setSlice(i+1);
		run("Paste");
	}
	selectImage(PositionsStackID);
	run("Select None");
	N = sqrt(nResults);
	if(N-floor(N)>0)N=floor(N)+1;
	if(N>1)run("Make Montage...", "columns="+d2s(N,0)+" rows="+d2s(N,0)+" scale="+d2s(QuickViewScale,0)+" first=1 last="+d2s(nResults,0)+" increment=1 border=0 font="+d2s(8*QuickViewScale,0)+" label");
	else run("Duplicate...", "title=Copy");
	rename("QuickView");
	QuickViewID = getImageID();
	selectImage(TmpID);
	close();
	selectImage(PositionsStackID);
	close();
	selectImage(CurrentID);
	setBatchMode("exit & display");
}

// User's selection/edition of the points of interest
if((QuickView==true)&&(Analysis!="None")&&(nResults>0))
{
	xpoints = newArray(nResults);
	ypoints = newArray(nResults);
	for(i=0;i<nResults;i++)
	{
		xpoints[i] = Lx*(QuickViewScale/2)+Lx*QuickViewScale*(i%N);
		ypoints[i] = Ly*(QuickViewScale/2)+Ly*QuickViewScale*(floor(i/N));		
	}
	selectImage("QuickView");
	makeSelection("point",xpoints,ypoints);
	/*
	if(bitDepth==24)
	{
		run("Make Composite", "display=Composite");
		run("Channels Tool... ");
	}
	*/
	waitForUser("You can remove unwanted positions on the quickview");
	getSelectionCoordinates(xCoordinates, yCoordinates);
	SelectionX = newArray(lengthOf(xCoordinates));
	SelectionY = newArray(lengthOf(xCoordinates));
	for(i=0;i<lengthOf(xCoordinates);i++)
	{
		SelectedPosition = round((xCoordinates[i]-Lx*(QuickViewScale/2))/(Lx*QuickViewScale)+N*round((yCoordinates[i]-Ly*(QuickViewScale/2))/(Ly*QuickViewScale)));
		SelectionX[i] = OriginalXCoordinates[SelectedPosition];
		SelectionY[i] = OriginalYCoordinates[SelectedPosition];
	}
	selectImage(MontageID);
	makeSelection("point",SelectionX,SelectionY);
}
else waitForUser("You can now edit the selected positions:\n \n - Left click to create a new point\n - Drag a point to move it\n - Alt+ left click to remove a point\n - Zoom with shift+up/down arrows\n - Hold space and drag the view to move around\n");

// Measure position of the points of interest
run("Clear Results");
run("Measure");

// Compute the X/Y offsets of the points of interest with respect to the well centers
if(selectionType!=-1)
{
xList = newArray(nResults);
yList = newArray(nResults);		
WellxList = newArray(nResults);
WellyList = newArray(nResults);
tPos = 0;
for(i=0;i<nResults;i++)
{
	if((getResult("X",i)>-1)&&(getResult("Y",i)>-1)&&(getResult("X",i)<getWidth())&&(getResult("Y",i)<getHeight()))
	{
		xList[tPos] = round(ImagesSize[0]/2)-(getResult("X",i)%ImagesSize[0]);
		yList[tPos] = round(ImagesSize[1]/2)-(getResult("Y",i)%ImagesSize[1]);
		WellxList[tPos] = floor(getResult("X",i)/ImagesSize[0])+1;
		WellyList[tPos] = floor(getResult("Y",i)/ImagesSize[1])+1;
		tPos++;
	}
}
////////////////////  /////////////////////////////////////////
aPos = getNumber("How many positions should be sent?",tPos);

// Generate the secondary scan CAM script in log window
LogWindowCloser();
print("/cli:ipa-ws /app:matrix /cmd:startscan");
print("/cli:ipa-ws /app:matrix /cmd:deletelist");
if(AFDrift == false)ext = "none";
else ext = "af";  
for(i=0;i<aPos;i++)
{
	offx = -xSign*xList[i];
	offy = -ySign*yList[i];
	if(xyFlip==1)print("/cli:ipa-ws /app:matrix /cmd:add /tar:camlist /exp:"+JobHigh+" /ext:"+ext+" /slide:0 /wellx:"+d2s(WellxList[i],0)+" /welly:"+d2s(WellyList[i],0)+" /fieldx:1 /fieldy:1 /dxpos:"+d2s(offy,0)+" /dypos:"+d2s(offx,0));
	else print("/cli:ipa-ws /app:matrix /cmd:add /tar:camlist /exp:"+JobHigh+" /ext:"+ext+" /slide:0 /wellx:"+d2s(WellxList[i],0)+" /welly:"+d2s(WellyList[i],0)+" /fieldx:1 /fieldy:1 /dxpos:"+d2s(offx,0)+" /dypos:"+d2s(offy,0));
}
print("/cli:ipa-ws /app:matrix /cmd:startcamscan /runtime:9999 /repeattime:9999"); // runtime is set to a large value since CAM list scan should stop only once fully done 
if(Umanager == true)
{
	print("_exit_");
	print("_endmessage_");	
}

// Write log window to file
selectWindow("Log");
ScriptName2 = ExpPath+"CAMScript2.txt";
run("Text...", "save=["+ScriptName2+"]");
run("Close");

// Send CAM script
if(CAMEnable==1)run("LASAFClient","filepath=["+ScriptName2+"] serverip="+LasafIP+" serverport="+LasafPort);
}

}
else if(CAMEnable==1)
{
	ScriptName2 = ExpPath+"CAMScript2.txt";
	run("LASAFClient","filepath=["+ScriptName2+"] serverip="+LasafIP+" serverport="+LasafPort);
}

// Find out images path (CAM folder inside the last folder inside the experiment folder)
MyList 	= getFileList(ExpPath);
Array.sort(MyList);
for(i=0;i<lengthOf(MyList);i++)
{
	if(endsWith(MyList[i],"/"))
	{
		FolderName = MyList[i];
		ImagesPath = ExpPath+FolderName;	
	}
}
MyList 	= getFileList(ImagesPath);
ImagesPathCAM = "";
for(i=0;i<lengthOf(MyList);i++)if((substring(MyList[i],0,3)=="CAM")&&(endsWith(MyList[i],"/")))ImagesPathCAM = ImagesPath+MyList[i];	

// Save montage to file
if(Resend==false)
{
	selectImage(MontageID);
	save(ExpPath+"Montage"+substring(FolderName,0,lengthOf(FolderName)-1)+".tif");
	if((QuickView==true)&&(QuickViewID>0))
	{
		selectImage(QuickViewID);
		save(ExpPath+"Quickview"+substring(FolderName,0,lengthOf(FolderName)-1)+".tif");
	}
}

if(ImagesPathCAM=="")
{
	showMessage("The images from the CAM list cannot be found");
	exit();
}

// Display images (Filter = filter the image)
if(HighDisp==true)ImagesSize=ParseAndDisplayImages(ImagesPathCAM,Filter,"");

print("AutoScanJ finished.");

///////////////////
//// Functions ////
///////////////////

// Close log window if opened
function LogWindowCloser()
{
	if(isOpen("Log"))
	{
		selectWindow("Log");
		run("Close");
	}
}

// Parse the analysis function file to retrieve the function names
// and register them to allow calls
function RegisterFunctions(FunctionsFile)
{
	AnalysisFunctionsRegistered = replace(FunctionsFile, "function _", "@");
	AnalysisFunctionsRegistered = split(AnalysisFunctionsRegistered,"@");
	AnalysisFunctions = newArray(lengthOf(AnalysisFunctionsRegistered)-1);
	for(i=1;i<lengthOf(AnalysisFunctionsRegistered);i++)
	{
		Buf = split(AnalysisFunctionsRegistered[i],"(");
		print("Registered function "+d2s(i,0)+": "+Buf[0]);
		AnalysisFunctions[i-1] = Buf[0];
	}
	return AnalysisFunctions;
}

// Parse filenames inside image folder to retrieve scan configuration (X/Y wells, z slices, channels) 
// Load the images and build projected, mixed, montage 
function ParseAndDisplayImages(LocalImagesPath,Filter,Mode)
{		
MyList 	= getFileList(LocalImagesPath);
xmax=0;ymax=0;zmax=0;cmax=0;xmin=99;ymin=99;
for(i=0;i<lengthOf(MyList);i++)
{
	if(endsWith(MyList[i],".ome.tif"))
	{
		OmeFields = split(MyList[i],"--");
		x=parseInt(substring(OmeFields[3],1,3));
		y=parseInt(substring(OmeFields[4],1,3));
		z=parseInt(substring(OmeFields[11],1,3));
		c=parseInt(substring(OmeFields[12],1,3));
		if(x>xmax)xmax=x;
		if(y>ymax)ymax=y;
		if(z>zmax)zmax=z;
		if(c>cmax)cmax=c;
		if(x<xmin)xmin=x;
		if(y<ymin)ymin=y;
	}
}
// Open images
run("Image Sequence...", "open=["+LocalImagesPath+"] starting=1 increment=1 scale=100 file=[] or=[]");
rename("Imported Sequence");
run("Grays");
ImagesSize=newArray(2);
ImagesSize[0]=getWidth();
ImagesSize[1]=getHeight();

// Optional filtering
if(Filter==1)run("Smooth", "stack");

// Mode SCAN: generate montage to build the primary scan map
if((Mode=="SCAN")||(Mode=="SINGLE"))
{
	NumZplanes = zmax+1;
	NumChannels = cmax+1;
	xPos = xmax+1-xmin;
	yPos = ymax+1-ymin;
	nPos = nSlices/(NumChannels*NumZplanes);
	
	// Print retrieved scan configuration
	print("Images read from folder: "+LocalImagesPath);
	print("Filtering: ",Filter);
	print("Number of z slices: ",NumZplanes);
	print("Number of channels: ",NumChannels);
	print("u wells width: ",xPos);
	print("v wells width: ",yPos);
	print("Number of positions: ",nPos);
	
	// Stack to hyperstack, maximum intensity z projection
	if((NumZplanes>1)||(NumChannels>1))
	{
		selectImage("Imported Sequence");
		run("Stack to Hyperstack...", "order=xyczt(default) channels="+d2s(NumChannels,0)+" slices="+d2s(NumZplanes,0)+" frames="+d2s(nPos,0)+" display=Composite");
		if(NumZplanes>1)
		{
			selectImage("Imported Sequence");
			run("Z Project...", "start=1 stop="+d2s(NumZplanes,0)+" projection=[Max Intensity] all");
			rename("Projection");
			selectImage("Imported Sequence");
			close();
			selectImage("Projection");
		}
	}
	rename("Processed sequence");
	
	// More than 1 channel: Convert composite to RGB image
	if(NumChannels>1)
	{
		run("Stack to RGB", "frames keep");
		rename("Merged");
		selectImage("Processed sequence");
		close();
		selectImage("Merged");	
		rename("Processed sequence");
	}
	
	// More than 1 well: build montage
	if((nPos>1)&&(Mode=="SCAN"))
	{
		selectImage("Processed sequence");
		if(nPos!=xPos*yPos) // Error in the configuration
		{
			print("Warning, the number of views do not match the number of wells!");
			yPos = floor(sqrt(nPos));
			xPos = floor(nPos/yPos)+(((nPos/yPos)%1)>0); 
		}
		// Re-shuffle the stack so that the images are ordered row by row instead of column by column
		if((xPos>1)&&(yPos>1))
		{
			run("Stack to Hyperstack...", "order=xyctz channels=1 slices="+d2s(xPos,0)+" frames="+d2s(yPos,0)+" display=Grayscale");
			selectImage("Processed sequence");
			run("Hyperstack to Stack");
		}
		selectImage("Processed sequence");
		run("Make Montage...", "columns="+d2s(xPos,0)+" rows="+d2s(yPos,0)+" scale=1 first=1 last="+d2s(nPos,0)+" increment=1 border=0 font=12");
		rename("Montage");
		selectImage("Processed sequence");
		close();
	}
	else rename("Montage");
}

// Remove scale
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
return ImagesSize;

}

// Open past CAM experiment
function FixedExperimentOpener(ExpPath,ImagesSize)
{	
	if(selectionType()>-1)
	{
	run("Clear Results");
	run("Measure");

	WellxList = newArray(nResults);
	WellyList = newArray(nResults);
	WellIndex = newArray(nResults);
	NbWellx = (getWidth()/ImagesSize[0]);
	NbWelly = (getHeight()/ImagesSize[1]);
	WellIndexCnt = newArray(NbWellx*NbWelly);
	tPos = 0;

	for(i=0;i<nResults;i++)
	{
		if((getResult("X",i)>-1)&&(getResult("Y",i)>-1)&&(getResult("X",i)<getWidth())&&(getResult("Y",i)<getHeight()))
		{
			WellxList[tPos] = floor(getResult("X",i)/ImagesSize[0])+1;
			WellyList[tPos] = floor(getResult("Y",i)/ImagesSize[1])+1;
			WellIndex[tPos] = WellIndexCnt[WellxList[tPos]-1+(WellyList[tPos]-1)*NbWellx];
			WellIndexCnt[WellxList[tPos]-1+(WellyList[tPos]-1)*NbWellx] = WellIndexCnt[WellxList[tPos]-1+(WellyList[tPos]-1)*NbWellx]+1;
			tPos++;
		}
	}
	
	Positions = "";
	for(i=0;i<nResults;i++)Positions = Positions+d2s(i+1,0)+"-";
	str = getString("Please specify the positions you would like to open", Positions);
	PositionsToOpen = split(str,"-");
		
	MyList = getFileList(ExpPath);
	Array.sort(MyList);
	for(i=0;i<lengthOf(MyList);i++)
	{
		if(endsWith(MyList[i],"/"))
		{
			FolderName = substring(MyList[i],0,lengthOf(MyList[i])-1);
			ImagesPath = ExpPath+MyList[i];
			MyList2 = getFileList(ImagesPath);
			for(j=0;j<lengthOf(MyList2);j++)if((substring(MyList2[j],0,3)=="CAM")&&(endsWith(MyList2[j],"/")))ImagesPathCAM = ImagesPath+MyList2[j];		
		}
	}

	for(i=0;i<lengthOf(PositionsToOpen);i++)
	{
		j = parseInt(PositionsToOpen[i])-1;
		Wellx = IJ.pad(WellxList[j]-1,2);
		Welly = IJ.pad(WellyList[j]-1,2);	
		if(WellIndex[j]==0)
		{
			Filter = ".*U"+Wellx+"--V"+Welly+".*--C[0-9][0-9].ome.tif";
			print("Accesing "+Filter);
			run("Image Sequence...", "open=["+ImagesPathCAM+"] number=9999 starting=1 increment=1 scale=100 file=[] or="+Filter+" sort");
			rename("Position "+d2s(j+1,0));
			run("Grays");
		}
		else 
		{
			Index=IJ.pad(WellIndex[j],3);
			Filter = ".*U"+Wellx+"--V"+Welly+".*--C[0-9][0-9]--"+Index+".ome.tif";
			print("Accesing "+Filter);
			run("Image Sequence...", "open=["+ImagesPathCAM+"] number=9999 starting=1 increment=1 scale=100 file=[] or="+Filter+" sort");
			rename("Position "+d2s(j+1,0));
			run("Grays");
		}

	}
}