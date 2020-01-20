import java.util.Map;

class ClusterGroup
{
  ArrayList< Centroid > centroids = new ArrayList< Centroid >();
  ArrayList< Centroid > tmpCentroids = new ArrayList< Centroid >();
  ArrayList< ClusteredPoint > points = new ArrayList< ClusteredPoint >();
  boolean allClustersStable = false;
  boolean allPointsClustered = false;
  float minXCoord;
  float maxXCoord;
  static final int sMaxCentroidCount = 10;
  boolean clusteringFinished = true;
  
  ClusterGroup(float pMinXPos, float pMaxXPos)
  {
    minXCoord = pMinXPos;
    maxXCoord = pMaxXPos;
  }
  
  public void resetTouchPoints()
  {
    points.clear();
  }
  
  public void addTouchPoint( TouchPoint tPoint )
  {
    if( clusteringFinished == false ) return;
    
    ClusteredPoint cPoint = new ClusteredPoint(tPoint);
    cPoint.dispColor = color(255, 0, 0);
    points.add( cPoint );
  }
  
  public void calculateClusters()
  {  
    if( clusteringFinished == false ) return;
    
    clusteringFinished = false;
    allClustersStable = false;
    allPointsClustered = false;
    
    // increment death time of all existing centroids
    for(int cI=0; cI<centroids.size(); ++cI)
    {
      centroids.get(cI).deathTime += 1;
    }

    tmpCentroids.clear();

    if( points.size() > 0 )
    {
        //add first centroid
        {
          Centroid centroid = new Centroid( random(minXCoord, maxXCoord), random(0.0, 1.0) );
          centroid.dispColor = color( 255, 0, 0 );
          tmpCentroids.add( centroid );
        }
      
        while( allClustersStable == false || allPointsClustered == false )
        {
          if( allClustersStable == false || allPointsClustered == false )
          {  
            if(allClustersStable == true) // add new centroid
            {
                Centroid centroid = new Centroid( random(minXCoord, maxXCoord), random(0.0, 1.0) );
                //centroid.dispColor = color( random(0,255),random(0,255),random(0,255) );
                centroid.dispColor = color( 255, 0, 0 );
                tmpCentroids.add( centroid );
            }
            
            updateCentroids();
            
            if( allClustersStable == true && allPointsClustered == true )
            {
              // assign lowest point id to cluster
              for(int cI=0; cI<tmpCentroids.size(); ++cI)
              {
                Centroid centroid = tmpCentroids.get(cI);
                int pointCount = centroid.points.size();
                
                if( pointCount > 0 )
                {
                  int lowestId = 10000;
                  int currentId;
                  
                  for(int pI=0; pI<centroid.points.size(); ++pI)
                  {
                    ClusteredPoint cPoint = centroid.points.get(pI);
                    TouchPoint tPoint = cPoint.touchPoint;
                    currentId = tPoint.ID;
                    
                    if( currentId < lowestId ) lowestId = currentId;
                  }
                  
                  centroid.ID = lowestId;
                }
                else
                {
                  centroid.ID = -1;
                }
              }
            }
          }  
      } 
    }
    
    //println("tmpCentroids " + tmpCentroids.size());
    
    // update centroids based on new centroids 
    HashMap<Integer, Centroid> tmpCentroidIDMap = new HashMap<Integer, Centroid>();
    HashMap<Integer, Centroid> centroidIDMap = new HashMap<Integer, Centroid>();
    
    for(int cI=0; cI<tmpCentroids.size(); ++cI)
    {
      Centroid centroid = tmpCentroids.get(cI);
      tmpCentroidIDMap.put( centroid.ID, centroid );
    }
    
    for(int cI=0; cI<centroids.size(); ++cI)
    {
      Centroid centroid = centroids.get(cI);
      centroidIDMap.put( centroid.ID, centroid );
    }
    
    for(Map.Entry entry : tmpCentroidIDMap.entrySet()) // update current centroids
    {
      int tmpCentroidId = (Integer)(entry.getKey());
      
      if( centroidIDMap.containsKey( tmpCentroidId ) )
      {
        Centroid tmpCentroid = (Centroid)(entry.getValue());
        Centroid centroid = centroidIDMap.get(tmpCentroidId);
        
        float positionSmoothing;
        if( centroid.lifeTime <= centroid.sMinLifeTime ) positionSmoothing = 0.0;
        else positionSmoothing = centroid.sPositionSmoothing;
        
        centroid.prevXCoord = centroid.xCoord;
        centroid.prevYCoord = centroid.yCoord;
        centroid.xCoord = centroid.prevXCoord * positionSmoothing + tmpCentroid.xCoord * (1.0 - positionSmoothing);
        centroid.yCoord = centroid.prevYCoord * positionSmoothing + tmpCentroid.yCoord * (1.0 - positionSmoothing);
        centroid.lifeTime += 1;
        centroid.deathTime = 0;
      }
      else
      {
        Centroid tmpCentroid = (Centroid)(entry.getValue());
        Centroid centroid = new Centroid(tmpCentroid.xCoord, tmpCentroid.yCoord);
       
        centroid.ID = tmpCentroid.ID;
        centroid.prevXCoord = centroid.xCoord;
        centroid.prevYCoord = centroid.yCoord;
        centroid.lifeTime = 0;
        centroid.deathTime = 0;    
    
        centroids.add(centroid);    
      }
    }

    ArrayList< Integer> removeCentroidIndices = new ArrayList< Integer >(); 
    
    for(int cI=0; cI<centroids.size(); ++cI) // update no longer existing centroids
    {
      Centroid centroid = centroids.get(cI);
      int centroidID = centroid.ID;
      
      if( tmpCentroidIDMap.containsKey( centroidID ) == false )
      {
        centroid.deathTime += 1;
        
        if( centroid.deathTime > centroid.sMaxDeathTime ) removeCentroidIndices.add( cI );
      }
    }
    
    for(int cI=removeCentroidIndices.size() -1; cI>=0; --cI)
    {
      int removeCentroidIndex = removeCentroidIndices.get(cI);
      // touches ended
      touchesEnded(centroids.get(removeCentroidIndex).ID);
      println("id removed: ",centroids.get(removeCentroidIndex).ID);

      centroids.remove( removeCentroidIndex );
    }

    clusteringFinished = true;
  }
  
