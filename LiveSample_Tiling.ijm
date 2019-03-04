/////////////////////////////////////////////////////////////////////////////////////////////////
//
// Name:	LiveSample_Tiling
// Author: 	Sebastien Tosi (IRB/ADMCF)
// Date:	06-10-2011	
//		          
//////////////////////////////////////////////////////////////////////////////////////////////////

// Default parameters for the microscope configuration //////////
xyFlip = 0; // Invert x and y axis (field of view rotation > 90 degree) 
xSign = 1; // x axis direction
ySign = 1;  // y axis direction
LasafIP = "127.0.0.1";
LasafPort = 8895;
JobHigh = "Job high";
AnalysisFunctionsPath = getDirectory("macros")+"AnalysisFunctions_Live_Tiling.ijm";
///// Used fro debugging with local images only /////////
OfflineFilesPath = "..."; // Only required for debugging
JString = "J00";
OfflineZ = 3;
OfflineX = 3;
OfflineY = 2;
////////////////////////////////////////////////////////////////////////////////////////////////

// Initialization
run("Options...", "iterations=1 count=1 edm=Overwrite");

// Store analysis functions to string
if(File.exists(AnalysisFunctionsPath))AnalysisFunctionsFile = File.openAsString(AnalysisFunctionsPath);
else exit("Could not find the analysis functions file,\nplease check the path to the file");
AnalysisFunctions = RegisterFunctions(AnalysisFunctionsFile);
	
// Macro parameters dialog box
ExpPath = getDirectory("Path to the LASAF experiment folder");
Dialog.create("AutoScanJ LiveSample_Tiling");
Dialog.addMessage("Scans");
Dialog.addNumber("Primary scan Ncols", 3);
Dialog.addNumber("Primary scan Nrows", 2);
Dialog.addNumber("Max. rep. for primary scan", 10);
Dialog.addNumber("Repetition period 1 (sec)", 5);
Dialog.addNumber("Secondary scan repetitions", 10);
Dialog.addNumber("Repetition period 2 (sec)", 120);
Dialog.addCheckbox("Send CAM script? If disabled, use offline mode", true);
Dialog.addCheckbox("Micro-manager mode", true);
Dialog.addMessage("Analysis");
Dialog.addChoice("Automatic pre-analysis",AnalysisFunctions,"Mitosis_Microtubulin");
Dialog.addCheckbox("Only open past live CAM experiment", false);
Dialog.show();

// Recover parameters from dialog box
NbWellsX = Dialog.getNumber();
NbWellsY = Dialog.getNumber();
MaxNbRepetitionLow = Dialog.getNumber();
RepetitionPeriodLow = Dialog.getNumber();
NbRepetitionHigh = Dialog.getNumber(); 
RepetitionPeriodHigh = Dialog.getNumber();
CAMEnable = Dialog.getCheckbox();
Umanager = Dialog.getCheckbox();
Analysis = Dialog.getChoice();
OpenExperiment = Dialog.getCheckbox();

// Close all opened images
run("Close All");

if(OpenExperiment==true)
{
	LiveExperimentOpener(ExpPath);
	exit("Experiment opened");
}

