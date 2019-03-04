//////////////////////////////////////////////////////////////////////////////////////////////////
//
// Name:	FixedSample_Blocks
// Author: 	Sebastien Tosi (IRB/ADMCF)
// Date:	09-11-2012	
//			   
// Similar to FixedSample_Tiling but the wells (UV) are opened independently.
// For each well all the subpositions (XY) are opened and tiled before being processed sequentially 
// to find targets. A single high resolution scan is triggered 
// once the grid of wells defined in the dialog box has been completely processed. 
// Possible application: Cytoo chip scan.
//
// SP5 config:          	xyFlip = 1 xSign = -1 ySign = 1
// Micro-Manager config:     	xyFlip = 0 xsign = 1 ySign = 1
//
//////////////////////////////////////////////////////////////////////////////////////////////////

// Default parameters for the microscope configuration //////////
xyFlip = 0; //0	
xSign = 1; //1	
ySign = 1;  //1	
DefaultLasafIP = "127.0.0.1";
DefaultLasafPort = 8895;
DefaultJobHigh = "Job high";
AnalysisFunctionsPath = getDirectory("macros")+"AnalysisFunctions_Fixed_Blocks.ijm";
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
Dialog.create("FixedSample_Blocks setup");
Dialog.addMessage("Server configuration");
Dialog.addString("Server IP", DefaultLasafIP);
Dialog.addNumber("Server port", DefaultLasafPort);
Dialog.addString("Name of job for high resolution scan", DefaultJobHigh);
Dialog.addMessage("Scans");
Dialog.addCheckbox("Perform low resolution scan?", true);
Dialog.addCheckbox("Send CAM script?", true);
Dialog.addCheckbox("Micro-manager mode?", true);
Dialog.addMessage("Processing");
Dialog.addCheckbox("Display quick view montage?", false);
Dialog.addNumber("QuickView high/low zoom ratio", 10);
Dialog.addNumber("QuickView scale", 1);
Dialog.addMessage("Analysis");
Dialog.addChoice("Automatic pre-analysis",AnalysisFunctions,"Cytoo_Mitosis_SP5");
Dialog.addNumber("Block start row   ", 0);
Dialog.addNumber("Block start col   ", 0);
Dialog.addNumber("Block end row     ", 1);
Dialog.addNumber("Block end col     ", 1);
Dialog.show();

// Recover parameters from dialog box
LasafIP = Dialog.getString();
LasafPort = Dialog.getNumber();
JobHigh = Dialog.getString();
LowScan = Dialog.getCheckbox();
CAMEnable = Dialog.getCheckbox();
Umanager = Dialog.getCheckbox();
QuickView = Dialog.getCheckbox();
ZoomRatio = Dialog.getNumber();
QuickViewScale = Dialog.getNumber();
Analysis = Dialog.getChoice();
BlockStartRow = Dialog.getNumber();
BlockStartCol = Dialog.getNumber();
BlockEndRow = Dialog.getNumber();
BlockEndCol = Dialog.getNumber();

// Close all opened images
run("Close All");
run("Clear Results");

