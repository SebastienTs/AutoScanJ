///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function _None(FieldWidth,FieldHeight)
{	
	setTool("multipoint");
	waitForUser("Select points of interest");
}

function _Mitosis_Microtubulin(FieldWidth,FieldHeight)
{	

// 512 x 512 pix images
NucleusMinRadius = 8;
EventMinArea = 64;
LaplacianThresh = -0.5;	  // Event detection (dark to bright particle difference)
LaplacianMax = 0.15;	  // Nucleus detection (dark particle)

// 256 x 256 pix images
//NucleusMinRadius = 4;
//EventMinArea = 16;
//LaplacianThresh = -2;
//LaplacianMax = 0.6;

// Basal nucleus characteristics
NucleusMaxMean = 40;		// Maximum mean intensity inside non dividing nucleus
IntensityTol = 5;		// Wand tolerance for selection
MinArea = 100;			// Selectin minimum area
// Dividing nucleus intensity characteristics
IntensityIncrease = 35;		// Minimum mean intensity increase (inside former nucleus)
BurstMinIntensity = 16;		// Minimum intensity (inside former nucleus)

// Initialization
run("Set Measurements...", "area mean min center shape redirect=None decimal=2");

// Stack format
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices=1 frames="+d2s(nSlices,0)+" display=Grayscale");

// PreFiltering
run("Median...", "radius="+d2s(round(NucleusMinRadius/2),0)+" stack");
//run("Gray Morphology", "radius="+d2s(NucleusMinRadius/2,0)+" type=circle operator=close");
rename("Filtered");

// Laplacian for particles detection
run("FeatureJ Laplacian", "compute smoothing="+d2s(NucleusMinRadius,0));
rename("Laplacian");

// Temporal derivative of the Laplacian
selectImage("Laplacian");
run("Duplicate...","title=Variations duplicate range=1-"+d2s(nSlices,0));
run("32-bit");
setSlice(nSlices);
run("Add Slice");
setSlice(1);
run("Delete Slice");
imageCalculator("Subtract stack", "Variations","Laplacian");
run("Reverse");
setSlice(nSlices);
run("Add Slice");
run("Reverse");
setSlice(nSlices);
run("Delete Slice");

// Events mask (Strong Laplacian decrease in a localized area)
selectImage("Variations");
setThreshold(-1000,LaplacianThresh);

run("Convert to Mask", "  black");
rename("EventsMask");

Detected = false;
XDetect = 0;
YDetect = 0;

// Test all the events
for(i=3;i<=nSlices;i++)
{
	QualityDetect = 0;
	selectImage("EventsMask");
	setSlice(i);
	run("Select None");
	if(roiManager("count")>0)
	{
		roiManager("Deselect");
		roiManager("Delete");
	}
	run("Analyze Particles...", "size="+d2s(EventMinArea,0)+"-Infinity circularity=0.00-1.00 show=Nothing clear add slice");
	for(j=0;j<roiManager("count");j++)
	{
		selectImage("Laplacian");
		roiManager("Select",j);
		Slice = getSliceNumber();
		setSlice(Slice-1);	
		run("Enlarge...", "enlarge="+d2s(NucleusMinRadius/2,0));
		run("Find Maxima...", "noise="+d2s(LaplacianMax,2)+" output=List exclude");
		IsLaplacianExtremum = (nResults==1);
		if(IsLaplacianExtremum)
		{	
			MaxXpos = getResult("X",nResults-1);
			MaxYpos = getResult("Y",nResults-1);

			selectImage("Filtered");
			setSlice(Slice-2);
			doWand(MaxXpos,MaxYpos,IntensityTol,"legacy");
			run("Measure");
			MeanBefore2 = getResult("Mean",nResults-1);
			AreaBefore2 = getResult("Area",nResults-1);
			CircBefore2 = getResult("Circ.",nResults-1);
			
			selectImage("Filtered");
			setSlice(Slice-1);
			doWand(MaxXpos,MaxYpos,IntensityTol,"legacy");
			run("Measure");
			MeanBefore1 = getResult("Mean",nResults-1);
			AreaBefore1 = getResult("Area",nResults-1);			
			CircBefore1 = getResult("Circ.",nResults-1);
			
			selectImage("Filtered");
			setSlice(Slice);	
			run("Measure");
			MeanAfter = getResult("Mean",nResults-1);
			MinAfter = getResult("Min",nResults-1);
			
			Test1 = ((MeanBefore1<NucleusMaxMean)&&((MeanAfter-MeanBefore1)>IntensityIncrease)&&(MinAfter>BurstMinIntensity)&&(AreaBefore1>MinArea)&&(CircBefore1>0.3));
			Test2 = ((MeanBefore2<NucleusMaxMean)&&((MeanAfter-MeanBefore2)>IntensityIncrease)&&(MinAfter>BurstMinIntensity)&&(AreaBefore2>MinArea)&&(CircBefore2>0.3));
			if(Test1||Test2)
			{
				Quality=(MeanAfter-MeanBefore1)*(MeanAfter-MeanBefore2)/(MeanBefore1*MeanBefore2);
				print(i,j,"Found","Quality"+d2s(Quality,0));
				Detected=true;
				if(Quality>QualityDetect)
				{
					XDetect=getResult("XM",nResults-1);;
					YDetect=getResult("YM",nResults-1);;
					QualityDetect = Quality;
				}
			}
			else print(i,j,"Failed",AreaBefore2,CircBefore2,AreaBefore1,CircBefore1," - ",MeanBefore2,MeanBefore1,MinAfter,MeanAfter);
		}
	}
}
selectImage("EventsMask");
close();
selectImage("Laplacian");
close();
selectImage("Filtered");
run("Select None");
setSlice(nSlices);
if(Detected==true)makePoint(XDetect,YDetect);
}