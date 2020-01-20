/*
 1-02 adding OSC
 1.05 added beziercurves, eph gravitation
 1.06 change to frame based timeline recording of nodes
 1.09 added PGraphics for trails
 1.10  added angle dependent loopPointer direction change
 1.11 added node to node repulsion, attract to brighter trail pixe
 1.12 ephemer alive, eToE interaction , new class Leg, tbd
 1.13 immersive lab, handleuserinput back to mouse events + timestamps
 1.14 immersive lab version
 1.15 params adjustment
 1.16 div tuning
 1.17 cameratracking
 1.18 lange nacht installation version
 */
/*
- wieso klebt unten und oben? force? away from brightest pixel?
 repellFromBrightestPixel if y = 0 || y = canvasH -> repell
 - faderate von framerate abhängig machen.
 - fadeamount statt rate. lineare abnahme evtl besser.
 - resurrect: steer to light?
 
 
 */

// tracking
import processing.video.*;
import org.openkinect.processing.*;
import beads.*;



// audio
AudioContext ac;
IOAudioFormat audioFormat;
float sampleRate = 44100;
int buffer = 512;
int bitDepth = 16;
int inputs = 2;
int outputs = 6;
boolean stereo = true;  // stereo or quad

//Capture video;
PImage video;
Kinect kinect;
int blobCounter = 0;

int maxLife = 10;  // blog survival time in frames, if no match
float threshold = 30;
float distThreshold = 120;
int maxBlobSize = 175; 
int minRedValue = 230;
int minGreenValue = -1;

ArrayList<Blob> blobs = new ArrayList<Blob>();
boolean setupMode;
PVector[] projectionPoints = new PVector[4];  // 0= upper left, 1= upper right, 2= lower right, 3= lower left ----> clockwise
int pMinX, pMinY, pMaxX, pMaxY;  // min/max values calc from projectionPoints
String touchtext = "   ";
Preference myPrefs = new Preference();
float deg;
boolean showFrameRate = false;


// 
import codeanticode.syphon.*;
import oscP5.*;
import netP5.*;

PGraphics canvas;
PGraphics trailCanvas;
PGraphics noTrailCanvas;

SyphonServer server;
NetAddress videoMapperAddress;
NetAddress trackerMasterAddress;

TouchManager touchManager;
int touchTimeStamp;


OscP5 oscP5;
NetAddress myRemoteLocation;

int canvasW;         // testmode the actual size of the texture to display
int canvasH;         // testmode the actual size of the texture to display
boolean[][] inFramePixels;

ArrayList<Ephemer> ephemers;        
IntList touchIds;
IntList[] currentEphemers;     // stores an intlist with touch ids for each ephemer  .ephemer's ind as key and touch ids as values
int     currentEphemer;
int maxEphemers = 10;         // max number of ephemers
int maxNodes = 50;            // max number of nodes in an ephemer
float maxVelocity = 5;

float   gravity = .01;

float   ephemerFadeRate = 0.9996;    // global fade rate . each added node reduces the faderate by factor 0.999
int     nodeForceDivisor = 1000;     // used to adjust the force calc between nodes. the higher the value, the weaker the force 
float   nodeDrag = 0.002;          // fluid drag coefficient
boolean setFrame = true;
int minDuration = 20;      // min duration between nodes in ms
float minDistance = 5;    // min distance between nodes
int lastUserInputTime = 0;  // millis of last user input
int upperScreenLimit;
int lowerScreenLimit;

