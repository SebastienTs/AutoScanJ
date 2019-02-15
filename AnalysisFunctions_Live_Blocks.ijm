///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Name:	LiveCAMAnalysisFunctionsPositions
// Author: 	Sebastien Tosi (IRB/ADMCF)
// Date:	10-10-2012	
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function _Mitosis_Neuroblast(ImagesSize)
{

// Segmentation mask (fixed threshold at SignalLevel) --> find best neuroblast candidate in each position. 
// Criteria: area (typical: A0) and median intensity (typical: M0). 
// If the fitness of the best candidate is above a given threshold (MonThr) the system enters monitor mode 
// (for this position). 
// From monitor mode the system can switch to trigger mode if the fitness shows a sudden drop (greater than DropThr). 
// When in trigger mode a neuroblast division is detected if the fitness gets below a fixed threshold (DetThr)
// and the last monitor candidate is centered in the field of view (WindowWidth).
// Oversegmentation of monitored particles is tested for by trying to merge closeby particles. In case
// oversegmentation is detected it is un-triggered. (See state machine pdf for details).

// Neuroblast detection
SignalLevel = 10; // Signal level threshold (typical: 35, first dataset: 10)   
A0 = 1600; 	  // Typical neuroblast area (typical: 1600 pix)
M0 = 20;   	  // Typical neuroblast median intensity (typical: 70, first dataset: 20)

// Neuroblast fitness
MonThr = 0.85;	 // Fitness threshold to enter monitor mode
DropThr = 0.1;   // Minimum fitness drop to enter trigger mode
DetThr = 0.775;  // Fitness threshold for division (once in trigger mode) 

// Extra conditions
MinRelArea = 0.125; 	    // Oversegmentation correction: Try to merge the particles inside the last monitored particle, check overall area 
WindowWidth = ImagesSize/4; // Do not detect division centered is outside this square window centered on the image

// Behaviour
InactivatePosition = false; // Stop monitoring position if division has been detected
ShowStates = true;	    // Draw current best fitness when monitor or trigger mode is true (T--> trigger)
Timer = true;		    // Report processing time in log window

if(Timer == true)Time=getTime();

// Initialization
run("Options...", "iterations=1 count=1 edm=Overwrite do=Nothing");
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
run("Set Measurements...", "area centroid median redirect=[Concatenated Stacks] decimal=2");
setForegroundColor(255, 255, 255);
setFont("SansSerif", 24);
NxField = getWidth()/ImagesSize;
NyField = getHeight()/ImagesSize;
Mid = ImagesSize/2;
nSlice = nSlices;

// Preprocess image
run("Subtract Background...", "rolling=100 stack");

// Segmentation mask
run("Duplicate...", "title=Mask duplicate");
setThreshold(SignalLevel, 255);
run("Convert to Mask", "stack");
//R0 = 3*sqrt(A0)/PI;
//run("Auto Local Threshold", "method=Mean radius="+d2s(R0,0)+" parameter_1=-6 parameter_2=0 white stack");
//run("Invert LUT");
for(i=1;i<=nSlice;i++)
{
	setSlice(i);
	//run("Fill Holes", "slice");
	run("Watershed", "slice");
}

// State machine: initialization
TmpFolder = getDirectory("temp");
FileName = "CAMLivePositionsStates.txt";
LastBestArray = newArray(NxField*NyField);
PosXLastBestArray = newArray(NxField*NyField);
PosYLastBestArray = newArray(NxField*NyField);
MonitorArray = newArray(NxField*NyField);
TriggerArray = newArray(NxField*NyField);
PosXLastValidArray = newArray(NxField*NyField);
PosYLastValidArray = newArray(NxField*NyField);

// Active positions file
Active = File.openAsString(TmpFolder+"CAMLivePositionsActivePositions.txt");
Active = split(Active,"--");
ActivePositionsArray = newArray(NxField*NyField);
for(i=0;i<NxField*NyField;i++)ActivePositionsArray[i]=parseInt(Active[i]);

for(loop=1;loop<=2;loop++)
{
// State machine: update
if(File.exists(TmpFolder+FileName))
{
	States = File.openAsString(TmpFolder+FileName);
	StatesArray = split(States,"--");
	for(i=0;i<NxField*NyField;i++)
	{
		LastBestArray[i] = parseFloat(StatesArray[i*7]);
		PosXLastBestArray[i] = parseInt(StatesArray[i*7+1]);
		PosYLastBestArray[i] = parseInt(StatesArray[i*7+2]);
		MonitorArray[i] = parseInt(StatesArray[i*7+3]);
		TriggerArray[i] = parseInt(StatesArray[i*7+4]);
		PosXLastValidArray[i] = parseInt(StatesArray[i*7+5]);
		PosYLastValidArray[i] = parseInt(StatesArray[i*7+6]);
	}
	loop = 2;
}
else loop=1;
	
for(x=0;x<NxField;x++)
{
for(y=0;y<NyField;y++)
{
	// Initialization
	Division = false;
	IndxPos = x*NyField+y;

	if(ActivePositionsArray[IndxPos]==true)
	{
	
	// Read state machine array
	LastBest = LastBestArray[IndxPos];
	LastBestPosX = PosXLastBestArray[IndxPos];
	LastBestPosY = PosYLastBestArray[IndxPos];
	Monitor = MonitorArray[IndxPos];
	Trigger = TriggerArray[IndxPos];
	LastBestCMassX = PosXLastValidArray[IndxPos];
	LastBestCMassY = PosYLastValidArray[IndxPos];

	// Compute fitness of particles
	selectImage("Mask");
	setSlice(loop);
	makeRectangle(x*ImagesSize,y*ImagesSize,ImagesSize,ImagesSize);	
	run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 show=Nothing display exclude clear record");
	BestFit = 0;
	BestFitPos = -1;
		
	for(i=0;i<nResults;i++)
	{
		Fitness = (minOf(getResult("Area",i)/A0,1)+minOf(M0/getResult("Median",i),1))/2;
		if(Fitness>BestFit)
		{
			BestFit = Fitness;
			BestFitPos = i;
		}	
		setResult("Fitness", i, Fitness);
	}
	updateResults();
	
	// Division detection: trigger
	DeltaFit = (BestFit-LastBest);
	if((DeltaFit<-DropThr)&&(Monitor==true))
	{
		Trigger = true;
	}
	
	// Untrigger: test watershed oversegmentation of the last valid particle
	UnTrigger = false;
	if((Trigger==true)&&(Monitor==true))
	{
		selectImage("Mask");
		setSlice(1);
		doWand(LastBestPosX,LastBestPosY,0,"Legacy");		
		getRawStatistics(Area, mean, min, max);
		CumArea = 0;
		// Test if object fitness is low due to oversegmentation
		for(Pnt=0;Pnt<nResults;Pnt++)
		{
			if(selectionContains(getResult("X",Pnt), getResult("Y",Pnt)))CumArea = CumArea+getResult("Area",Pnt);
		}
		// Avoid oversegmentation
		if(abs(CumArea/Area-1)<MinRelArea)
		{
			Trigger = false;
			UnTrigger = true;
		}
		run("Select None");	
	}	
		
	// Division detection (trigger + low level)
	if((BestFit<DetThr)&&(Trigger==true))
	{	
		if((abs(Mid-(LastBestCMassX%ImagesSize))<WindowWidth)&&(abs(Mid-(LastBestCMassY%ImagesSize))<WindowWidth))
		{	
		selectImage("Concatenated Stacks");
		setSlice(loop);	
		makePoint(LastBestCMassX,LastBestCMassY);
		Monitor = false;
		Trigger = false;
		Division = true;
		x = NxField; 
		y = NyField;
		// Update active positions
		if(InactivatePosition==true)
		{
			ActivePositionsArray[IndxPos] = 0;
			Active = "";
			for(i=0;i<NxField*NyField;i++)
			{
				if(ActivePositionsArray[i]==true)Active=Active+"1--";
				else Active=Active+"0--";
			}
			File.saveString(Active, TmpFolder+"CAMLivePositionsActivePositions.txt");
		}
		}
		else
		{
			Monitor = false;
			Trigger = false;
		}
	}
	// At least one particle?
	if(BestFitPos>-1)
	{
		XC = round(getResult("X",BestFitPos));
		YC = round(getResult("Y",BestFitPos));
	}
	// Monitor mode?
	if(BestFit>=MonThr)
	{
		Monitor = true;
		Trigger = false;
		LastBestPosX = getResult("XStart",BestFitPos);
		LastBestPosY = getResult("YStart",BestFitPos);
		LastBestCMassX = XC;
		LastBestCMassY = YC;
	}
	else Monitor = false;

	// Write to state machine array
	LastBestArray[IndxPos] = BestFit;
	PosXLastBestArray[IndxPos] = LastBestPosX;
	PosYLastBestArray[IndxPos] = LastBestPosY;
	MonitorArray[IndxPos] = Monitor;
	TriggerArray[IndxPos] = Trigger;
	PosXLastValidArray[IndxPos] = LastBestCMassX;
	PosYLastValidArray[IndxPos] = LastBestCMassY;

	// Show states on last frame
	if(loop==2)
	{
		selectImage("Concatenated Stacks");
		setSlice(loop);
		if(ShowStates==true)
		{
		if(BestFitPos>-1)
		{	
			DisplayString = d2s(BestFit,2);
			if(Trigger == true)DisplayString = DisplayString + " (T)";
			if(UnTrigger == true)DisplayString = DisplayString + " (U)";
			if(Monitor==true)
			{	
				setFont("SansSerif", 24);
				drawString(DisplayString, LastBestCMassX, LastBestCMassY);
			}
			else 
			{
				setFont("SansSerif", 16);
				drawString(DisplayString, round(getResult("X",BestFitPos)), round(getResult("Y",BestFitPos))); 	
			}
		}
		}
	}
	}
}	
}

// Write state machine array to file
States = "";
for(i=0;i<NxField*NyField;i++)States = States+d2s(LastBestArray[i],3)+"--"+d2s(PosXLastBestArray[i],0)+"--"+d2s(PosYLastBestArray[i],0)+"--"+d2s(MonitorArray[i],0)+"--"+d2s(TriggerArray[i],0)+"--"+d2s(PosXLastValidArray[i],0)+"--"+d2s(PosYLastValidArray[i],0)+"--";
File.saveString(States, TmpFolder+FileName);

}

// Cleanup
selectImage("Mask");
close();
selectImage("Concatenated Stacks");

// Division detected: reset state machine
if(Division==true)
{
	File.delete(TmpFolder+FileName);
}

if(Timer == true)
{
	Time2 = getTime();
	print("Time elapsed: "+d2s(Time2-Time,0)+" ms\n");
}
}