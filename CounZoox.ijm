
// CounZoox is a macro dveeloped to count zooxanthellae, linked to the paper .....
// It is easily hijacked for other purpose. The macros are provided "as is".
// for more information contact sebastien.schaub@imev-mer.fr

var MyUnit="pxl";// Default value for unit. If images are calibrated, it turns to mm
var Algua_Thresh=newArray(0,65535);// Threshold for Reference Algua
var Algua_Range="4-14"; // diameter in µm
var Ch_Fluo=1;// define which channel content the fluorescence to threshold
var ChamberThickness=0.2;// depth of the chamber. 0.2mm for a Mallasez cell
// ============================================================================
macro "AutoInstall"{
	run("Install...", "install=["+getDirectory("macros")+"MICA\\CounZoox.ijm]");
}
// ============================================================================
macro "Init [9]"{
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

	ColorImage();
	ImgDir=getInfo("image.directory");
	ImgName=getInfo("image.filename");
	run("Select None");
	CamArea=getWidth()*getHeight();
	getPixelSize (unit, pixelWidth, pixelHeight);
	
	setSlice(1);
	Stack.setDisplayMode("grayscale");
	if (Algua_Thresh[0]==0){
		run("Threshold...");
		setAutoThreshold("MaxEntropy dark");
		waitForUser("Confirm Threshold");	
		getThreshold(Algua_Thresh[0], Algua_Thresh[1]);
	}
	else {
		setThreshold(Algua_Thresh[0], Algua_Thresh[1]);		
	}
	run("Create Mask");
	run("Watershed");

// Convert diameter in area
	D=newArray(2);
	D=split(Algua_Range, "-");
	AreaRange=""+round(pow(D[0],2)*PI/4)+"-"+round(pow(D[1],2)*PI/4);

	run("Analyze Particles...", "size="+AreaRange+" display clear include slice add");
	close("mask");
	
	Algua_Area=0; // mean area of Algua in µm²
	LArea=newArray(nResults);
	LInt=newArray(nResults);
	roiManager("deselect");
	run("Measure");
	for (i1=0;i1<roiManager("count")-1;i1++) {
//		Algua_Area+=getResult("Area", i1);
		LArea[i1]=getResult("Area", i1);
		LInt[i1]=getResult("IntDen", i1);
	}
	Algua_N=nResults+1; 
	Array.getStatistics(LArea, min, max, Algua_Area, Algua_Area_Std);
	Array.getStatistics(LInt, min, max, Algua_Int, Algua_Int_Std);
	Algua_Conc2D=Algua_N/CamArea; // number of Algua per mm²
	Algua_Conc3D=Algua_Conc2D;
	if (unit=="microns"){
		S=CamArea*pow(pixelWidth/1000,2);
//		Algua_Area=Algua_Area *pow(pixelWidth,2);
		V=S*ChamberThickness;
		Algua_Conc2D=Algua_N/S;
		Algua_Conc3D=Algua_N/V;
		MyUnit="mm";
	}
	else{
		S=CamArea;
		V=S;
		Algua_Conc2D=Algua_N/S;		
	}
	
	IJ.renameResults("Results","tmp");
	
	IJ.renameResults("MySummary","Results");
	n=nResults;
	setResult("Directory", n, ImgDir);
	setResult("Filename", n, ImgName);
	setResult("N.Algua", n, Algua_N);
	setResult("<Algua.Area> ["+unit+"2]", n, Algua_Area);
	setResult("AA +/- ["+unit+"2]", n, Algua_Area_Std);
	setResult("<Chlorophyl> [int]", n, Algua_Int);
	setResult("Chl +/- [int]", n, Algua_Int_Std);
	setResult("C.Algua per "+MyUnit+"^2", n, Algua_Conc2D);
	setResult("C.Algua per "+MyUnit+"^3", n, Algua_Conc3D);
	setResult("Est.Vol ["+MyUnit+"^3]", n, V);
	setResult("Thresh.Algua", n, Algua_Thresh[0]);
	setResult("CamSze", n, ""+getWidth()+"x"+getHeight());	
	setResult("PxlSze", n, ""+pixelWidth+unit);
	
	IJ.renameResults("Results","MySummary");
	IJ.renameResults("tmp","Results");
	Stack.setDisplayMode("composite");
	Stack.setActiveChannels("110");

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
        	if (endsWith(list[i], ".czi")){
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
	Dialog.addNumber("Algua Threshold [0 to reboot]", Algua_Thresh[0]);
	Dialog.addString("Algua Diameter [min-max] in µm" , Algua_Range);
	Dialog.show();
	Ch_Fluo = Dialog.getNumber();
	Algua_Thresh[0] = Dialog.getNumber();
	Algua_Range= Dialog.getString();
}

// ============================================================================
function ColorImage(){
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