  private void updateCentroids()
  {
      //println("updateCentroids");
    
      allPointsClustered = true;
      allClustersStable = true;
      
      // reset points stored in centroids
      for(int cI=0; cI<tmpCentroids.size(); ++cI)
      {
        Centroid centroid = tmpCentroids.get(cI);
        centroid.points.clear();
      }
    
    // assign points to centroids
    float distance;
    float minDistance;
    Centroid minCentroid;
    
    for(int pI=0; pI<points.size(); ++pI)
    {
      ClusteredPoint point = points.get(pI);
      TouchPoint tPoint = point.touchPoint;
  
      minDistance = 10000.0;
      minCentroid = null;
      
      for(int cI=0; cI<tmpCentroids.size(); ++cI)
      {
        Centroid centroid = tmpCentroids.get(cI);
        
        distance = (centroid.xCoord - tPoint.xCoord) * (centroid.xCoord - tPoint.xCoord) + (centroid.yCoord - tPoint.yCoord) * (centroid.yCoord - tPoint.yCoord);
        
        if( distance < minDistance )
        {
          minDistance = distance;
          minCentroid = centroid;
        }
      }
      
       minCentroid.points.add(point);
      
      if( minDistance < Centroid.sMaxPointDistance )
      {
        point.centroid = minCentroid;
      }
      else if( tmpCentroids.size() < sMaxCentroidCount )
      {       
        allPointsClustered = false;
        point.centroid = null;
      }
    }
    
    // update position of centroid
    float centroidPositionChange[] = new float[2];
    
    for(int cI=0; cI<tmpCentroids.size(); ++cI)
    {
      Centroid centroid = tmpCentroids.get(cI);
      
      if( centroid.points.size() > 0 )
      {
        float oldCentroidPosition[] = { centroid.xCoord, centroid.yCoord };
      
        centroid.xCoord = 0.0;
        centroid.yCoord = 0.0;
      
        for(int pI=0; pI<centroid.points.size(); ++pI)
        {
          ClusteredPoint point = centroid.points.get(pI);
          TouchPoint tPoint = point.touchPoint;
        
          centroid.xCoord += tPoint.xCoord;
          centroid.yCoord += tPoint.yCoord;
        }
      
        centroid.xCoord /= (float)centroid.points.size();
        centroid.yCoord /= (float)centroid.points.size();
        
        // calculate centroid movement distance 
        centroidPositionChange[0] = oldCentroidPosition[0] - centroid.xCoord;
        centroidPositionChange[1] = oldCentroidPosition[1] - centroid.yCoord;
       
        if( ( centroidPositionChange[0] ) * ( centroidPositionChange[0] ) + ( centroidPositionChange[1] ) * ( centroidPositionChange[1] ) < Centroid.sStablePositionCriteria )
        {
          centroid.stablePosition = true;
        }
        else
        {
          centroid.stablePosition = false;
          allClustersStable = false;
        }
      }
      else
      {
          centroid.xCoord = random(minXCoord, maxXCoord);
          centroid.yCoord = random(0.0, 1.0);
        
          centroid.stablePosition = false;
          allClustersStable = false;
      }
    }
  }
  