// Launch primary scan (low resolution)
if(LowScan==1)
{
	showMessage("Launch the low resolution scan? \n \nMake sure the main scan is correctly set!");

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

Test = File.delete(ExpPath+"CAMScript2.txt");
for(BlockXInd = BlockStartCol ;BlockXInd<BlockEndCol+1;BlockXInd++)
{
for(BlockYInd = BlockStartRow ;BlockYInd<BlockEndRow+1;BlockYInd++)
{

// Find out images path (last folder in the experiment folder)
MyList 	= getFileList(ExpPath);
Array.sort(MyList);
for(i=0;i<lengthOf(MyList);i++)if(endsWith(MyList[i],"/"))ImagesPath = ExpPath+MyList[i];	

// Display the images ("SCAN" = images montage)
ImagesSize=ParseAndDisplayImages(ImagesPath,"SCAN",BlockXInd,BlockYInd);

// Call to the automatic points selection function (it must return points selection)
eval("_"+Analysis+"("+d2s(ImagesSize[0],0)+","+d2s(BlockXInd,0)+","+d2s(BlockYInd,0)+","+d2s(BlockStartCol,0)+","+d2s(BlockStartRow,0)+");\n"+AnalysisFunctionsFile);

run("Clear Results");
if(selectionType()==10)
{
	run("Set Measurements...", "centroid redirect=None decimal=2");
	run("Measure");
}

// QuickView montage around the selected positions
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
	selectImage("Montage");
	makeSelection("point",SelectionX,SelectionY);
	selectImage("QuickView");
	close();
}
else 
{
	//waitForUser("You can now edit the selected positions:\n \n - Left click to create a new point\n - Drag a point to move it\n - Alt+ left click to remove a point\n - Zoom with shift+up/down arrows\n - Hold space and drag the view to move around\n");
	wait(1000);
}

// Measure position of the points of interest
run("Clear Results");
run("Measure");

// Compute the X/Y offsets of the points of interest with respect to the well centers
if(selectionType!=-1)
{
xList = newArray(nResults);
yList = newArray(nResults);		
FieldxList = newArray(nResults);
FieldyList = newArray(nResults);
tPos = 0;

for(i=0;i<nResults;i++)
{
	if((getResult("X",i)>-1)&&(getResult("Y",i)>-1)&&(getResult("X",i)<getWidth())&&(getResult("Y",i)<getHeight()))
	{
		xList[tPos] = round(ImagesSize[0]/2)-(getResult("X",i)%ImagesSize[0]);
		yList[tPos] = round(ImagesSize[1]/2)-(getResult("Y",i)%ImagesSize[1]);
		FieldxList[tPos] = floor(getResult("X",i)/ImagesSize[0])+1;
		FieldyList[tPos] = floor(getResult("Y",i)/ImagesSize[1])+1;
		tPos++;
	}
}

// Generate the secondary scan CAM script
if ((BlockXInd==0)&&(BlockYInd==0))
{
	File.append("/cli:ipa-ws /app:matrix /cmd:startscan\r", ExpPath+"CAMScript2.txt");
	File.append("/cli:ipa-ws /app:matrix /cmd:deletelist\r", ExpPath+"CAMScript2.txt");
}
for(i=0;i<tPos;i++)
{
	offx = -xSign*xList[i];
	offy = -ySign*yList[i];
	if(xyFlip==1)File.append("/cli:ipa-ws /app:matrix /cmd:add /tar:camlist /exp:"+JobHigh+" /ext:none /slide:0 /wellx:"+d2s(BlockXInd+1,0)+" /welly:"+d2s(BlockYInd+1,0)+" /fieldx:"+d2s(FieldxList[i],0)+" /fieldy:"+d2s(FieldyList[i],0)+" /dxpos:"+d2s(offy,0)+" /dypos:"+d2s(offx,0)+"\r", ExpPath+"CAMScript2.txt");
	else File.append("/cli:ipa-ws /app:matrix /cmd:add /tar:camlist /exp:"+JobHigh+" /ext:none /slide:0 /wellx:"+d2s(BlockXInd+1,0)+" /welly:"+d2s(BlockYInd+1,0)+" /fieldx:"+d2s(FieldxList[i],0)+" /fieldy:"+d2s(FieldyList[i],0)+" /dxpos:"+d2s(offx,0)+" /dypos:"+d2s(offy,0)+"\r", ExpPath+"CAMScript2.txt");
}

}

selectImage("Montage");
saveAs("Tiff", ExpPath+"Montage_U"+IJ.pad(BlockXInd,2)+"--V"+IJ.pad(BlockYInd,2)+".tif");
close();

}
}
File.append("/cli:ipa-ws /app:matrix /cmd:startcamscan /runtime:9999 /repeattime:9999\r", ExpPath+"CAMScript2.txt");
if(Umanager == true)
{	
	File.append("_exit_\r", ExpPath+"CAMScript2.txt");
	File.append("_endmessage_\r", ExpPath+"CAMScript2.txt");
}

// Send CAM script
if(CAMEnable==1)
{
	//showMessage("Launch the high resolution scan? \n \nYou can assign a dummy job to the scan");
	ScriptName2 = ExpPath+"CAMScript2.txt";
	run("LASAFClient","filepath=["+ScriptName2+"] serverip="+LasafIP+" serverport="+LasafPort);
}

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
function ParseAndDisplayImages(LocalImagesPath,Mode,ForceUWell,ForceVWell)
{		
MyList 	= getFileList(LocalImagesPath);
xmax=0;ymax=0;zmax=0;cmax=0;
for(i=0;i<lengthOf(MyList);i++)
{
	if(endsWith(MyList[i],".ome.tif"))
	{
		OmeFields = split(MyList[i],"--");
		x=parseInt(substring(OmeFields[8],1,3));
		y=parseInt(substring(OmeFields[9],1,3));
		z=parseInt(substring(OmeFields[11],1,3));
		c=parseInt(substring(OmeFields[12],1,3));
		if(x>xmax)xmax=x;
		if(y>ymax)ymax=y;
		if(z>zmax)zmax=z;
		if(c>cmax)cmax=c;
	}
}
xPos = xmax+1;
yPos = ymax+1;
nPos = xPos*yPos;
NumZplanes = zmax+1;
NumChannels = cmax+1;

// Open images
filter = "U"+IJ.pad(ForceUWell,2)+"--V"+IJ.pad(ForceVWell,2);
run("Image Sequence...", "open=["+LocalImagesPath+"] number="+d2s(nPos*NumZplanes*NumChannels,0)+" starting=1 increment=1 scale=100 file="+filter+" or=[] sort");
rename("Imported Sequence");
run("Grays");

ImagesSize=newArray(2);
ImagesSize[0]=getWidth();
ImagesSize[1]=getHeight();

// Mode SCAN: generate montage to build the primary scan map
if((Mode=="SCAN")||(Mode=="SINGLE"))
{
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
		for(i=0;i<NumChannels;i++)
		{
			Stack.setChannel(i+1);
			resetMinAndMax();
		}
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