void setup() {
  // screen size
  surface.setResizable(true);
  fullScreen(P3D);
  //  fullScreen(SPAN);
  frameRate(60);
  //  size(1280, 180, P3D);
  //size(1680, 900);  // p3 testmode
  canvasW = width;
  canvasH = height; 
  upperScreenLimit = 72;  // upper y bound value, used to reduce the height 
  lowerScreenLimit = canvasH - 117 ;

  inFramePixels = new boolean[canvasW][canvasH];

  // tracking
  kinect = new Kinect(this);
  kinect.initVideo();
  video = kinect.getVideoImage();
  //String[] cameras = Capture.list();
  //printArray(cameras);
  //video = new Capture(this, cameras[15]);
  //video.start();

  // load Preferences
  if (myPrefs.loadPref() == 0) {  // loaded ok
    for (int i = 0; i < projectionPoints.length; i++) {
      projectionPoints[i] = new PVector(myPrefs.getFloat("p"+i+"x"), myPrefs.getFloat("p"+i+"y"));
    }
    threshold = myPrefs.getFloat("threshold");
    distThreshold = myPrefs.getFloat("distThreshold");
    maxBlobSize = myPrefs.getInt("maxBlobSize");
    minRedValue = myPrefs.getInt("minRedValue");
    maxLife = myPrefs.getInt("maxLife");
  } else {
    projectionPoints[0] = new PVector(10, 10);
    projectionPoints[1] = new PVector(video.width - 10, 10);
    projectionPoints[2] = new PVector(video.width - 10, video.height - 10);
    projectionPoints[3] = new PVector(10, video.height - 10);
  }
  calcProjPixels();

  // set up a new OSC network interface
  oscP5 = new OscP5(this, 12000);

  //canvas = createGraphics(canvasW, canvasH, P3D); // create the canvas to render to and used to transmt via syphon
  canvas = createGraphics(canvasW, canvasH); // testmode create the canvas to render to and used to transmt via syphon

  // set up a new sypon (i.e. texture) server
  //server = new SyphonServer(this, "Processing_Syphon");

  // register for video mapping
  videoMapperAddress = new NetAddress("127.0.0.1", 8400);
  OscMessage videoMapperMessage = new OscMessage("/SwitchSyphonClient");
  videoMapperMessage.add("ephemer_1_17"); // This must contain the same name as the Sketch
  videoMapperMessage.add("Processing_Syphon");
  videoMapperMessage.add(1.0); // the transparency of the the texture in the mapper, leave at 1.0
  oscP5.send(videoMapperMessage, videoMapperAddress);  // send this message to the mapper to display your image

  // register for tracking
  trackerMasterAddress = new NetAddress("127.0.0.1", 64000);
  OscMessage trackerMasterMessage = new OscMessage("/trackerMaster/requestTuiostream");
  trackerMasterMessage.add(12000); // the port you wish to receive touch information on
  oscP5.send(trackerMasterMessage, trackerMasterAddress);  // subscribe to tuio-stream

  ephemers = new ArrayList<Ephemer>();
  myRemoteLocation = new NetAddress("127.0.0.1", 57120);    // SC port
  trailCanvas = createGraphics(canvasW, canvasH);
  noTrailCanvas = createGraphics(canvasW, canvasH);
  currentEphemers = new IntList[maxEphemers];
  for (int i = 0; i < maxEphemers; i++) {
    currentEphemers[i] = new IntList();
  }
  touchManager = new TouchManager();
  touchTimeStamp = touchManager.currentTimeStamp;
  trailCanvas.beginDraw();
  trailCanvas.endDraw();
  trailCanvas.loadPixels();
  println("width: " + width + " height: " + height);
}

