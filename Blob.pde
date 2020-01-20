
// Daniel Shiffman
// http://codingrainbow.com
// http://patreon.com/codingrainbow
// Code for: https://youtu.be/o1Ob28sF0N8

class Blob {
  float minx;
  float miny;
  float maxx;
  float maxy;

  int id = 0;
  int count = 0;
  color colr;

  int lifespan = maxLife;

  boolean taken = false;

  Blob(float x, float y, color c) {
    minx = x;
    miny = y;
    maxx = x;
    maxy = y;
    colr = c;
    count = 1;
  }

  boolean checkLife() {
    lifespan--; 
    if (lifespan < 0) {
      return true;
    } else {
      return false;
    }
  }


  void show() {
    stroke(200);
    //fill(255, lifespan);
    noFill();
    strokeWeight(1);
    rectMode(CORNERS);
    rect(minx, miny, maxx, maxy);

    textAlign(CENTER);
    textSize(16);
    //fill(250);
    text(id, minx + (maxx-minx)*0.5, miny - 10);
    textSize(10);
    text(red(colr) + ", " + green(colr) + ", " + blue(colr), minx + (maxx-minx)*0.5, maxy + 10);
    text("size: " + size(), minx + (maxx-minx)*0.5, maxy + 22);
    text("count: "+count, minx + (maxx-minx)*0.5, maxy + 34);
    //text(lifespan, minx + (maxx-minx)*0.5, miny - 10);
  }


  void add(float x, float y, color c) {  // add pixel to blob
    minx = min(minx, x);
    miny = min(miny, y);
    maxx = max(maxx, x);
    maxy = max(maxy, y);
    colr = color( 
      (red(colr)*count + red(c))/(count+1),  
      (blue(colr)*count + blue(c))/(count+1),  
      (green(colr)*count + green(c))/(count+1)  
      );
    count++;
  }

  void become(Blob other) {
    minx = other.minx;
    maxx = other.maxx;
    miny = other.miny;
    maxy = other.maxy;
    colr = other.colr;
    count = other.count;
    lifespan = maxLife;
  }

  float size() {
    return (maxx-minx)*(maxy-miny);
  }

  PVector getCenter() {
    float x = (maxx - minx)* 0.5 + minx;
    float y = (maxy - miny)* 0.5 + miny;    
    return new PVector(x, y);
  }

  boolean isNear(float x, float y) {

    float cx = max(min(x, maxx), minx);
    float cy = max(min(y, maxy), miny);
    float d = distSq(cx, cy, x, y);

    if (d < distThreshold*distThreshold) {
      return true;
    } else {
      return false;
    }
  }
}

float distSq(float x1, float y1, float x2, float y2) {
  float d = (x2-x1)*(x2-x1) + (y2-y1)*(y2-y1);
  return d;
}


float distSq(float x1, float y1, float z1, float x2, float y2, float z2) {
  float d = (x2-x1)*(x2-x1) + (y2-y1)*(y2-y1) +(z2-z1)*(z2-z1);
  return d;
}
