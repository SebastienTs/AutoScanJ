///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	Cytoo_Mitosis_SP5: Optimized for confocal images (SP5) 
//			   20x air lens, zoom = 1, 1024x1024, Pinhole = 3 airy, 3 Z planes (2 um spacing)
//	channel1: DNA (DAPI)	channel2: Auxiliary	channel3:  Cytoo patterns
//	Pattern detection: Strong Gaussian blur + regional maxima detection (Alternative: normalized cross-correlation based detection)
//	Targets: Isolated nucleus on Cytoo pattern
//
//	CytooL_Mitosis_widefield: Optimized for widefield images (AF7000) - 20x air lens, binning = 1, 1 Z plane
//	channel1: Cytoo patterns	channel2: DNA (DAPI)	channel3: Tubulin
//	Pattern detection: Threshold + particle analysis
//	Targets:
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function _None(ImagesSize,BlockXInd,BlockYInd,BlockStartRow,BlockStartCol)
{
	run("Point Tool...", "mark=0 label selection=yellow");
	setTool("multipoint");
}

function _Cytoo_Isolated_Nucleus_Confocal(ImagesSize,BlockXInd,BlockYInd,BlockStartRow,BlockStartCol)
{	
	DebugMode = 1; // 0 --> none, 1 --> last step (selected cells), 2 --> all steps
	
	MinNucArea = 50;
	NucLapSmooth = 4;
	AnalysisRad = 30;
	NucThr = -12;
	
	// Configuration
	OriginalID = getImageID();
	run("Duplicate...", "title=LowResolutionMontage");
	CopyID = getImageID();
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
	run("Set Measurements...", "centroid redirect=None decimal=2");
	TempFolder = getDirectory("temp");
	// Calibrate / save / load calibration
	if((BlockXInd==BlockStartCol)&&(BlockYInd==BlockStartRow))
	{
		setTool("rectangle");
		waitForUser("Block ROI (outside cropped)");
		getBoundingRect(XStart, YStart, Width, Height);
		//XStart = 228;YStart = 243;Width = 1560;Height = 1560;
		run("Select None");
		setTool("oval");
		waitForUser("Select the ROI of a pattern (used for area measurement only)");
		getStatistics(PatternArea, mean, min, max);
		//PatternArea = 9000;
		Str = d2s(XStart,0)+"--"+d2s(YStart,0)+"--"+d2s(Width,0)+"--"+d2s(Height,0)+"--"+d2s(PatternArea,0);
		Test = File.delete(TempFolder+"//CytooConfig.txt");
		Test = File.append(Str, TempFolder+"//CytooConfig.txt");
	}
	else
	{
		Str = File.openAsString(TempFolder+"//CytooConfig.txt");
		StrArr = split(Str,"--");
		XStart = parseInt(StrArr[0]);YStart = parseInt(StrArr[1]);Width = parseInt(StrArr[2]);Height = parseInt(StrArr[3]);PatternArea = parseInt(StrArr[4]);
	}
	PatternRadius = sqrt(PatternArea/PI);
	makeRectangle(XStart, YStart, Width, Height);
	run("Crop");

	// Split channels
	run("Make Composite", "display=Composite");
	CompositeID = getImageID();
	run("Duplicate...", "title=Nuclei duplicate channels=1");
	run("Grays");
	NucleiID = getImageID();
	selectImage(CompositeID);
	run("Duplicate...", "title=Auxiliary duplicate channels=2");
	run("Grays");
	AuxiliaryID = getImageID();
	selectImage(CompositeID);
	run("Duplicate...", "title=Patterns duplicate channels=3");
	run("Grays");
	PatternsID = getImageID();

	// Patterns detection
	selectImage(PatternsID);
	rename("Patterns");
	run("Gaussian Blur...", "sigma="+d2s(PatternRadius/2,0));
	// Find maxima
	run("Find Maxima...", "noise=1 output=[Single Points] exclude");
	PatternCentersID = getImageID();
	run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 show=Nothing clear add");
	selectImage(PatternsID);
	close();
	selectImage(PatternCentersID);
	close();
	
	// Only keep patterns which are in line with at least 2 other patterns along a row AND a column
	RoisOnGrid2(PatternRadius/4,3);
	if(DebugMode==2)
	{
		selectImage(CompositeID);
		roiManager("Show All");
		waitForUser("Debug Mode: Detected patterns");
	}
	selectImage(CompositeID);
	close();
	
	// Store pattern center positions to array
	run("Clear Results");
	roiManager("Measure");
	PattPosX = newArray(nResults);
	PattPosY = newArray(nResults);
	for(i=0;i<nResults;i++)
	{
		PattPosX[i] = getResult("X",i);
		PattPosY[i] = getResult("Y",i);	
	}

	// Loop over detected positions
	ValPattPosX = newArray(roiManager("count"));
	ValPattPosY = newArray(roiManager("count"));
	CntPos = 0;
	selectImage(NucleiID);
	run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=10 mask=*None* fast_(less_accurate)");
	run("FeatureJ Laplacian", "compute smoothing="+d2s(NucLapSmooth,2));
	
	//LapID = getImageID();
	//run("Find Maxima...", "noise=0.75 output=[Single Points] exclude light"); // Alternative
	
	run("Invert");
	run("Select None");
	run("8-bit");
	run("Auto Local Threshold", "method=Mean radius="+d2s(AnalysisRad,0)+" parameter_1="+d2s(NucThr,0)+" parameter_2=0 white");
	run("Invert LUT");
	run("Fill Holes");
	run("Watershed");
	run("Analyze Particles...", "size="+d2s(MinNucArea,0)+"-Infinity circularity=0.00-1.00 show=Masks exclude in_situ");
	run("Ultimate Points");
	setThreshold(1,255);
	run("Convert to Mask");
	run("Invert");
	rename("NucleiCenters");
	NucleiCentersID = getImageID();
	
	if(DebugMode==2)setForegroundColor(2552,255,255);
	
	CntValPos = 0;
	for(i=0;i<lengthOf(PattPosX);i++)
	{
		makeOval(PattPosX[i]-PatternRadius, PattPosY[i]-PatternRadius, PatternRadius*2, PatternRadius*2);
		getStatistics(area, mean, min, max, std, histogram);
		Nnuclei = histogram[0];
		if(Nnuclei==1)
		{
			if(DebugMode>0)run("Draw");
			ValPattPosX[CntValPos] = XStart+PattPosX[i];
			ValPattPosY[CntValPos] = YStart+PattPosY[i];
			CntValPos++;
		}	
	}
	selectImage(NucleiID);
	run("Add Image...", "image=NucleiCenters x=0 y=0 opacity=30");
	if(DebugMode>0)waitForUser("Debug Mode: Isolated cells");
	
	// Cleanup
	close();
	selectImage(NucleiCentersID);
	close();
	//selectImage(LapID);
	//close();	
	selectImage(AuxiliaryID);
	close();

	// Define final selection
	selectImage(OriginalID);
	for(i=0;i<CntValPos;i++)
	{
		makePoint(ValPattPosX[i],ValPattPosY[i]);
		setKeyDown("shift");
	}
}