void draw() {
  if (setFrame) {
    frame.setLocation(0, 100);
    setFrame = false;
  }
  if (setupMode) {
    background(0);
    image(video, 0, 0);
    handleLaserTracking();

    stroke(0, 255, 0);
    noFill();
    rect(0, 0, video.width, video.height);  // cam picture
    PVector m = translateCamPoint(mouseX, mouseY);
    ellipse(m.x, m.y, 10, 10);
    for (Blob b : blobs) {
      b.show();
    }
    strokeWeight(2);
    stroke(255, 255, 255);
    rectMode(CORNER);
    rect(0, upperScreenLimit, canvasW-2, lowerScreenLimit - upperScreenLimit);
    quad(
      projectionPoints[0].x, 
      projectionPoints[0].y, 
      projectionPoints[1].x, 
      projectionPoints[1].y, 
      projectionPoints[2].x, 
      projectionPoints[2].y, 
      projectionPoints[3].x, 
      projectionPoints[3].y 
      );
    textAlign(RIGHT);
    fill(250);
    //text(currentBlobs.size(), width-10, 40);
    //text(blobs.size(), width-10, 80);
    textSize(24);
    text("distance threshold: " + distThreshold, width-10, 25 + upperScreenLimit);
    text("color threshold: " + threshold, width-10, 50 + upperScreenLimit);  
    text("max blob size: " + maxBlobSize, width-10, 75 + upperScreenLimit);
    text("min red value: " + minRedValue, width-10, 100 + upperScreenLimit);
    text("framerate: " + (int)frameRate, width-10, 125 + upperScreenLimit);
    text("maxLife: " + maxLife, width-10, 175 + upperScreenLimit);
    text(touchtext, width-10, 150 + upperScreenLimit);
  } else {  
    // not setup
    background(0, 0, 0); 
    trailCanvas.beginDraw();
    noTrailCanvas.beginDraw();
    noTrailCanvas.clear();
    //  if (mousePressed) {
    //    int eId = getEphemerIdForTouchId(-1);  // touch id -1 = mouse
    //    if ( eId > -1) handleAdditionalUserInput(mouseX*canvasW/width, mouseY*canvasH/height, eId);
    //  }
    handleLaserTracking();
    for (int i = 0; i < ephemers.size (); i++) {
      Ephemer ephemer = ephemers.get(i);
      if (ephemer.alive) {
        PVector sum = new PVector();
        PVector force = new PVector();
        for (int j = 0; j < ephemers.size (); j++) {
          Ephemer otherEphemer = ephemers.get(j);
          if ((otherEphemer.alive) && (i != j)) {
            force = otherEphemer.attract(ephemer);
            otherEphemer.applyForce(force);
            // currentNode to other currentNode steering test
            //force = PVector.sub(otherEphemer.nodes.get(otherEphemer.currentNode).location, ephemer.nodes.get(ephemer.currentNode).location);
            float distance = force.mag();
            if ((distance > 0) && (distance < 500)) {
              force.normalize();
              sum.add(force);
            }
          }
        }
        sum.setMag(maxVelocity * 60.0 / frameRate);  // set max velocity
        sum.sub(ephemer.nodes.get(ephemer.currentNode).velocity);
        sum.limit(0.02);  // limit steering force
        //ephemer.nodes.get(ephemer.currentNode).applyForce(sum);

        ephemer.update();
        ephemer.display();
        ephemer.sendOSC();
        ephemer.advanceToNextNode();
        if (ephemer.recMode == false) ephemer.checkAndCloseEphemer();
      }
    }
    trailCanvas.endDraw();
    noTrailCanvas.endDraw();

    canvas.beginDraw(); // all the drawing has to happen in the canvas in order to share across syphon
    canvas.background(0, 0, 0);
    canvas.image(trailCanvas, 0, 0);
    canvas.image(noTrailCanvas, 0, 0);
    canvas.fill(0);
    canvas.noStroke();
    canvas.rect(0, 0, canvasW, upperScreenLimit);
    canvas.rect(0, lowerScreenLimit, canvasW, canvasH - lowerScreenLimit );
    canvas.fill(255);
    canvas.textAlign(RIGHT);
    if (showFrameRate) canvas.text("framerate: " + (int)frameRate, width-10, 12);
    canvas.endDraw();
    //server.sendImage(canvas); // now send the image across syphon to the mapping software
    image(canvas, 0, 0, width, height); // and draw your local small version
    //image(canvas, 0, 0); // and draw your local small version


    //image(trailCanvas, 0, 0);
    //image(noTrailCanvas, 0, 0);
    if (millis() >= lastUserInputTime + (10000 * 60/frameRate)) {
      resurrect();
    }

    if (frameCount % int(pow(frameRate, 0.7)) == 0) {
      //if (millis() >= trailFadeLastTime + fadeInterval) {
      //trailFadeLastTime = millis();
      fadeGraphics(trailCanvas, 1);
    }

    //println("inputTime: "+lastUserInputTime);
    //if (frameCount % 100 == 0) println("frameRate: ", frameRate);
  }
}

void handleAdditionalUserInput(float x, float y, int id) {
  // attract / repell nodes of all ephemers from mousepointer 
  //PVector mouse = new PVector(x, y);
  for (int i = 0; i < ephemers.size (); i++) {
    Ephemer ephemer = ephemers.get(i); 
    if ((!ephemer.recMode) && (ephemer.id == id)) {
      //if ((keyCode == SHIFT) && (keyPressed == true))ephemer.repellFromLocation(mouse);
      //else ephemer.attractToLocation(mouse);
      //println("currentEphemer : ", currentEphemer);}
    }
  }
}


void mousePressed() { 
  if (setupMode) {
    float recDist = 10000;
    int recIndex = 0;
    PVector mouse = new PVector(mouseX, mouseY);
    for (int i = 0; i < projectionPoints.length; i++) {
      float dist = PVector.dist(projectionPoints[i], mouse);
      if (dist < recDist) { 
        recDist = dist;
        recIndex = i;
      }
    }
    projectionPoints[recIndex] = mouse;
    calcProjPixels();
  } else {
    touchesBegan(mouseX*canvasW/width, mouseY*canvasH/height, -1);    // mouse has touchid -1
  }
}


