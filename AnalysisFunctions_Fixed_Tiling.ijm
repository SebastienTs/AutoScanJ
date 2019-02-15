///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Glomerulus_detector:  Sample: Molecular probe mouse kidney section, GFP channel (first channel).
//			    Imaging: AF performed, primary job: single slice, 20x air objective NA=0.7, zoom=1, 
//				     pinhole=1.5 Airy, 1024x1024 pixels image
//
// Glomerulus_2detector: Same as before
//  
// Metaphase_detector: Sample: Cultured HeLa cells, DAPI channel (first channel)
//		     Imaging: AF performed, 63x oil objective NA=1.4, zoom=1, pinhole = 1.5 Airy, 256x256 pixels image
//
// MetaphaseHS3_detector:  Sample: Cultured HeLa cells, HS3-GFP channel (first channel)
//		     Imaging: AF, 63x oil objective NA=1.4, zoom=1, pinhole = 1.5 Airy, 256x256 pixels image
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function _None(ImagesSize)
{
	run("Point Tool...", "mark=0 label selection=yellow");
	setTool("multipoint");	
}

function _Glomerulus_detector(ImagesSize)
{	
	OriginalID = getImageID();
	run("Duplicate...", "title=LowResolutionMontage");
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
	run("Set Measurements...", "area centroid shape kurtosis redirect=None decimal=2");

	// If RGB only keep the first (red channel)
	if(bitDepth()==24)
	{
		run("Split Channels");	
		selectImage("LowResolutionMontage (blue)");
		close();
		selectImage("LowResolutionMontage (green)");
		close();
		selectImage("LowResolutionMontage (red)");
	}
	FirstChanID = getImageID();

	// Glomerulus detection - Enhance non isotropic texture
	run("FeatureJ Structure", "  smallest smoothing=0.25 integration=5");
	run("Gaussian Blur...", "sigma=4");
	run("8-bit");
	// Reduce background
	run("Subtract Background...", "rolling=50");
	FilteredID = getImageID();

	// Thresholding
	setAutoThreshold("Moments dark");
	run("Convert to Mask","slice");
	run("Fill Holes");
	//waitForUser("Initial mask");

	// Filter particles by size
	run("Analyze Particles...", "size=1750-25000 circularity=0.00-1.00 show=Masks clear add");
	AnalyzedID = getImageID();

	// Cleanup
	selectImage(FirstChanID);
	close();
	selectImage(FilteredID);
	close();
	selectImage(AnalyzedID);
	close();

	// Geometrical filtering + display particles centroids
	selectImage(OriginalID);
	run("Clear Results");
	roiManager("Measure");
	//waitForUser("Area filtered mask");
	
	for(i=0;i<nResults;i++)
	{
		if((getResult("Solidity",i)>0.7)&&(getResult("Round",i)>0.5)&&(getResult("Kurt",i)>-0.5))
		{
			makePoint(getResult("X",i),getResult("Y",i));
			setKeyDown("shift");
		}
	}
}

function _Glomerulus2_detector(ImagesSize)
{	
	OriginalID = getImageID();
	run("Duplicate...", "title=LowResolutionMontage");
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
	run("Set Measurements...", "area centroid shape kurtosis redirect=None decimal=2");

	// If RGB only keep the first (red channel)
	if(bitDepth()==24)
	{
		run("Split Channels");	
		selectImage("LowResolutionMontage (blue)");
		close();
		selectImage("LowResolutionMontage (green)");
		close();
		selectImage("LowResolutionMontage (red)");
	}
	FirstChanID = getImageID();

	// Glomerulus detection - Enhance non isotropic texture
	run("FeatureJ Structure", "  smallest smoothing=0.25 integration=5");
	run("Gaussian Blur...", "sigma=4");
	run("8-bit");
	// Reduce background
	run("Subtract Background...", "rolling=50");
	FilteredID = getImageID();

	// Thresholding
	setAutoThreshold("Moments dark");
	run("Convert to Mask","slice");
	run("Fill Holes");
	//waitForUser("Initial mask");

	run("Distance Map");
	run("Invert LUT");
	run("Find Maxima...", "noise=22 output=[Point Selection]");
	run("Clear Results");
	run("Measure");
	
	selectImage(OriginalID);
	for(i=0;i<nResults;i++)
	{
		makePoint(getResult("X",i),getResult("Y",i));
		setKeyDown("shift");
	}

	// Cleanup
	selectImage(FirstChanID);
	close();
	selectImage(FilteredID);
	close();
}

function _Metaphase_detector(ImagesSize)
{
	OriginalID = getImageID();
	//run("Enhance Contrast", "saturated=0");
	
	run("Duplicate...", "title=LowResolutionMontage");
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
	run("Set Measurements...", "area centroid redirect=None decimal=2");

	// If RGB only keep the first (red channel)
	if(bitDepth()==24)
	{
		run("Split Channels");	
		selectImage("LowResolutionMontage (blue)");
		close();
		selectImage("LowResolutionMontage (green)");
		close();
		selectImage("LowResolutionMontage (red)");
	}
	FirstChanID = getImageID();

	// Pre filtering
	run("Median...", "radius=2");
	rename("PreProcessed");
	run("Duplicate...", "title=Tmp");
	//waitForUser("You will now have to set the parameters to efficiently \nremove the cells in metaphase (Typ: rad=5 thr=45)");
	//run("Remove Outliers...");
	run("Remove Outliers...", "radius=4 threshold=35 which=Bright");
	OutliersRemovedID = getImageID();
	rename("OutliersRemoved");
	imageCalculator("Subtract", "PreProcessed","OutliersRemoved");
	selectImage("PreProcessed");	

	// Filter detected particles by size
	setThreshold(1,255);
	run("Analyze Particles...", "size=12-100 circularity=0.00-1.00 show=Nothing display clear add include");

	// Cleanup
	selectImage(OutliersRemovedID);
	close();
	selectImage(FirstChanID);
	close();
	selectWindow("ROI Manager");
	run("Close");
	
	// Display detected objects centroids
	selectImage(OriginalID);
	for(i=0;i<nResults;i++)
	{
		makePoint(getResult("X",i),getResult("Y",i));
		setKeyDown("shift");
	}
	setTool("multipoint");
}

function _MetaphaseHS3_detector(ImagesSize)
{
	OriginalID = getImageID();

	run("Duplicate...", "title=LowResolutionMontage");
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
	run("Set Measurements...", "area centroid redirect=None decimal=2");

	// If RGB only keep the first (red channel)
	if(bitDepth()==24)
	{
		run("Split Channels");	
		selectImage("LowResolutionMontage (blue)");
		close();
		selectImage("LowResolutionMontage (green)");
		close();
		selectImage("LowResolutionMontage (red)");
	}
	run("Despeckle");
	run("Gaussian Blur...", "sigma=2");
	run("Threshold...");
	waitForUser("Adjust the threshold");
	run("Convert to Mask");
	run("Watershed");
	run("Analyze Particles...", "size=25-Infinity circularity=0.00-1.00 show=Nothing display clear include");
	close();
	
	// Display detected objects centroids
	selectImage(OriginalID);
	for(i=0;i<nResults;i++)
	{
		makePoint(getResult("X",i),getResult("Y",i));
		setKeyDown("shift");
	}
	setTool("multipoint");
}