
// CounZoox is a macro dveeloped to count zooxanthellae, linked to the paper https://royalsocietypublishing.org/doi/full/10.1098/rsos.231683
// It is easily hijacked for other purpose. The macros are provided "as is".
// for more information contact sebastien.schaub@imev-mer.fr

// Modifications
// 2024-04-11 : - works on single channel image  
//              - JPG image (the channel to analyse is 1=Red, 2=Green, 3=Blue). it works BUT NOT RECOMMANDED
// 2024-01-12 : - bugs on measurments (Set measurements have been added to solve it)
//              - Some macros are not composite, so run("Make Composite"... have been added to force it.
//              - Batch mode now accept czi AND tif files

var MyUnit="pxl";// Default value for unit. If images are calibrated, it turns to mm
var Alga_Thresh=newArray(0,65535);// Threshold for Reference Alga
var Alga_Range="4-14"; // diameter in µm
var Ch_Fluo=1;// define which channel content the fluorescence to threshold
var ChamberThickness=0.2;// depth of the chamber. 0.2mm for a Mallasez cell

// ============================================================================
macro "AutoInstall"{
	run("Install...", "install=["+getDirectory("macros")+"MICA\\CounZoox.ijm]");
}
// ============================================================================
macro "Init [9]"{
	run("Set Measurements...", "area mean modal centroid integrated redirect=None decimal=3");
	if(isOpen("MySummary")) close("MySummary");
	if (nImages==0) newImage("pipo", "8-bit black", 10, 10, 1);
	run("Measure");
	run("Clear Results");
	IJ.renameResults("Results","MySummary");
	run("Measure");
	run("Clear Results");
	close("pipo");
}

// ============================================================================
macro "MeasureCurrent [1]"{
	roiManager("reset");
	if (nImages==0) open();

	if (bitDepth()==24) {
		run("RGB Stack");
	}
	if (nSlices>1) {
		ColorImage();
		setSlice(Ch_Fluo);
		Stack.setDisplayMode("grayscale");
	}
	ImgDir=getInfo("image.directory");
	ImgName=getInfo("image.filename");
	run("Select None");
	CamArea=getWidth()*getHeight();
	getPixelSize (unit, pixelWidth, pixelHeight);
	


	if (Alga_Thresh[0]==0){
		run("Threshold...");
		setAutoThreshold("MaxEntropy dark");
		waitForUser("Confirm Threshold");	
		getThreshold(Alga_Thresh[0], Alga_Thresh[1]);
	}
	else {
		setThreshold(Alga_Thresh[0], Alga_Thresh[1]);		
	}
	run("Create Mask");
	run("Watershed");

// Convert diameter in area
	D=newArray(2);
	D=split(Alga_Range, "-");
	AreaRange=""+round(pow(D[0],2)*PI/4)+"-"+round(pow(D[1],2)*PI/4);

	run("Analyze Particles...", "size="+AreaRange+" display clear include slice add");
	close("mask");
	
	Alga_Area=0; // mean area of Alga in µm²
	LArea=newArray(nResults);
	LInt=newArray(nResults);
	roiManager("deselect");
	run("Measure");
	for (i1=0;i1<roiManager("count")-1;i1++) {
//		Alga_Area+=getResult("Area", i1);
		LArea[i1]=getResult("Area", i1);
		print(LArea[i1]);
		LInt[i1]=getResult("IntDen", i1);
	}
	Alga_N=nResults+1; 
	Array.getStatistics(LArea, min, max, Alga_Area, Alga_Area_Std);
	Array.getStatistics(LInt, min, max, Alga_Int, Alga_Int_Std);
	Alga_Conc2D=Alga_N/CamArea; // number of Alga per mm²
	Alga_Conc3D=Alga_Conc2D;
	if (unit=="microns"){
		S=CamArea*pow(pixelWidth/1000,2);
//		Alga_Area=Alga_Area *pow(pixelWidth,2);
		V=S*ChamberThickness;
		Alga_Conc2D=Alga_N/S;
		Alga_Conc3D=Alga_N/V;
		MyUnit="mm";
	}
	else{
		S=CamArea;
		V=S;
		Alga_Conc2D=Alga_N/S;		
	}
	
	IJ.renameResults("Results","tmp");
	if (isOpen("MySummary")) IJ.renameResults("MySummary","Results");
	n=nResults;
	setResult("Directory", n, ImgDir);
	setResult("Filename", n, ImgName);
	setResult("N.Alga", n, Alga_N);
	setResult("<Alga.Area> ["+unit+"2]", n, Alga_Area);
	setResult("AA +/- ["+unit+"2]", n, Alga_Area_Std);
	setResult("<Chlorophyll> [int]", n, Alga_Int);
	setResult("Chl +/- [int]", n, Alga_Int_Std);
	setResult("C.Alga per "+MyUnit+"^2", n, Alga_Conc2D);
	setResult("C.Alga per "+MyUnit+"^3", n, Alga_Conc3D);
	setResult("Est.Vol ["+MyUnit+"^3]", n, V);
	setResult("Thresh.Alga", n, Alga_Thresh[0]);
	setResult("CamSze", n, ""+getWidth()+"x"+getHeight());	
	setResult("PxlSze", n, ""+pixelWidth+unit);
	
	IJ.renameResults("Results","MySummary");
	IJ.renameResults("tmp","Results");
	if (nSlices>1){
		Stack.setDisplayMode("composite");
		Stack.setActiveChannels("110");
	}

	selectWindow("MySummary");
}