void calcProjPixels() {
  pMinX = (int)min(projectionPoints[0].x, projectionPoints[3].x);
  pMinY = (int)min(projectionPoints[0].y, projectionPoints[1].y);
  pMaxX = (int)(max(projectionPoints[1].x, projectionPoints[2].x));
  pMaxY = (int)(max(projectionPoints[2].y, projectionPoints[3].y));
  // calc in frame pixels
  PVector p;
  for (int x = 0; x < canvasW; x++ ) {
    for (int y = 0; y < canvasH; y++ ) {
      p = translateCamPoint(x, y);
      if ((p.x >= 0) && (p.x < canvasW) && (p.y >= upperScreenLimit) && (p.y < lowerScreenLimit)) {
        inFramePixels[x][y] = true;
      } else {
        inFramePixels[x][y] = false;
      }
    }
  }
}
void touchesBegan(float x, float y, int tId) {
  println("nbr alive: "+ getNbrOfAliveEphemers());
  if (getNbrOfAliveEphemers() >= maxEphemers) {
    // repell ephemers
    PVector mouse = new PVector(x, y);
    for (int i = 0; i < ephemers.size (); i++) {
      Ephemer eph = ephemers.get(i); 
      eph.attractToLocation(mouse);
    }
  } else {
    // check if within an ephemer
    int eId = idOfEphemerAtLocation(x, y);

    // touch in an ephemer
    if (eId > -1) { 
      IntList touchIds = currentEphemers[eId];
      boolean touchIdFound = false;
      for (int i = 0; i < touchIds.size (); i++) {
        if (tId == touchIds.get(i)) touchIdFound = true;
      }
      if (!touchIdFound)  touchIds.append(tId);      // append touch id to ephemer id's touchIds int list
    } else {                                         
      // touch out of existing ephemers
      if (ephemers.size() < maxEphemers) {  // previous touch was not in an ephemer. create a new one
        // create new ephemer
        Ephemer ephemer = new Ephemer(x, y, ephemers.size(), millis());  // create a new ephemer at current location and add a node
        ephemers.add(ephemer);
        ephemer.addNode(x, y, millis());
        currentEphemers[ephemers.size()-1].append(tId);  // add touch id to new ephemer
      } else { // overwrite dead ephemers 
        int eID = getDeadEphemer();
        if (eID >= 0) { // found one
          Ephemer ephemer = new Ephemer(x, y, eID, millis());  // create a new ephemer and replace dead one
          ephemers.set(eID, ephemer);
          ephemer.addNode(x, y, millis());
          currentEphemers[eID].clear();  
          currentEphemers[eID].append(tId);  // add touch id to new ephemer
        }
      }
    }
  }
  //println("touchesBegan: touchID: ", tId, " ephemerID: ", eId, " x: ", x, " y: ", y);
}

int getNbrOfAliveEphemers() {
  int aliveCount = 0;
  for (Ephemer e : ephemers) { // search for the longest dead ephemer
    if (e.alive) {
      aliveCount++;
    }
  }
  return aliveCount;
}

int getDeadEphemer() {
  int maxTime = 1000000000;
  int eID = -1;
  for (Ephemer e : ephemers) { // search for the longest dead ephemer
    if ((!e.alive) && (e.millisDead < maxTime)) {
      maxTime = e.millisDead;
      eID = e.id;
    }
  }
  return eID;
}

void mouseDragged() {
  if (setupMode) {
  } else {
    //  touchesMoved(mouseX*canvasW/width, mouseY*canvasH/height, pmouseX*canvasW/width, pmouseY*canvasH/height, -1);
    touchesMoved(mouseX*canvasW/width, mouseY*canvasH/height, -1);
  }
}