LastTime = 0;
StartTime = getTime();
if(File.exists(ExpPath+"\\T_1_Frame.tif"))File.delete(ExpPath+"\\T_1_Frame.tif");
if(File.exists(ExpPath+"\\T_2_Frame.tif"))File.delete(ExpPath+"\\T_2_Frame.tif");
for(Iter=0;Iter<MaxNbRepetitionLow;Iter++)
{ 
	// Primary scan timer
	print("Waiting for next primary scan...");
	while((getTime()-LastTime)/1000<RepetitionPeriodLow)wait(100);
	LastTime = getTime();
	
	// Generate primary scan script in log window
	LogWindowCloser();
	// Enable all wells
	for(i=1;i<=NbWellsX;i++)for(j=1;j<=NbWellsY;j++)print("/cli:ipa-ws /app:matrix /cmd:enable /slide:0 /wellx:"+d2s(i,0)+" /welly:"+d2s(j,0)+" /fieldx:0 /fieldy:0 /value:true");	
	print("/cli:ipa-ws /app:matrix /cmd:startscan");
	if(Umanager == true)print("_endmessage_");
	selectWindow("Log");
	ScriptName1 = ExpPath+"CAMScript.txt";
	// Save log window to file
	run("Text...", "save=["+ScriptName1+"]");
	run("Close");
	// Send CAM script
	if(CAMEnable==1)run("LASAFClient","filepath=["+ScriptName1+"] serverip="+LasafIP+" serverport="+LasafPort);
	else FetchNewTimePoint(ExpPath,Iter,OfflineFilesPath); // Offline mode - debugging

	// Find out images path (last folder in the experiment folder)
	MyList = getFileList(ExpPath);
	Array.sort(MyList);
	for(i=0;i<lengthOf(MyList);i++)
	{
		if(endsWith(MyList[i],"/"))
		{
			FolderName = substring(MyList[i],0,lengthOf(MyList[i])-1);
			ImagesPath = ExpPath+MyList[i];
		}
	}

	// Display the images as a projected, composite montage
	run("Close All");
	ImagesSize=ParseAndDisplayImages(ImagesPath,0,"SCAN");
	rename("CurrentFrame.tif");
	CurrentFrameID = getImageID();
	
	SecondaryScanPerformed = false;
	if((File.exists(ExpPath+"\\T_1_Frame.tif"))&&(File.exists(ExpPath+"\\T_2_Frame.tif")))
	{
	open(ExpPath+"\\T_1_Frame.tif");
	open(ExpPath+"\\T_2_Frame.tif");
	File.delete(ExpPath+"\\T_2_Frame.tif");
	File.rename(ExpPath+"\\T_1_Frame.tif",ExpPath+"\\T_2_Frame.tif");
	selectImage("CurrentFrame.tif");
	save(ExpPath+"\\T_1_Frame.tif");
	run("Concatenate...", "  title=[Concatenated Stacks] image1=T_2_Frame.tif image2=T_1_Frame.tif image3=CurrentFrame.tif image4=[-- None --]");

	// Call to the automatic points selection function (it must return points selection)
	eval("_"+Analysis+"("+d2s(ImagesSize[0],0)+","+d2s(ImagesSize[1],0)+");\n"+AnalysisFunctionsFile);
	
	run("Clear Results");
	run("Measure");

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

		// Save snapshot of detected event
		run("Enlarge...", "enlarge=32");
		run("Duplicate...", "title=Copy duplicate range=1-3");
		CopyID = getImageID(); 
		run("Select None");
		saveAs("Tiff", ExpPath+"Detected_"+d2s(Iter,0)+".tif");
		//selectImage("Detected_"+d2s(Iter,0)+".tif");
		selectImage(CopyID);
		close();

		// Generate the secondary scan CAM script in log window
		LogWindowCloser();
		for(i=1;i<=NbWellsX;i++)for(j=1;j<=NbWellsY;j++)print("/cli:ipa-ws /app:matrix /cmd:enable /slide:0 /wellx:"+d2s(i,0)+" /welly:"+d2s(j,0)+" /fieldx:0 /fieldy:0 /value:false");
		for(i=0;i<tPos;i++)print("/cli:ipa-ws /app:matrix /cmd:enable /slide:0 /wellx:"+d2s(WellxList[i],0)+" /welly:"+d2s(WellyList[i],0)+" /fieldx:0 /fieldy:0 /value:true");
		print("/cli:ipa-ws /app:matrix /cmd:deletelist");
		for(i=0;i<tPos;i++)
		{
			offx = -xSign*xList[i];
			offy = -ySign*yList[i];
			if(xyFlip==1)print("/cli:ipa-ws /app:matrix /cmd:add /tar:camlist /exp:"+JobHigh+" /ext:none /slide:0 /wellx:"+d2s(WellxList[i],0)+" /welly:"+d2s(WellyList[i],0)+" /fieldx:1 /fieldy:1 /dxpos:"+d2s(offy,0)+" /dypos:"+d2s(offx,0));
			else print("/cli:ipa-ws /app:matrix /cmd:add /tar:camlist /exp:"+JobHigh+" /ext:none /slide:0 /wellx:"+d2s(WellxList[i],0)+" /welly:"+d2s(WellyList[i],0)+" /fieldx:1 /fieldy:1 /dxpos:"+d2s(offx,0)+" /dypos:"+d2s(offy,0));
		}
		print("/cli:ipa-ws /app:matrix /cmd:startscan");
		print("/cli:ipa-ws /app:matrix /cmd:startcamscan /runtime:"+d2s(NbRepetitionHigh*RepetitionPeriodHigh,0)+" /repeattime:"+d2s(RepetitionPeriodHigh,0)); 
		if(Umanager == true)print("_endmessage_");
		
		// Write log window to file
		selectWindow("Log");
		ScriptName2 = ExpPath+"CAMScript_"+d2s(Iter,0)+"_"+FolderName+".txt";
		run("Text...", "save=["+ScriptName2+"]");
		run("Close");

		// Send CAM script
		if(CAMEnable==1)run("LASAFClient","filepath=["+ScriptName2+"] serverip="+LasafIP+" serverport="+LasafPort);
		else wait(2000); // Offline debugging

		// Clean up images buffer
		SecondaryScanPerformed = true;
		File.delete(ExpPath+"\\T_1_Frame.tif");
		File.delete(ExpPath+"\\T_2_Frame.tif");
	}
	}
	else
	{
		if(File.exists(ExpPath+"\\T_1_Frame.tif"))File.rename(ExpPath+"\\T_1_Frame.tif",ExpPath+"\\T_2_Frame.tif");
		selectImage("CurrentFrame.tif");
		save(ExpPath+"\\T_1_Frame.tif");
	}

	print("Loop count: "+d2s(Iter+1,0)+"/"+d2s(MaxNbRepetitionLow,0));
	if(!SecondaryScanPerformed)
	{
		if((getTime()-LastTime)/1000>RepetitionPeriodLow)exit("Error: repetition time exceeded by "+d2s((getTime()-LastTime)/1000,0)+" seconds");
	}
	else LastTime = 0;

	print("End of experiment: "+d2s((getTime()-StartTime)/1000,0)+"/"+d2s(MaxNbRepetitionLow*RepetitionPeriodLow,0));
	if((getTime()-StartTime)/1000>MaxNbRepetitionLow*RepetitionPeriodLow)
	{
		if(Umanager == true)
		{
			LogWindowCloser();
			print("_exit_");
			print("_endmessage_");	
			// Write log window to file
			selectWindow("Log");
			ScriptName3 = ExpPath+"CAMExitScript.txt";
			run("Text...", "save=["+ScriptName3+"]");
			run("Close");
			if(CAMEnable==1)run("LASAFClient","filepath=["+ScriptName3+"] serverip="+LasafIP+" serverport="+LasafPort);
			else wait(2000); // Offline debugging
		}
		exit("End of experiment");
		print("AutoScanJ finished.");
	}
}