// ============================================================================
macro "Batch Measure [2]"{
  dir = getDirectory("Choose a Directory ");
  count = 1;

  if(isOpen("MySummary")) close("MySummary");
  if (nImages==0) newImage("pipo", "8-bit black", 10, 10, 1);
  run("Measure");
  run("Clear Results");
  IJ.renameResults("Results","MySummary");
  run("Measure");
  run("Clear Results");
  close("pipo");

  
  listFiles(dir); 
  selectWindow("MySummary");
  saveAs("Results", dir+"MySummary.csv");

  function listFiles(dir) {
     list = getFileList(dir);
     for (i=0; i<list.length; i++) {
        if (endsWith(list[i], "/"))
           listFiles(""+dir+list[i]);
        else{
        	if (endsWith(list[i], ".czi") | endsWith(list[i], ".tif")  | endsWith(list[i], ".jpg")){
        		open(dir+list[i]);
        		TmpTitle2=getTitle();
        		run("MeasureCurrent [1]");
    			roiManager("reset");
        		close(TmpTitle2);
        	}        	
        }
     }
  }	
}


// ============================================================================
macro "EditParameters [0]"{
	Dialog.create("Comptage Zooxanthelles Parameters");
	Dialog.addNumber("# channel to threshold", Ch_Fluo);
	Dialog.addNumber("Alga Threshold [0 to reboot]", Alga_Thresh[0]);
	Dialog.addString("Alga Diameter [min-max] in µm" , Alga_Range);
	Dialog.show();
	Ch_Fluo = Dialog.getNumber();
	Alga_Thresh[0] = Dialog.getNumber();
	Alga_Range= Dialog.getString();
}

// ============================================================================
function ColorImage(){
//	Stack.getDimensions(width, height, channels, slices, frames);
//	print("C"+channels+" S"+slices+"F"+frames);
	run("Make Composite", "display=Composite");
	if (nSlices==2){
		setSlice(2);
		run("Enhance Contrast", "saturated=0.05");
		run("Grays");
		setSlice(1);
		run("Enhance Contrast", "saturated=0.05");
		run("Green");
		Stack.setDisplayMode("composite");
		Stack.setActiveChannels("11");	
	}
	if (nSlices==3){
		setSlice(3);
		run("Enhance Contrast", "saturated=0.05");
		run("Magenta");
		setSlice(2);
		run("Enhance Contrast", "saturated=0.05");
		run("Grays");
		setSlice(1);
		run("Enhance Contrast", "saturated=0.05");
		run("Green");
		Stack.setDisplayMode("composite");
		Stack.setActiveChannels("110");	
	}
}