void touchesMoved(float x, float y, int tId) {
  int currentMillis = millis();
  //println("dragged: ", milli, " delta: ", milli-millisOfBegin);
  int eId = getEphemerIdForTouchId(tId);

  if ((eId >= 0) && (eId < ephemers.size())) {  // in an ephemer
    Ephemer ephemer = ephemers.get(eId);
    if (ephemer.recMode) {
      // rec mode -> add nodes
      Node prevNode = ephemer.nodes.get(ephemer.nodes.size()-1);    // get previous node
      int dur = currentMillis - ephemer.millis - prevNode.millis;    // calc millis since last node added
      float dist = PVector.dist(prevNode.location, new PVector(x, y));
      if ((dur >= minDuration) && (dist >= minDistance)) {
        prevNode.duration = dur;  // set duration for previous node  
        ephemer.addNode(x, y, currentMillis);
      }
    } else {    
      // not rec mode -> attract
      PVector mouse = new PVector(x, y);
      for (int i = 0; i < ephemers.size (); i++) {
        Ephemer eph = ephemers.get(i); 
        if (eId == eph.id) {
          eph.handled = true;
          eph.attractToLocation(mouse);
        }
      }
    }
  } else {
    if (getNbrOfAliveEphemers() >= maxEphemers) {
      // repell ephemers
      PVector mouse = new PVector(x, y);
      for (int i = 0; i < ephemers.size (); i++) {
        Ephemer eph = ephemers.get(i); 
        eph.attractToLocation(mouse);
      }
    }
  }
  //println("touchesMoved: touchID: ", tId, " ephemerID: ", eId, " x: ", x, " y: ", y);
}


void mouseReleased() {
  if (setupMode) {
  } else {
    touchesEnded(-1);
  }
}

void touchesEnded(int tId) {
  int eId = getEphemerIdForTouchId(tId);
  if (eId > -1) {  // touch ended in an ephemer. 
    if (ephemers.size() > eId) {  // if ephemer really exists
      Ephemer ephemer = ephemers.get(eId);
      if (ephemer.recMode) {
        ephemer.releaseTime = millis() - ephemer.millis;
        ephemer.nodes.get(ephemer.nodes.size()-1).duration = millis() - ephemer.millis - ephemer.nodes.get(ephemer.nodes.size()-1).millis;
        ephemer.recMode = false;
      } else {
        ephemer.handled = false;
        // tbd ephemer.timeFactor = 0;
      }
    }
    IntList touchIds = currentEphemers[eId];
    int touchIdIdx = -1;
    for (int i = 0; i < touchIds.size (); i++) {
      if (touchIds.get(i) == tId) touchIdIdx = i;
    }
    if (touchIdIdx > -1) {
      touchIds.remove(touchIdIdx);    // remove touch id from touch id list of particular ephemer
    }
  }
  lastUserInputTime = millis();
  //println("touchesEnded: touchID: ", tId, " ephemerID: ", eId);
}

int idOfEphemerAtLocation(float x, float y) {    // get index of nearest ephemer. -1 if not in an ephemer
  float distance = canvasW;  // record distance
  int eId = -1;
  PVector location = new PVector(x, y);
  for (int i = 0; i < ephemers.size (); i++) {
    Ephemer ephemer = ephemers.get(i);
    if ((ephemer.alive) && (ephemer.hit(x, y))) {
      PVector center = new PVector(ephemer.centerX, ephemer.centerY);
      if (distance > location.dist(center)) {
        distance = location.dist(center);
        eId = ephemer.id;
      }
    }
  } 
  //println("id of ephemer: ", id);
  return eId;
}

void keyPressed() {
  if (key == ' ') {  //
    ephemers.clear();
    OscMessage myMessage = new OscMessage("/exit");
    oscP5.send(myMessage, myRemoteLocation);
    trailCanvas.beginDraw();
    trailCanvas.background(0);
    trailCanvas.endDraw();
    image(trailCanvas, 0, 0);
  } else if (key == 'a') {  //
    //trailCanvas.loadPixels();
    // get alpha value
    color c =  trailCanvas.pixels[mouseY*canvasW/width+mouseX];
    println("a:", c>>24&0xFF, "  r:", c>>16&0xFF, "  g:", c>>8&0xFF, "  b:", c&0xFF, "  br:", brightness(c)) ;
  } else if (key == 's') {
    setupMode = !setupMode;
    if (!setupMode) savePrefs();
    //println(setupMode);
  } else if (key == 'f') {
    showFrameRate = !showFrameRate;
  } else if (key == 'z') {
    distThreshold+=1;
  } else if (key == 'h') {
    distThreshold-=1;
  } else if (key == 'u') {
    threshold+=5;
  } else if (key == 'j') {
    threshold-=5;
  } else if (key == 'i') {
    maxBlobSize+=5;
  } else if (key == 'k') {
    maxBlobSize-=5;
  } else if (key == 'o') {
    minRedValue+=1;
  } else if (key == 'l') {
    minRedValue-=1;
  } else if (key == 'p') {
    maxLife+=1;
  } else if (key == 'ö') {
    maxLife-=1;
  } else if (key == CODED) {
    if (keyCode == UP) {
      deg++;
    } else if (keyCode == DOWN) {
      deg--;
    }
    deg = constrain(deg, 0, 30);
    kinect.setTilt(deg);
  }
}