// Isolated nuclei + check tubulin threshold
function _CytooL_Isolated_Metaphase_Widefield(ImagesSize,BlockXInd,BlockYInd,BlockStartRow,BlockStartCol)
{	
	DebugMode = 1;  // 0 --> none, 1 --> last step (selected cells), 2 --> all steps
	
	// Pattern spacing is 100 um (medium), block spacing is 1300 um.
	// Scale = 1 --> optimized for 20x lens, 6.5 um CCD pixel size
	Scale = 1;
	
	// Patterns detection and analysis
	PatternLengthTolerance = 0.2; //(relative)
	PatternLengthExtension = 1.2; //(relative)

	// DNA and tubulin local threshold
	LocalThrRadius = 30;
	LocalThrLevel = -5;

	// DNA and tubulin geometry	
	CondensedDNAAreaMin = 500*(Scale*Scale);
	CondensedDNAAreaMax = 1500*(Scale*Scale);
	TubulinMitosisAreaMin = 500*(Scale*Scale);
	TubulinMitosisAreaMax = 1500*(Scale*Scale);	
	
	// Configuration
	OriginalID = getImageID();
	TempFolder = getDirectory("temp");
	run("Set Measurements...", "area centroid bounding redirect=None decimal=2");
	
	// Calibrate / save/load calibration
	if((BlockXInd==BlockStartCol)&&(BlockYInd==BlockStartRow))
	{
		run("Duplicate...", "title=Calibration");
		CalibrationID = getImageID();
		setTool("rectangle");
		run("Enhance Contrast", "saturated=0.7");
		waitForUser("Block ROI (outside cropped)");
		getBoundingRect(XStart, YStart, Width, Height);
		//XStart = 21;YStart = 24;Width = 1293;Height = 972;
		print("ROI position: ",XStart,YStart,Width,Height);
		run("Select None");
		waitForUser("Draw a ROI closely circling a L pattern");
		getStatistics(PatternArea, mean, min, max);
		//PatternArea = 18000;
		print("Pattern area: "+PatternArea);
		Str = d2s(XStart,0)+"--"+d2s(YStart,0)+"--"+d2s(Width,0)+"--"+d2s(Height,0)+"--"+d2s(PatternArea,0);
		Test = File.delete(TempFolder+"//CytooConfig.txt");
		Test = File.append(Str, TempFolder+"//CytooConfig.txt");
		selectImage(CalibrationID);
		close();
	}
	else
	{
		Str = File.openAsString(TempFolder+"//CytooConfig.txt");
		StrArr = split(Str,"--");
		XStart = parseInt(StrArr[0]);YStart = parseInt(StrArr[1]);Width = parseInt(StrArr[2]);Height = parseInt(StrArr[3]);PatternArea = parseInt(StrArr[4]);
	}

	if(DebugMode<2)setBatchMode(true);

	// Copy original
	selectImage(OriginalID);
	run("Duplicate...", "title=LowResolutionMontage");
	CopyID = getImageID();
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
	
	// Crop ROI
	PatternSideLength = sqrt(PatternArea);
	makeRectangle(XStart, YStart, Width, Height);
	run("Crop");
	
	// Split channels
	run("Make Composite", "display=Composite");
	CompositeID = getImageID();
	run("Duplicate...", "title=Nuclei duplicate channels=2");
	run("Grays");
	NucleiID = getImageID();
	selectImage(CompositeID);
	run("Duplicate...", "title=Tubulin duplicate channels=3");
	run("Grays");
	TubulinID = getImageID();
	selectImage(CompositeID);
	run("Duplicate...", "title=Patterns duplicate channels=1");
	run("Grays");
	PatternsID = getImageID();
	selectImage(CompositeID);
	close();
	
	// Patterns: Threshold and analyze particles
	selectImage(PatternsID);
	rename("Patterns");
	setAutoThreshold("Otsu dark");
	run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 show=Nothing display exclude clear");	
	
	if(DebugMode>1)waitForUser("Debug Mode: Patterns");
	
	selectImage(PatternsID);
	close();
	// Only keep valid patterns and store positions to array
	PattPosX = newArray(nResults);
	PattPosY = newArray(nResults);
	CntValPatt = 0;
	for(i=0;i<nResults;i++)
	{
		if((abs(getResult("Width",i)-PatternSideLength)/PatternSideLength<PatternLengthTolerance)&&(abs(getResult("Height",i)-PatternSideLength)/PatternSideLength<PatternLengthTolerance))
		{
			PattPosX[CntValPatt] = getResult("BX",i)+getResult("Width",i)/2;
			PattPosY[CntValPatt] = getResult("BY",i)+getResult("Height",i)/2;	
			CntValPatt++;	
		}
	}
	PattPosX = Array.trim(PattPosX,CntValPatt);
	PattPosY = Array.trim(PattPosY,CntValPatt);
	
	// Nuclei channel: threshold
	selectImage(NucleiID);
	run("Auto Local Threshold", "method=Mean radius="+d2s(LocalThrRadius,0)+" parameter_1="+d2s(LocalThrLevel,0)+" parameter_2=0 white");
	run("Invert LUT");
	// Distance map: only keep the candidate condensed DNA
	run("Analyze Particles...", "size="+d2s(CondensedDNAAreaMin,0)+"-"+d2s(CondensedDNAAreaMax,0)+" circularity=0.00-1.00 show=Masks display clear");
	run("Distance Map");
	rename("DistanceMap");
	DistanceMapID = getImageID();

	if(DebugMode>1)waitForUser("Debug Mode: DNA");

	// Tubulin channel: local threshold
	selectImage(TubulinID);
	run("Auto Local Threshold", "method=Mean radius="+d2s(LocalThrRadius,0)+" parameter_1="+d2s(LocalThrLevel,0)+" parameter_2=0 white");
	run("Invert LUT");

	if(DebugMode>1)waitForUser("Debug Mode: Tubulin");

	// Wander pattern positions
	ValPattPosX = newArray(CntValPatt);
	ValPattPosY = newArray(CntValPatt);
	CntValPos = 0;
	for(i=0;i<lengthOf(PattPosX);i++)
	{
		selectImage(NucleiID);
		makeOval(PattPosX[i]-PatternSideLength*PatternLengthExtension/2,PattPosY[i]-PatternSideLength*PatternLengthExtension/2,PatternSideLength*PatternLengthExtension,PatternSideLength*PatternLengthExtension);
		// Analyze particles for candidate mitotic cells (nuclei channel): 1 single dividing cell		
		run("Analyze Particles...", "size="+d2s(CondensedDNAAreaMin,0)+"-"+d2s(CondensedDNAAreaMax,0)+" circularity=0.00-1.00 show=Nothing display exclude clear");
		NCondensedNuc = nResults;
		selectImage(DistanceMapID);
		makeOval(PattPosX[i]-PatternSideLength*PatternLengthExtension/2,PattPosY[i]-PatternSideLength*PatternLengthExtension/2,PatternSideLength*PatternLengthExtension,PatternSideLength*PatternLengthExtension);
		run("Find Maxima...", "noise=2 output=[Point Selection] light");
		if(selectionType>-1)
		{
			getSelectionCoordinates(xCoordinates, yCoordinates);
			Nmax = lengthOf(xCoordinates);
		}
		else Nmax = 0;

		if((NCondensedNuc == 1)&&(Nmax == 1))
		{	
			// Analyze particles for candidate mitotic cells (tubulin channel): 1 single dividing cell not touching the border of the analysis area	
			selectImage(TubulinID);
			makeOval(PattPosX[i]-PatternSideLength*PatternLengthExtension/2,PattPosY[i]-PatternSideLength*PatternLengthExtension/2,PatternSideLength*PatternLengthExtension,PatternSideLength*PatternLengthExtension);
			run("Analyze Particles...", "size="+d2s(TubulinMitosisAreaMin,0)+"-Infinity circularity=0.00-1.00 show=Nothing display exclude clear");
			N1 = nResults;
			run("Analyze Particles...", "size="+d2s(TubulinMitosisAreaMin,0)+"-Infinity circularity=0.00-1.00 show=Nothing display clear");
			N2 = nResults;
			if(N1 == N2)
			{
				ValPattPosX[CntValPos] = XStart+PattPosX[i];
				ValPattPosY[CntValPos] = YStart+PattPosY[i];
				CntValPos++;
			}
		}
	}
	run("Select None");
	
	// Define final selection
	selectImage(OriginalID);
	for(i=0;i<CntValPos;i++)
	{
		makePoint(ValPattPosX[i],ValPattPosY[i]);
		setKeyDown("shift");
	}
	
	// Cleanup
	selectImage(NucleiID);
	close();	
	selectImage(DistanceMapID);
	close();
	selectImage(TubulinID);
	close();
	selectImage(OriginalID);

	if(DebugMode<2)setBatchMode("exit & display");
	if(DebugMode>0)waitForUser("Debug Mode: Pattern centered isolated cells + condensed DNA + condensed tubulin");
}