if(Umanager == true)
{
	LogWindowCloser();
	print("_exit_");
	print("_endmessage_");	
	// Write log window to file
	selectWindow("Log");
	ScriptName3 = ExpPath+"CAMExitScript.txt";
	run("Text...", "save=["+ScriptName3+"]");
	run("Close");
	if(CAMEnable==1)run("LASAFClient","filepath=["+ScriptName3+"] serverip="+LasafIP+" serverport="+LasafPort);
	else wait(2000); // Offline debugging
}
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
		OmeFields = split(MyList[i],'--');
		x=parseInt(substring(OmeFields[3],1));
		y=parseInt(substring(OmeFields[4],1));
		z=parseInt(substring(OmeFields[11],1));
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
	else 
	{
		selectImage("Processed sequence");
		rename("Single position");
	}
}

// Remove scale
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
return ImagesSize;

}

// Open past CAM experiment
function LiveExperimentOpener(ExpPath)
{
	MyList = getFileList(ExpPath);
	Array.sort(MyList);
	TimeFrame = 1;
	for(i=0;i<lengthOf(MyList);i++)
	{
		if(endsWith(MyList[i],"/"))
		{
			FolderName = substring(MyList[i],0,lengthOf(MyList[i])-1);
			ImagesPath = ExpPath+MyList[i];
			ImagesSize=ParseAndDisplayImages(ImagesPath,0,"SCAN");
			if(isOpen("Montage"))
			{
				if(isOpen("Concatenated Slices"))run("Concatenate...", "  title=[Concatenated Slices] image1=[Concatenated Slices] image2=[Montage] image3=[-- None --]");
				else rename("Concatenated Slices");
				TimeFrame++;
			}
			else
			{
				selectImage("Single position");
				close();
				MyList2 = getFileList(ImagesPath);
				for(j=0;j<lengthOf(MyList2);j++)if((substring(MyList2[j],0,3)=="CAM")&&(endsWith(MyList2[j],"/")))ImagesPathCAM = ImagesPath+MyList2[j];	
				ImagesSize=ParseAndDisplayImages(ImagesPathCAM,0,"SINGLE");
				selectImage("Single position");
				rename("Event starting at frame "+d2s(TimeFrame,0));
			}
			wait(250);
		}
	}
}

// Offline loading of images from a non CAM movie (for analysis function design)
function FetchNewTimePoint(ExpPath,Iter,FilesPath)
{
	File.makeDirectory(ExpPath+"scan_time_"+IJ.pad(d2s(Iter,0),4));
	ScanPath = ExpPath+"scan_time_"+IJ.pad(d2s(Iter,0),4)+"\\";
	for(i=0;i<OfflineX;i++)
	{
	for(j=0;j<OfflineY;j++)
	{
	for(k=0;k<OfflineZ;k++)
	{
		u = IJ.pad(d2s(i,0),2);
		v = IJ.pad(d2s(j,0),2);
		z = IJ.pad(d2s(k,0),2);
		t = IJ.pad(d2s(Iter,0),4);
		ImageName = "image--L"+t+"--S00--U"+u+"--V"+v+"--"+JString+"--E00--O00--X00--Y00--T"+t+"--Z"+z+"--C00.ome.tif";
		print(FilesPath+"\\"+ImageName);
		print(ScanPath+"\\"+ImageName);
		exec("cmd", "/c", "copy",FilesPath+"\\"+ImageName,ScanPath+ImageName);
	}
	}
	}
}