void exit() {
  println("exiting");
  OscMessage myMessage = new OscMessage("/exit");

  /* send the message */
  oscP5.send(myMessage, myRemoteLocation);


  // save preferences
  //savePrefs();

  super.exit();
}

void savePrefs() {
  for (int i = 0; i < projectionPoints.length; i++) {
    myPrefs.setNumber("p"+i+"x", projectionPoints[i].x, false);
    myPrefs.setNumber("p"+i+"y", projectionPoints[i].y, false);
  }


  myPrefs.setNumber("threshold", threshold, false);
  myPrefs.setNumber("distThreshold", distThreshold, false);
  myPrefs.setNumber("maxBlobSize", maxBlobSize, false);
  myPrefs.setNumber("minRedValue", minRedValue, false);
  myPrefs.setNumber("maxLife", maxLife, false);

  myPrefs.savePref();
}

void fadeGraphics(PGraphics c, int fadeAmount) {
  c.beginDraw();
  c.loadPixels();

  // iterate over pixels
  for (int i = upperScreenLimit * canvasW; i < (c.pixels.length - canvasW * (canvasH - lowerScreenLimit)); i++) {

    // get alpha value
    //int alpha = c.pixels[i] >> 24 & 0xFF ;
    int r = c.pixels[i] >> 16 & 0xFF ;
    int g = c.pixels[i] >> 8 & 0xFF ;
    int b = c.pixels[i]  & 0xFF ;
    // reduce alpha value
    //alpha = max(0, (alpha - fadeAmount));
    //r = max(0, (r-(int)random(fadeAmount+1)));
    //g = max(0, (g-(int)random(fadeAmount+1)));
    //b = max(0, (b-(int)random(fadeAmount+1)));
    r = max(0, (r-fadeAmount));
    g = max(0, (g-fadeAmount));
    b = max(0, (b-fadeAmount));

    // assign color with new alpha-value
    //c.pixels[i] = alpha<<24 | (c.pixels[i] & 0xFFFFFF) ;
    c.pixels[i] = r<<16 | (c.pixels[i] & 0xFF00FFFF) ;
    c.pixels[i] = g<<8 | (c.pixels[i] & 0xFFFF00FF) ;
    c.pixels[i] = b | (c.pixels[i] & 0xFFFFFF00) ;
  }

  c.updatePixels();
  c.endDraw();
}


void oscEvent(OscMessage theOscMessage) {
  /* check if theOscMessage has the address pattern we are looking for. */

  if (theOscMessage.checkAddrPattern("/ephemerFadeRate")==true) {
    ephemerFadeRate = theOscMessage.get(0).floatValue();  
    for (int i = 0; i < ephemers.size (); i++) {
      ephemers.get(i).fadeRate = ephemerFadeRate;
    }
  } else if (theOscMessage.checkAddrPattern("/nodeForceDivisor")==true) {
    nodeForceDivisor = theOscMessage.get(0).intValue();  
    for (int i = 0; i < ephemers.size (); i++) {
      for (int j = 0; j < ephemers.get (i).nodes.size(); j++) {
        ephemers.get(i).nodes.get(j).forceDivisor = nodeForceDivisor;
      }
    }
  } else if (theOscMessage.checkAddrPattern("/nodeDrag")==true) {
    nodeDrag = theOscMessage.get(0).floatValue();  
    for (int i = 0; i < ephemers.size (); i++) {
      for (int j = 0; j < ephemers.get (i).nodes.size(); j++) {
        ephemers.get(i).nodes.get(j).drag = nodeDrag;
      }
    }
  }

  // touch messages
  String oscAddress = theOscMessage.addrPattern();

  if ( oscAddress.equals("/tuio/2Dcur") )
  {
    String label = theOscMessage.get(0).stringValue();

    if (label.equals("fseq"))  // message end
    {
      int timeStamp = theOscMessage.get(1).intValue();

      touchManager.update(timeStamp);

      processTouch();
    } else if (label.equals("set"))
    {
      int touchId = theOscMessage.get(1).intValue();
      float touchX = theOscMessage.get(2).floatValue();
      float touchY = theOscMessage.get(3).floatValue();

      touchManager.update(touchId, touchX, touchY);
    }
  }
}