//////////////////////////////////////////////////////////////////////////////////////////////////
//
// Name:	RoisOnGrid2
// Author: 	Sébastien Tosi (IRB/ADMCF)
// Date:	17-04-2012	
//	
// Description: This function inspects the ROI manager selections and only keeps the
// ROIs which center is row AND column aligned (within "Tol" pixels) to the center of
// at least "match" other ROI centers. The other selections are removed from the ROI manager
//
//////////////////////////////////////////////////////////////////////////////////////////////////

function RoisOnGrid2(Tol,match)
{
run("Clear Results");
roiManager("Measure");
Tabx = newArray(nResults);
Taby = newArray(nResults);
Erase = newArray(nResults);
for(i=0;i<nResults;i++)
{
	Tabx[i]=getResult("X",i);
	Taby[i]=getResult("Y",i);
}

for(i=0;i<nResults;i++)
{
	x = Tabx[i];
	y = Taby[i];
	testx=0;testy=0;
	for(j=0;j<nResults;j++)
	{
		if(j!=i)
		{
			if(abs(x-Tabx[j])<=Tol)testx++;
			if(abs(y-Taby[j])<=Tol)testy++;
		}
	}
	if((testx<match)||(testy<match))Erase[i]=1;
}
for(i=nResults-1;i>-1;i--)
{
	if(Erase[i]==1)
	{
		roiManager("Select",i);
		roiManager("Delete");
	}
}
}