class Node {
  PVector location;
  PVector velocity;
  float veloMag;
  PVector acceleration;           // used for velo calc, will be set to 0 in update()
  PVector currentAcceleration;    // copied from acceleration before reset, used for sending OSC  
  float mass;
  float level;
  int millis;        // node creation in milliseconds after ephemer creation
  int duration;      // node duration to next node in ms 
  float diameter;
  float cDiameter;  // current diameter
  float diamCoeff;  // cDiameter * diamCoeff = actual diameter
  float diamDecayRate;
  float normDistance;  // ruhedistanz zwischen nodes
  //int numberOfFrames;
  boolean direction;
  int forceDivisor;
  float drag;
  float angle;      // angle in radians between previous and next node
  float maxspeed = 10;
  float maxforce = 0.01;

  Node (float x, float y, int _millis) {
    location = new PVector(x, y);
    velocity = new PVector(0, 0);
    acceleration = new PVector(0, 0);
    currentAcceleration = new PVector(0, 0);
    level = 255;
    millis = _millis;
    normDistance = 20;
    //numberOfFrames = 1;
    diameter = 8;
    direction = true;
    forceDivisor = nodeForceDivisor;
    drag = nodeDrag;
    diamDecayRate = 0.99;
  }

  void applyForce(PVector force) {
    //PVector f = PVector.div(force, numberOfFrames);
    //acceleration.add(f);
    acceleration.add(force);
  }

  void update() {
    velocity.add(acceleration);
    // friction: dampen any movement:
    //float f = calcFrictionAtLocation();
    //velocity.mult(f);
    velocity.limit(maxVelocity * 60.0 / frameRate);
    location.add(velocity);
    checkBounds();
    veloMag = velocity.mag();
    currentAcceleration = acceleration.copy();
    //currentAcceleration = acceleration.get();
    acceleration.mult(0);
  }

  void display(float d, boolean now) {
    if (direction) cDiameter = (cDiameter + constrain(veloMag, 0.1, 20)/1.0) ;
    else           cDiameter = (cDiameter - constrain(veloMag, 0.1, 20)/1.0) ;
    diamCoeff = diamCoeff * diamDecayRate;
    if (cDiameter < 1) {
      //     if (cDiameter < 1) {
      cDiameter = 1;
      direction = true;
    } else if ((cDiameter > diameter) || (now)) {
      direction = false;
      cDiameter = diameter;
      if (now) diamCoeff = 1;
    }

    //    trailCanvas.stroke(constrain(mouseX, 0, 255), constrain(mouseY, 0, 255));
    trailCanvas.stroke(level, min((level/255)*55*veloMag + 10, 127));  // alpha related to level and velocity
    //    trailCanvas.stroke(level, cDiameter*diamCoeff*10);  // alpha related to level and velocity
    trailCanvas.point(location.x, location.y);
    noTrailCanvas.noStroke();
    noTrailCanvas.fill(level);
    //    noTrailCanvas.ellipse(location.x, location.y, cDiameter*pow(numberOfFrames, 0.33333), cDiameter*pow(numberOfFrames, 0.333333));
    noTrailCanvas.ellipse(location.x, location.y, cDiameter*diamCoeff, cDiameter*diamCoeff);
  }

  PVector attract(Node n) {
    PVector force = PVector.sub(location, n.location);
    float distance = force.mag() - normDistance;
    force.normalize();

    float strength = distance/forceDivisor;
    force.mult(strength);
    return force;
  }


  PVector repulse(Node n) {
    PVector force = PVector.sub(location, n.location);
    //float distance = force.mag();
    //distance = constrain(distance, 10.0, 2000.0);                 // Limiting the distance to eliminate "extreme" results for very close or very far objects
    //force.normalize();                                            // Normalize vector (distance doesn't matter here, we just want this vector for direction

    //float strength = (g * mass * n.mass) / (distance * distance); // Calculate gravitional force magnitude

    float distance = max(force.mag(), 1);
    force.normalize();

    float strength = -0.005/distance;
    //force.mult(0);
    force.mult(strength);
    return force;
  }

  PVector repellFromLocation(PVector p) {
    PVector force = PVector.sub(location, p);
    float distance = max(force.mag(), 1);
    force.normalize();

    float strength = 100/distance;
    force.mult(strength);
    return force;
  }

  PVector attractToLocation(PVector p) {
    PVector force = PVector.sub(location, p);
    float distance = max(force.mag(), 100);
    force.normalize();

    float strength = -distance * 0.0005;
    force.mult(strength);
    return force;
  }