void processTouch() {
  ClusterGroup[] clusterGroups = touchManager.clusterGroups;

  for (int gI=0; gI<clusterGroups.length; ++gI)
  {
    ArrayList< Centroid > centrois = clusterGroups[gI].centroids;

    for (int cI=0; cI<centrois.size (); ++cI)
    {
      Centroid centroid = centrois.get(cI);
      int centroidId = centroid.ID;
      int centroidLifeTime = centroid.lifeTime;
      int centroidDeathTime = centroid.deathTime;
      float centroidXCoord = centroid.xCoord * 1280.0;
      float centroidYCoord = centroid.yCoord * 720.0;

      if ((centroid.lifeTime >= centroid.sMinLifeTime) && (centroid.deathTime == 0))
      {
        //ballsVisible[ centroidId ] = true;

        if (centroid.deathTime == 0)  // alive
        {
          // is centroidId in currentEphemers?
          if (getEphemerIdForTouchId(centroidId) > -1) {
            //            touchesMoved(centroidXCoord, centroidYCoord, centroid.prevXCoord * 1280.0, centroid.prevYCoord * 720.0, centroidId);
            touchesMoved(centroidXCoord, centroidYCoord, centroidId);
          } else {
            touchesBegan(centroidXCoord, centroidYCoord, centroidId);
            // (getEphemerIdForTouchId(-1) > -1)) handleAdditionalUserInput(mouseX*canvasW/width, mouseY*canvasH/height, -1);
          }
        }
      } else {
        touchesEnded(centroidId);
        //println("ended?");
      }
    }
  }
}

int getEphemerIdForTouchId(int tId) {  // returns ephemer id for touch id, or -1 if not assigned to an ephemer
  int eId = -1;  // init return value
  for (int i = 0; i < ephemers.size (); i++) {  
    IntList touchIds = currentEphemers[i];
    for (int j = 0; j < touchIds.size (); j++) {
      if (tId == touchIds.get(j)) {
        eId = i;
      }
    }
  }
  //println("e ID for touch ID: ",eId);
  return eId;
}