  public void display(PGraphics canvas)
  {
    if( clusteringFinished == false ) return;
    
    try
    {
      canvas.stroke(100);
      float canvasScaleX = canvas.width / 4;
      float canvasScaleY = canvas.height;
      
      // draw points
      float pointSize = 10.0;
      
      for(int pI=0; pI<points.size(); ++pI)
      {
        ClusteredPoint cPoint = points.get(pI);
        TouchPoint tPoint = cPoint.touchPoint;
        
        if( cPoint.centroid != null ) fill( cPoint.centroid.dispColor );
        else canvas.fill(0,0,0, 55.0);
        
        canvas.ellipse(tPoint.xCoord * canvasScaleX, tPoint.yCoord * canvasScaleY, pointSize, pointSize);
      }
  
      // draw centroids
      float centroidSize = 60.0;
      canvas.textSize(48);
      
      for(int cI=0; cI<centroids.size(); ++cI)
      {
        Centroid centroid = centroids.get(cI);
        
        if( centroid.lifeTime < centroid.sMinLifeTime || centroid.deathTime > 0 ) continue;
        
        //canvas.fill( centroid.dispColor );
        canvas.fill( 255, 0, 0, 55.0 );
        canvas.ellipse(centroid.xCoord * canvasScaleX, centroid.yCoord * canvasScaleY, centroidSize, centroidSize);
        canvas.fill(0,0,0);
        canvas.text(str(centroid.ID), centroid.xCoord * canvasScaleX + 20, centroid.yCoord * canvasScaleY); 
      }
    }
    catch(Exception e)
    {}
  }
};

class Centroid
{
  static final float sStablePositionCriteria = 0.01;
  static final float sMaxPointDistance = 0.02;
  static final int sMinLifeTime = 0;
  static final int sMaxDeathTime = 0;
  static final float sPositionSmoothing = 0.9;
  
  public int ID = 0;
  public float xCoord = 0.0;
  public float yCoord = 0.0;
  public float prevXCoord = 0.0;
  public float prevYCoord = 0.0;
  public int lifeTime = 0;
  public int deathTime = 0;
 
  ArrayList< ClusteredPoint > points = new ArrayList< ClusteredPoint >();
  boolean stablePosition = false;
 
  color dispColor = color(0,0,0);
  
  Centroid( float pXCoord, float pYCoord )
  {
    xCoord = pXCoord;
    yCoord = pYCoord;
  }
};

class ClusteredPoint
{
  TouchPoint touchPoint;
  Centroid centroid;
  color dispColor;
  
  ClusteredPoint( TouchPoint pTouchPoint )
  {
    touchPoint = pTouchPoint;
  }
};