  PVector repellFromSide() {
    PVector force = new PVector(0, 0);
    float distance = 0;
    if (location.x < 0) {
      force = new PVector(1, 0);
      distance = -location.x;
    } else if (location.x > canvasW) {
      force = new PVector(-1, 0);
      distance = location.x - canvasW;
    } else if (location.y < upperScreenLimit + 20){
      force = new PVector(0, 1);
      distance = pow(-location.y + upperScreenLimit + 20, 1.5);
    } else if (location.y > lowerScreenLimit - 20){
      force = new PVector(0, -1);
      distance = location.y - lowerScreenLimit + 20;
    }
    force.mult(distance/forceDivisor);
    return force;
  }


  void checkBounds() {
    //     if ((location.x > width) || (location.x < 0)) {
    //      velocity.x = velocity.x * -1;
    //    }
    //    if (((location.y > canvasH - 10) && (location.y <= canvasH)) || ((location.y < 10) && (location.y >= 0))) {
    //    velocity.x = velocity.x * 0.5;
    //  velocity.y = velocity.y * 0.5;
    // }
    if (location.y + cDiameter*diamCoeff/2.0 >= lowerScreenLimit  || location.y - cDiameter*diamCoeff/2.0 < upperScreenLimit) {
      velocity.y = velocity.y * -0.9;
      if (location.y - cDiameter*diamCoeff/2.0 < upperScreenLimit) location.y = upperScreenLimit + cDiameter*diamCoeff/2.0;
      else location.y = lowerScreenLimit - 1 - cDiameter*diamCoeff/2.0;
      //println("bounds x:", location.x, " y:", location.y, " v.y:", velocity.y);
    }
  }

  PVector drag() {
    // tbd drag depending on trailCanvas. brighter -> less drag
    float speed = veloMag;
    float dragMagnitude;
    if (location.y > canvasH - 20 || location.y < 20) dragMagnitude = 8 * drag * speed * speed;    // drag is higher on the lower/upper edge
    else dragMagnitude = drag * speed * speed;
    PVector dragForce = velocity.copy();
    dragForce.mult(-1);
    dragForce.normalize();
    dragForce.mult(dragMagnitude);
    return dragForce;
  }


  float calcFrictionAtLocation() {
    //trailCanvas.loadPixels(); 
    float f = veloMag*0.001;
    f = max(0, 1-f);
    if ((location.x < canvasW) && (location.y < canvasH) && (location.x>0) && (location.y>0)) {
      int b = trailCanvas.pixels[(int)(location.y*canvasW +location.x)] & 0xFF;       // get blue value , rgb all the same
      return f*drag;              // returned friction tends to 1 for brighter pixels
    } else {
      return f*drag;
    }
  }

  PVector attractToBrightestPixel() {
    PVector force = new PVector(0, 0);
    int newX = -1;
    int newY = -1;
    int x = (int)location.x;  // node center
    int y = (int)location.y;
    if ((x >= 0) && (x < canvasW) && (y >= 0) && (y < canvasH)) {  // within screen
      int startX = max(x - 1, 0);
      int startY = max(y - 1, 0);
      int endX = min(x + 1, canvasW - 1);
      int endY = min(y + 1, canvasH - 1);
      int brightness = trailCanvas.pixels[y * canvasW + x] & 0xFF;       // get blue value of node, rgb all the same
      for (int i = startX; i <= endX; i++) {  // check neighbours
        for (int j = startY; j <= endY; j++) {
          if ((i != x) && (j != y)) {
            if (brightness < (trailCanvas.pixels[j*canvasW + i] & 0xFF)) {  // look for brightest pixel
              brightness = (trailCanvas.pixels[j*canvasW + i] & 0xFF);
              newX = i;
              newY = j;
            }
          }
        }
      }
      if (newX > -1) {
        force = new PVector(newX-x, newY-y);
        force.normalize();
        force.mult((brightness-(trailCanvas.pixels[y * canvasW + x] & 0xFF)) * 0.0001); 
        //force.mult(0.05);
      }
    }
    return force;
  }