void handleLaserTracking() {
  video = kinect.getVideoImage();
  video.loadPixels();
  //image(video, 0, 0);

  ArrayList<Blob> currentBlobs = new ArrayList<Blob>();
  //PVector p;

  // Begin loop to walk through every pixel
  for (int x = pMinX; x < pMaxX; x++ ) {
    for (int y = pMinY; y < pMaxY; y++ ) {
      // check if pixel within tracking frame
      if (inFramePixels[x][y]) {
        int loc = x + y * video.width;
        if (loc < video.pixels.length) {
          // What is current color
          color currentColor = video.pixels[loc];
          float r1 = red(currentColor);
          float g1 = green(currentColor);
          float b1 = blue(currentColor);

          float d = r1 - ((g1 + b1) / 2.0);
          if ((r1 > minRedValue) && (d > threshold) && (g1 > minGreenValue)) {  // pixel is qualified

            boolean found = false;
            for (Blob b : currentBlobs) {
              if (b.isNear(x, y)) {  // pixel is within distthreshold from blob center
                b.add(x, y, currentColor);
                found = true;
                break;
              }
            }

            if (!found) {
              Blob b = new Blob(x, y, currentColor);
              currentBlobs.add(b);
            }
          }
        }
      }
    }
  }

  for (int i = currentBlobs.size()-1; i >= 0; i--) {
    //if ((currentBlobs.get(i).size() > maxBlobSize) || (currentBlobs.get(i).size() == 0)) { // not too big, but more than 1 pixel
    if (currentBlobs.get(i).size() > maxBlobSize) { // not too big, but more than 1 pixel
      currentBlobs.remove(i);
    }
  }

  // There are no blobs!
  if (blobs.isEmpty() && currentBlobs.size() > 0) {
    //println("Adding blobs!");
    for (Blob b : currentBlobs) {
      b.id = blobCounter;
      blobs.add(b);
      blobCounter++;
    }
  } else if (blobs.size() <= currentBlobs.size()) {
    // Match whatever blobs you can match
    for (Blob b : blobs) {
      float recordD = 1000;
      Blob matched = null;
      for (Blob cb : currentBlobs) {
        PVector centerB = b.getCenter();
        PVector centerCB = cb.getCenter();         
        float d = PVector.dist(centerB, centerCB);
        if (d < recordD && !cb.taken) {
          recordD = d; 
          matched = cb;
        }
      }
      if (matched != null) {
        matched.taken = true;
        b.become(matched);
      }
    }

    // Whatever is leftover make new blobs
    for (Blob b : currentBlobs) {
      if (!b.taken) {
        b.id = blobCounter;
        blobs.add(b);
        blobCounter++;
      }
    }
  } else if (blobs.size() > currentBlobs.size()) {
    for (Blob b : blobs) {
      b.taken = false;
    }


    // Match whatever blobs you can match
    for (Blob cb : currentBlobs) {
      float recordD = 1000;
      Blob matched = null;
      for (Blob b : blobs) {
        PVector centerB = b.getCenter();
        PVector centerCB = cb.getCenter();         
        float d = PVector.dist(centerB, centerCB);
        if (d < recordD && !b.taken) {
          recordD = d; 
          matched = b;
        }
      }
      if (matched != null) {
        matched.taken = true;
        matched.lifespan = maxLife;
        matched.become(cb);
      }
    }

    for (int i = blobs.size() - 1; i >= 0; i--) {
      Blob b = blobs.get(i);
      if (!b.taken) {
        if (b.checkLife()) {
          touchesEnded(b.id);
          touchtext = "touch ended: " + b.id;
          blobs.remove(i);
        }
      }
    }
  }


  for (Blob b : blobs) {
    // is blob Id in currentEphemers?
    PVector bV = translateCamPoint((b.maxx - b.minx)* 0.5 + b.minx, (b.maxy - b.miny)* 0.5 + b.miny);
    if ((bV.x >= 0) && (bV.y >= upperScreenLimit) && (bV.x < canvasW) && (bV.y < lowerScreenLimit)) {// onscreen
      if (getEphemerIdForTouchId(b.id) > -1) {
        touchesMoved(bV.x, bV.y, b.id);
        touchtext = "touch moved: " + b.id;
      } else {
        touchesBegan(bV.x, bV.y, b.id);
        touchtext = "touch began: " + b.id;
      }
    }
  }
}


PVector translateCamPoint (float x, float y) {
  PVector[] crossPoints = new PVector[4];
  // calculate x of left crosspoint 
  crossPoints[0] = new PVector (projectionPoints[0].x + (projectionPoints[3].x - projectionPoints[0].x) / (projectionPoints[3].y - projectionPoints[0].y) * (y - projectionPoints[0].y), y);
  // calculate x of right crosspoint 
  crossPoints[1] = new PVector (projectionPoints[1].x + (projectionPoints[2].x - projectionPoints[1].x) / (projectionPoints[2].y - projectionPoints[1].y) * (y - projectionPoints[1].y), y);
  // calculate y of upper crosspoint *--------|-------*
  crossPoints[2] = new PVector (x, projectionPoints[0].y + (projectionPoints[1].y - projectionPoints[0].y) / (projectionPoints[1].x - projectionPoints[0].x) * (x - projectionPoints[0].x));
  // calculate y of lower crosspoint *--------|-------*
  crossPoints[3] = new PVector (x, projectionPoints[3].y + (projectionPoints[2].y - projectionPoints[3].y) / (projectionPoints[2].x - projectionPoints[3].x) * (x - projectionPoints[3].x));

  float tX = (x - crossPoints[0].x) / (crossPoints[1].x - crossPoints[0].x) * width;
  float tY = (y - crossPoints[2].y) / (crossPoints[3].y - crossPoints[2].y) * (lowerScreenLimit - upperScreenLimit) + upperScreenLimit;
  /*if (setupMode) {
   for (PVector p : crossPoints) {
   fill(0,255,0);
   ellipse(p.x, p.y, 10, 10);
   }
   }*/

  return new PVector(tX, tY);
}

void captureEvent(Capture video) {
  video.read();
}

void resurrect() {
  if (getNbrOfAliveEphemers() < 3) {
    int eID = getDeadEphemer();
    if (eID >= 0) { // found one
      Ephemer eph = ephemers.get(eID);
      eph.ephemerResurrect();
      lastUserInputTime = millis();
    }
  }
}
