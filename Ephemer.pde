class Ephemer {
  ArrayList<Node>nodes;
  //ArrayList<Leg>legs;
  int id;              // ephemer id number
  PVector origLocation;    // center of ephemer at creation time
  PVector location;    // center of ephemer
  PVector velocity;
  PVector acceleration;
  float   mass;          // ephemer mass = nbr of nodes * nodes.level 

  //int recPointer;     // where in the nodes array to record new or overwrite old nodes 

  float centerX;
  float centerY;
  float minX, minY, maxX = 0, maxY = 0;  // ephemer boundaries
  float minXr = canvasW, minYr = canvasH, maxXr = 0, maxYr = 0;  // ephemer boundaries record
  float startLevel;
  float minLevel;

  float fadeRate;
  float fadeAmount = 0.1;
  float shrink;  // not used
  boolean decaying;                 // first = false until level reaches max, then true and level decreases 

  boolean recMode;
  int distance;                     // norm distance between nodes
  PVector lastAddedNodeLocation;    // location of the last added Node
  float minNodeDistance;            // minimal distance for a new node to be created
  int minNodeInterval;              // minimal time interval for adding new nodes            
  int numberOfFramesCount = 0;
  boolean alive;
  //int loopMode;  // 0 = fwd , 1= pendulum
  boolean forward;  // true = fwd
  int eBufferZone = 10;              // padding, buffer zone around ephemer. used for interaction
  boolean closed;                    // if true, ephemer is ring shaped
  float closeDistance = 40;          // min distance to close an ephemer ( first and last nodes are connected)  

  int millis;                        // incept time
  int millisOfNextNode;              // milliseconds to next Node
  int millisOfLastAddedNode;
  int releaseTime;                   // millis of mouse release at creation time - millis
  int millisDead;                    // death time

  float timeFactor;               // next node interval * timeFactor, increase with lifetime, reset by user interaction
  int previousNode;
  int currentNode;                 // the actual play position within the nodes array                 
  int currentInterval;
  int nextNode;
  boolean currentNodeIsNew;        // indicates that the currentNode has advanced in a frame
  boolean directionChanged;        // forward true/false changed in a frame
  float probFactor;                // between 0.001 and 1.0 increases over 60s
  float[] ephemerAttractions;      // contains the attraction forces magnitude of other ephemers
  float attractionSum = 0;
  boolean handled;                // true when touched

  Ephemer(float x, float y, int _id, int _millis) {
    id = _id;
    millis = _millis;
    millisOfNextNode = millis;
    nodes = new ArrayList<Node>();
    origLocation = new PVector(x, y);
    location = new PVector(x, y);
    velocity = new PVector(0, 0);
    acceleration = new PVector(0, 0);
    shrink = 0.9995;
    fadeRate = ephemerFadeRate;
    location = new PVector(x, y);
    minX = x;
    minY = y;
    maxX = 0;
    maxY = 0;

    startLevel = 255;
    minLevel = 51;
    recMode = true;
    distance = 10;
    lastAddedNodeLocation = new PVector();
    minNodeDistance = 5;
    minNodeInterval = 20;
    alive = true;
    forward = true;
    closed = false;
    decaying = false;
    ephemerAttractions = new float[maxEphemers];

    addNode(x, y, millis);    // add first node
    ephemerNew();
  }

  void update() {
    velocity.add(acceleration);
    location.add(velocity);
    acceleration.mult(0);

    minX = canvasW*2;  // reset boundaries
    minY = canvasH*2;
    maxX = 0;
    maxY = 0;
    probFactor =  constrain((millis() - millis)/60000.0, 0.001, 1.0);  // probability increases over time
    attractionSum = 0;
    for (int i = 0; i < ephemerAttractions.length; i++) {
      attractionSum += ephemerAttractions[i];
    }
    attractionSum = attractionSum / ephemers.size();
    //println(id+" "+attractionSum);
    // adjust node levels and mass if current node
    if (currentNodeIsNew) {  // new for this frame
      Node node = nodes.get(currentNode);
      float level = node.level;
      mass = mass - level;
      level += attractionSum;
      if ((decaying) && (!handled))  level *= pow(fadeRate, 60.0/frameRate) ; 
      else           level *= 1 + (1 - fadeRate ) * 2.0;
      //      if (decaying)  level -= fadeAmount * 60.0/frameRate * nodes.size(); 
      //      else           level += fadeAmount * 60.0/frameRate * nodes.size();
      if (level > 255) {
        level = 255;
        decaying = true;
        //println("decaying");
      }
      if (decaying && (level < minLevel)) level = 0;    // mark dead
      node.level = level;
      mass = mass + level;
      //println(currentNode);

      if (currentNode == 0) { // check sporadically if ephemer is still alive     
        boolean aliveTest = false;
        for (Node n : nodes) {  
          if (n.level > 0) aliveTest = true;
        }
        if (!aliveTest) {
          ephemerDead();
        }
      }
    }

    // add ephemer velocity to all node locations first. ephemer velo = 0, if only 1 ephemer ???
    for (int i = 0; i < nodes.size (); i++) {
      Node node = nodes.get(i);
      node.location.add(velocity);
    }
    // calculate node to node attraction
    PVector force;
    for (int i = 0; i < nodes.size (); i++) {
      Node node = nodes.get(i);
      for (int j = 0; j < nodes.size (); j++) {
        // anziehungskraft zum vorangehenden node berechnen
        if ((j == i - 1) || (closed && (i == 0) && (j == nodes.size()-1))) {
          force = nodes.get(j).attract(node);
          force.mult(probFactor * mass / 2550);
          //          force.mult( 25.5 / mass );
          node.applyForce(force);  // add force
        }
        // anziehung zum nächsten node berrechnen
        else if ((j == i + 1) || (closed && (i == nodes.size()-1) && (j == 0))) {
          force = nodes.get(j).attract(node);
          force.mult(probFactor * mass / 2550);
          node.applyForce(force);
        } else if (i != j) {
          force = nodes.get(j).repulse(node);
          force.mult(probFactor * mass / 2550);
          node.applyForce(force);
        }
      }

      // node drag force.
      force = node.drag();
      force.mult(probFactor);
      node.applyForce(force);


      // background forces, attract node to brightest neighboring trail pixel 
      force = node.repellFromBrightestPixel();
      //      force = node.attractToBrightestPixel();
      //  force = node.attractToDarkestPixel();
      //force = node.steerToDarkestPixel();
      //force.mult(probFactor);
      node.applyForce(force);    // add force to acc

      // repell from the sides
      force = node.repellFromSide();
      node.applyForce(force);

      // calc force of currentNode
      //if (currentNodeIsNew) {
      // force = currentNodeForce();
      // node.applyForce(force);
      //}

      node.update();  // all forces are now added. add acc to velo, update location , reset acceleration

      // check min max ephemer boundaries
      if (node.location.x+eBufferZone>maxX) maxX = node.location.x+eBufferZone;
      if (node.location.x-eBufferZone<minX) minX = node.location.x-eBufferZone;
      if (node.location.y+eBufferZone>maxY) maxY = node.location.y+eBufferZone;
      if (node.location.y-eBufferZone<minY) minY = node.location.y-eBufferZone;
      location.x = (maxX-minX)/2.+minX;
      location.y = (maxY-minY)/2.+minY;
      maxXr = max(maxX, maxXr);
      maxYr = max(maxY, maxYr);
      minXr = min(minX, minXr);
      minYr = min(minY, minYr);
    }
    if (decaying && ((minX >= canvasW) || (maxX <= 0) || (minY >= canvasH) || (maxY <= 0))) {
      ephemerDead();
      //println("ephemer ", id, ": minX: ", minX, " maxX: ", maxX, " minY: ", minY, " maxY: ", maxY);
    }
    // calculate angle between nodes
    for (int i = 0; i < nodes.size (); i++) {
      Node node = nodes.get(i);
      // index des vorangehenden node berechnen
      int j = 0;
      if (i>0) {      // erster Punkt bleibt fix, ausser eph ist closed
        j = i - 1;
      } else if (closed) {
        j = nodes.size()-1;
      }
      PVector prev = PVector.sub(nodes.get(j).location, node.location);  // Vector to the previous node
      // index des nächsten node berrechnen
      if (i < nodes.size()-1) {
        j = i + 1;
      } else if (closed) {
        j = 0;
      }
      PVector next = PVector.sub(nodes.get(j).location, node.location);  // Vector to the next node
      node.angle = PVector.angleBetween(prev, next);
    }

    //if (frameCount%100 == 0) {
    //println("ephemer: ", id, ": minX: ", minX, " maxX: ", maxX, " minY: ", minY, " maxY: ", maxY);
    //}
  }

  void display() {
    for (int i = 0; i < nodes.size (); i++) {
      Node node = nodes.get(i);
      float d = nodes.size()/5.0 ;
      if ((i == currentNode)&& (currentNodeIsNew)) node.display(d, true);
      else  node.display(d, false);
      // draw velo
      //trailCanvas.stroke(150, 10);
      /*     trailCanvas.line(nodes.get(i).location.x, nodes.get(i).location.y, 
       nodes.get(i).location.x+nodes.get(i).velocity.x*30, 
       nodes.get(i).location.y+nodes.get(i).velocity.y*30);
       */
      // draw bezier curve
      if ((i<nodes.size()-1) || (closed )) {
        PVector b1 = new PVector(0, 0); 
        if (i>0) b1 = PVector.sub(node.location, nodes.get(i-1).location);
        else if (closed) b1 = PVector.sub(node.location, nodes.get(nodes.size()-1).location);
        //        b1 = b1.mult(0.3);
        b1.mult(0.3);
        b1.add(node.location);
        PVector b2 = new PVector(0, 0);
        if (i<nodes.size()-2) b2 = PVector.sub(nodes.get(i+1).location, nodes.get(i+2).location);
        else if (closed)       b2 = PVector.sub(nodes.get((i+1)%nodes.size()).location, nodes.get((i+2)%nodes.size()).location);
        b2.mult(0.3);
        b2.add(nodes.get((i+1)%nodes.size()).location);

        if (currentNode == i) trailCanvas.strokeWeight(3);
        else trailCanvas.strokeWeight(1);
        //        trailCanvas.stroke(node.level, (1-node.level/255)*50+20);
        //trailCanvas.stroke(node.level, constrain(mouseX, 0, 255));
        trailCanvas.stroke(node.level, min(200, 10 + 0.3 * node.level * min(2, node.veloMag)));  // alpha related to level and velocity

        //     trailCanvas.stroke(node.level, min((node.level/255)*55*node.veloMag + 10, 127));  // alpha related to level and velocity
        trailCanvas.noFill();
        trailCanvas.bezier(node.location.x, node.location.y, 
          b1.x, b1.y, 
          b2.x, b2.y, 
          nodes.get((i+1)%nodes.size()).location.x, nodes.get((i+1)%nodes.size()).location.y);

        if (currentNode == i) noTrailCanvas.strokeWeight(3);
        else noTrailCanvas.strokeWeight(1);
        noTrailCanvas.stroke(node.level, 255);
        noTrailCanvas.noFill(); 
        noTrailCanvas.bezier(node.location.x, node.location.y, 
          b1.x, b1.y, 
          b2.x, b2.y, 
          nodes.get((i+1)%nodes.size()).location.x, nodes.get((i+1)%nodes.size()).location.y);
      }
      // draw curve
    }
    // draw ephemer frame
    //noTrailCanvas.noFill();
    //noTrailCanvas.stroke(150);
    //noTrailCanvas.rect(minX, minY, maxX-minX, maxY-minY);
  }

  void advanceToNextNode() {    
    // node duration based processing
    directionChanged = false;
    if (millisOfNextNode - millis() <= 0 ) {
      currentNodeIsNew = true;
      while (millisOfNextNode - millis() <= 0 ) {
        // //   if (millisOfNextNode - millis() <= 0) {
        previousNode = currentNode;
        currentNode = nextNode;

        float prob = abs(nodes.get(currentNode).angle - (float)PI) * 75 / PI ;  // calc probability 0-75 for direction change for current node
        boolean stop = false;
        boolean wrapped = false;
        prob *= probFactor;
        if (random(100) < prob) {
          if (random(100) < 50) {
            forward = !forward;
            directionChanged = true;
          } else stop = true;
        }
        if (!stop) {  // calc next node
          if (forward) nextNode++;
          else nextNode --;

          if (nextNode >= nodes.size()) {    // forward and end of loop reached
            if (closed) {
              nextNode = 0;
              wrapped = true;
            } else {
              /*nextNode = nodes.size()-2;
               if (nextNode<0) nextNode = 0;
               forward = false;*/
              nextNode = 0;
            }
          }
          if (nextNode < 0) {  // backward
            if (closed) {
              nextNode = nodes.size()-1;
              wrapped = true;
            } else {
              //nextNode = 1;
              nextNode = nodes.size()-1;
            }
            if (nextNode>=nodes.size())nextNode = 0;
            forward = true;
          }
        } 
        currentInterval = nodes.get(currentNode).duration;
        float nL = nodes.get(currentNode).level;       
        float veloFactor = 1.0/(nodes.get(currentNode).veloMag  + 0.5); // test with velocity  
        currentInterval =  int (currentInterval * veloFactor);
        // test slow down with lifetime
        //timeFactor = 1 + (millis() - millis)/60000.0;
        if (nL > minLevel) {
          timeFactor = 255.0 / min(255, 127 + (nL-minLevel));
          timeFactor = 1 / (1 + attractionSum) * timeFactor;
          currentInterval *= timeFactor;
        } else {  // quasi auslassen
          currentInterval = 1;
        }
        currentInterval = max(millis()-millisOfNextNode, currentInterval);
        //print("current interval: ", currentInterval, " currentNode: ", currentNode, "  diff: ", millisOfNextNode-millis());
        //currentInterval = int(100 * (1 + (millis() - millis)/10000.)); // test
        millisOfNextNode = max(millis()+1, millis() + currentInterval + (millisOfNextNode - millis()));
        //println("  next: ", millisOfNextNode-millis());
      }
    } else {
      // currentNode has not changed for this frame
      currentNodeIsNew = false;
    }
  }




  PVector attract(Ephemer e) {
    //PVector force = PVector.sub(e.nodes.get(e.currentNode).location, nodes.get(currentNode).location);            // Calculate direction of force
    PVector force = PVector.sub(e.location, location);            // Calculate direction of force, center to center g force
    float distance = force.mag();                                 // Distance between objects
    distance = constrain(distance, 50.0, 2000.0);                 // Limiting the distance to eliminate "extreme" results for very close or very far objects
    force.normalize();                                            // Normalize vector (distance doesn't matter here, we just want this vector for direction

    float strength = (gravity * mass * e.mass) / (distance * distance); // Calculate gravitional force magnitude
    force.mult(strength);      // Get force vector --> magnitude * direction
    ephemerAttractions[e.id] = force.mag();      // store attraction force mag to other ephemer
    return force;
  }

  void applyForce(PVector force) {
    PVector f = PVector.div(force, mass);
    acceleration.add(f);
  }

  void addNode(float x, float y, int _millis) {
    if (nodes.size() <= maxNodes) {
      PVector newNodeLocation = new PVector(x, y);
      // add a new node if separation and interval are big enough
      if ((newNodeLocation.dist(lastAddedNodeLocation) > minNodeDistance) && (_millis >= millisOfLastAddedNode + minNodeInterval)) {
        Node nNode = new Node(x, y, _millis-millis);
        nNode.level = startLevel;
        if (nodes.size()>0) {  // not the first node, calc velocity
          nNode.velocity.x = x;
          nNode.velocity.y = y;
          nNode.velocity.sub(nodes.get((nodes.size()-2)%nodes.size()).location);
          nNode.velocity.mult(.01); // factor velocity
        }
        nodes.add(nNode);
        lastAddedNodeLocation = newNodeLocation;
        millisOfLastAddedNode = _millis;
        //println("added node ", nodes.size()-1, " x:", nNode.location.x, " y:", nNode.location.y, " millis: ", nNode.millis);
        mass += startLevel;  // new node with level = mass 
        fadeRate *= 0.9996;
        //println(fadeRate);
      }
    }
  }


  boolean hit(float x, float y) {
    if (x >= minX && x <= maxX && y >= minY && y <= maxY) 
      return true; 
    else return false;
  }

  void sendOSC() {
    OscMessage myMessage = new OscMessage("/ephemer");
    if ((nodes.size() > 0)&&(currentNodeIsNew)) {
      //float eVelocityAngle = (velocity.heading() / PI + 0.5)%1;  // 0 = up, 1 = down
      //if (eVelocityAngle > 1.0) eVelocityAngle -= 1; 
      float eVelocityAngle = (velocity.heading()/PI );     // -1 = down, 1 = up, 0 = horizontal
      if (eVelocityAngle < 0) {
        if (eVelocityAngle < -0.5) eVelocityAngle = -1 - eVelocityAngle;
      } else {
        if (eVelocityAngle > 0.5) eVelocityAngle = 1 - eVelocityAngle;
      }
      eVelocityAngle *= -2;

      // ephemer osc message
      myMessage.add(this.id);                                 /* add ephemer nbr */
      myMessage.add(millis() - millis );                      /* add ephemer lifetime */

      myMessage.add(constrain(location.x/canvasW, 0, 1));     /* center of ephemer x 0-1 to the osc message */
      myMessage.add(constrain(1.- (location.y - upperScreenLimit)/(canvasH - upperScreenLimit - (canvasH - lowerScreenLimit)), 0, 1));  /* add y 0-1 to the osc message */
      myMessage.add(nodes.size());                            // number of nodes
      myMessage.add(velocity.mag());                          // velocity
      myMessage.add((maxX - minX)/canvasW);                   // xDim 0-1
      myMessage.add((maxY - minY)/(canvasH - upperScreenLimit - (canvasH - lowerScreenLimit)));                   // yDim 0-1
      myMessage.add(mass/255.0);                              // mass 0-nbr of nodes
      myMessage.add(eVelocityAngle);                          // velo angle -1...0....1
      myMessage.add(constrain(origLocation.x/canvasW, 0, 1));                          // original center x
      myMessage.add(constrain(1.- (origLocation.y - upperScreenLimit)/(canvasH - upperScreenLimit - (canvasH - lowerScreenLimit)), 0, 1));  // original center y
      for (int i = 0; i < ephemerAttractions.length; i++) {
        myMessage.add(ephemerAttractions[i]);
      }

      //myMessage.print();

      oscP5.send(myMessage, myRemoteLocation);      /* send the message */


      // node osc message send only current node data
      //for (int i=0; i<nodes.size (); i++) {
      //Node node = nodes.get(i);
      Node node = nodes.get(currentNode);
      PVector nLocation = node.location;

      float nAngle = 0;
      if (directionChanged) nAngle = 1;
      else if (node.angle != 0) nAngle = abs((float)PI - node.angle)/PI; // angle 0 - 1

      float nVelocity  = min(node.veloMag, 10);                   // velo max 10 pixels/frame
      //float nVelocityAngle = (node.velocity.heading() / PI + 0.5)%1;  // 0 = up, 1 = down
      //if (nVelocityAngle > 1.0) nVelocityAngle -= 1; 
      float nVelocityAngle = (node.velocity.heading()/PI );    // -1 = down, 1 = up, 0 = horizontal
      if (nVelocityAngle < 0) {
        if (nVelocityAngle < -0.5) nVelocityAngle = -1 - nVelocityAngle;
      } else {
        if (nVelocityAngle > 0.5) nVelocityAngle = 1 - nVelocityAngle;
      }
      nVelocityAngle *= -2;
      //println(nVelocityAngle);
      // node acceleration
      float nAcceleration  = min(node.currentAcceleration.mag(), 10);    // acc max 10 pixels/frame
      float nAccelerationAngle  = node.currentAcceleration.heading() / PI + 0.5;
      if (nAccelerationAngle > 1)  nAccelerationAngle -= 1;

      // osc message  
      myMessage.clear();
      myMessage.setAddrPattern("/node");
      myMessage.add(this.id);                                            /* add ephemer nbr */
      myMessage.add(currentNode);                                                  // node nbr
      myMessage.add(constrain(nLocation.x/canvasW, 0, 1));               /* add x 0-1 to the osc message */
      myMessage.add(constrain(1.- (nLocation.y - upperScreenLimit)/(canvasH - upperScreenLimit - (canvasH - lowerScreenLimit)), 0, 1));  /* add y 0-1 to the osc message */
      myMessage.add(node.level/255.);                                    // amp 0-1
      myMessage.add(nVelocity);                                          // velocity magnitude
      myMessage.add(1);                                                  // gate on
      //else myMessage.add(0);
      myMessage.add(nAcceleration);                                      // acceleration magnitude
      myMessage.add(nAngle);                                             // angle 0-1 meassured from  center 
      myMessage.add(forward);
      myMessage.add(directionChanged);
      myMessage.add(currentInterval);
      myMessage.add(nVelocityAngle);
      myMessage.add(nAccelerationAngle);
      oscP5.send(myMessage, myRemoteLocation);      /* send the message */
      //}


      // send trail 
      myMessage.clear();
      myMessage.setAddrPattern("/alpha");
      // iterate over pixels
      float amp = 0;
      for (int i = (canvasH-1)*canvasW + canvasW-1; i >= 0; i--) {  
        if ((i%canvasW >= minXr) && (i%canvasW <= maxXr) && (i/canvasW >= minYr) && (i/canvasW <= maxYr)) {
          amp = amp + (trailCanvas.pixels[i] & 0xFF); // get alpha value
        }
        if (i % canvasW == 0) {
          amp = amp / (255 * (maxXr - minXr));
          amp = amp * i/(canvasW * canvasH);
          myMessage.add(amp);
          amp = 0;
        }
      }
      oscP5.send(myMessage, myRemoteLocation);
      if (frameCount%canvasW == 100) {
        //myMessage.print();
      }
    }
  }


  void repellFromLocation(PVector p) {
    for (int i = 0; i < nodes.size (); i++) {
      Node node = nodes.get(i);
      PVector force = node.repellFromLocation(p);
      node.applyForce(force);
    }
  }

  void attractToLocation(PVector p) {
    for (int i = 0; i < nodes.size (); i++) {
      Node node = nodes.get(i);
      PVector force = node.attractToLocation(p);
      node.applyForce(force);
    }
  }

  PVector currentNodeForce() {
    PVector force = PVector.sub(nodes.get(currentNode).location, nodes.get(previousNode).location);
    force.normalize();
    force.mult(0.001/(max(1, nodes.get(currentNode).millis - nodes.get(previousNode).millis)));
    return force;
  }


  void ephemerNew() {
    //    alive = false;
    println("ephemer ", this.id, " new");
    OscMessage myMessage = new OscMessage("/new");
    myMessage.add(this.id);      /* add ephemer nbr */
    //    if (getNbrOfAliveEphemers() == 1) myMessage.add(1);  // indicate first
    //    else myMessage.add(0);
    oscP5.send(myMessage, myRemoteLocation);      /* send the message */
  }

  void ephemerDead() {
    alive = false;
    millisDead = millis();
    println("ephemer ", this.id, " dead");
    OscMessage myMessage = new OscMessage("/dead");
    myMessage.add(this.id);      /* add ephemer nbr */
    oscP5.send(myMessage, myRemoteLocation);      /* send the message */
    lastUserInputTime = millis();
  }

  void ephemerResurrect() {
    alive = true;
    decaying = false;
    millisDead = 0;
    mass = 0;
    for (Node n : nodes) {
      n.level = minLevel/4.0;
      mass += minLevel/4.0;
    }
    println("ephemer ", this.id, " resurrect");
    //OscMessage myMessage = new OscMessage("/new");
    //myMessage.add(this.id);      /* add ephemer nbr */
    //oscP5.send(myMessage, myRemoteLocation);      /* send the message */
  }



  void checkAndCloseEphemer() {
    if (nodes.size()>2) {
      Node node1 = nodes.get(0);                  // get first node
      Node node2 = nodes.get(nodes.size()-1);    // get last node
      float dist = PVector.dist(node1.location, node2.location);
      if (dist <= closeDistance) {
        closed = true;
      }
      if (node2.veloMag > maxVelocity * 30.0/frameRate) closed = false;
    }
  }
}