  PVector repellFromBrightestPixel() {
    PVector force = new PVector(0, 0);
    int newX = -1;
    int newY = -1;
    int x = (int)location.x;  // node center
    int y = (int)location.y;
    if ((x >= 0) && (x < canvasW) && (y > upperScreenLimit) && (y < lowerScreenLimit - 1)) {  // within screen and not top or bottom
      int startX = max(x - 1, 0);
      int startY = max(y - 1, 0);
      int endX = min(x + 1, canvasW - 1);
      int endY = min(y + 1, canvasH - 1);
      int brightness = trailCanvas.pixels[y * canvasW + x] & 0xFF;       // get blue value of node, rgb all the same
      for (int i = startX; i <= endX; i++) {  // check neighbours
        for (int j = startY; j <= endY; j++) {
          if ((i != x) || (j != y)) {
            if (brightness < (trailCanvas.pixels[j*canvasW + i] & 0xFF)) {  // look for brightest pixel
              brightness = (trailCanvas.pixels[j*canvasW + i] & 0xFF);
              newX = i;
              newY = j;
            }
          }
        }
      }
      if (newX > -1) {
        force = new PVector(newX-x, newY-y);
        force.normalize();
        force.mult((brightness-(trailCanvas.pixels[y * canvasW + x] & 0xFF)) * -0.0001); 
        //force.mult(0.05);
      }
    } else if ((x >= 0) && (x < canvasW) && ((y == upperScreenLimit) || (y == lowerScreenLimit - 1))) {
      // if (y == upperScreenLimit) force = new PVector(0, 1);
      //else  force = new PVector(0, -1);
      //force.mult((255-(trailCanvas.pixels[y * canvasW + x] & 0xFF)) * 0.001 );
    }
    return force;
  }


  PVector attractToDarkestPixel() {
    PVector force = new PVector(0, 0);
    int newX = -1;
    int newY = -1;
    int x = (int)location.x;  // node center
    int y = (int)location.y;
    if ((x >= 0) && (x < canvasW) && (y >= 0) && (y < canvasH)) {  // within screen
      int startX = max(x - 1, 0);
      int startY = max(y - 1, 0);
      int endX = min(x + 1, canvasW - 1);
      int endY = min(y + 1, canvasH - 1);
      int brightness = trailCanvas.pixels[y * canvasW + x] & 0xFF;       // get blue value of node, rgb all the same
      for (int i = startX; i <= endX; i++) {  // check neighbours
        for (int j = startY; j <= endY; j++) {
          if ((i != x) && (j != y)) {
            if (brightness > (trailCanvas.pixels[j*canvasW + i] & 0xFF)) {  // look for darkest pixel
              brightness = (trailCanvas.pixels[j*canvasW + i] & 0xFF);
              newX = i;
              newY = j;
            }
          }
        }
      }
      if (newX > -1) {
        force = new PVector(newX-x, newY-y);
        force.normalize();
        force.mult(((trailCanvas.pixels[y * canvasW + x] & 0xFF) - brightness) * 0.00001); 
        //force.mult(0.01);
      }
    }
    return force;
  }

  PVector steerToDarkestPixel() {
    PVector desired = new PVector(0, 0);
    int newX = -1;
    int newY = -1;
    int x = (int)location.x;  // node center
    int y = (int)location.y;
    if ((x >= 0) && (x < canvasW) && (y >= 0) && (y < canvasH)) {  // within screen
      int startX = max(x - 1, 0);
      int startY = max(y - 1, 0);
      int endX = min(x + 1, canvasW - 1);
      int endY = min(y + 1, canvasH - 1);
      int brightness = trailCanvas.pixels[y * canvasW + x] & 0xFF;       // get blue value of node, rgb all the same
      for (int i = startX; i <= endX; i++) {  // check neighbours
        for (int j = startY; j <= endY; j++) {
          if ((i != x) && (j != y)) {
            if (brightness > (trailCanvas.pixels[j*canvasW + i] & 0xFF)) {  // look for darkest pixel
              brightness = (trailCanvas.pixels[j*canvasW + i] & 0xFF);
              newX = i;
              newY = j;
            }
          }
        }
      }
      if (newX > -1) {  // darker pixel found
        desired = new PVector(newX-x, newY-y);
        desired.normalize();
        //desired.mult(20);
        //force.mult(((trailCanvas.pixels[y * canvasW + x] & 0xFF) - brightness) * 0.00001); 
        //force.mult(0.01);
      }
    }
    float d = desired.mag();
    if (d < 100) {
      float m = map(d, 0, 100, 0, maxspeed);
      desired.mult(m);
    } else desired.mult(maxspeed);
    PVector steer = PVector.sub(desired, velocity);
    steer.limit(maxforce);
    return steer;
  }
}
