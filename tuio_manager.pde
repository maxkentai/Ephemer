import java.util.Map;

class TouchPoint
{
  public int ID = 0;
  public int lifeStatus = 0;
  public int bornTimeStamp;
  public int timeStamp = 0;
  public float xCoord = 0.0;
  public float yCoord = 0.0;
  
  public int deathTimeCounter = 0;
}

class TouchManager
{
  final int sMaxTouchPoints = 800;
  final int sDeathConfirmationDuration = 40;
  final float sPointPositionSmoothing = 0.5;
  public TouchPoint[] allPoints = new TouchPoint[sMaxTouchPoints];
  public TouchPoint[] alivePoints = new TouchPoint[0];
  public TouchPoint[] bornPoints = new TouchPoint[0];
  public TouchPoint[] diedPoints = new TouchPoint[0];
  private int currentTimeStamp;
  
  final int sClusterGroupCount = 4;
  public ClusterGroup[] clusterGroups = new ClusterGroup[sClusterGroupCount];
  
  HashMap<Integer,TouchPoint> tmpPoints;
  
  boolean mLocked = false;
  
  TouchManager()
  {
     allPoints = new TouchPoint[sMaxTouchPoints];
     tmpPoints = new HashMap<Integer,TouchPoint>();
    
    for(int i=0; i<sMaxTouchPoints; ++i)
    {
      allPoints[i] = new TouchPoint();
      allPoints[i].ID = i;
    }
    
    float minXPos;
    float maxXPos;
    
    for(int i=0; i<sClusterGroupCount; ++i)
    {
      minXPos = float(i) * 1.0;
      maxXPos = minXPos + 1.0;
      clusterGroups[i] = new ClusterGroup( minXPos, maxXPos );
    }
  }
  
  public void update( int pTouchId, float pTouchX, float pTouchY )
  {
         if( mLocked == true ) return;
         mLocked = true;
    
        TouchPoint touchPoint = new TouchPoint();
        touchPoint.ID = pTouchId;
        touchPoint.timeStamp = currentTimeStamp;
        touchPoint.xCoord = pTouchX;
        touchPoint.yCoord = pTouchY;
                
        tmpPoints.put(touchPoint.ID, touchPoint);
        
        mLocked = false;
  }
  
  public void update( int pTimeStamp )
  {
      if( mLocked == true ) return;
      mLocked = true;
    
      updatePoints();  
      
      calculateClusters();

      currentTimeStamp = pTimeStamp;

      mLocked = false;
  }

  public void update( String tuioMessage )
  {
    //println("update message " + tuioMessage);
    
    String[] tokens = tuioMessage.split(" ");
    
    int tokenCount = tokens.length;
    //println(tokens[3]);
    
    if( tokenCount == 5 && tokens[3].equals("fseq") ) 
    {  
      updatePoints();
      currentTimeStamp = Integer.parseInt( tokens[4].substring(0, tokens[4].length() - 1) );
    }
    else if( tokenCount > 3 && tokens[3].equals("alive") )
    {
       int pointCount = tokenCount - 4;
       tmpPoints = new HashMap<Integer,TouchPoint>(pointCount);
    }
    else if( tokenCount > 3 && tokens[3].equals("set") )
    {
      for(int tI=4; tI<tokenCount; ++tI)
      {
        TouchPoint touchPoint = new TouchPoint();
        touchPoint.ID = Integer.parseInt( tokens[4] );
        touchPoint.timeStamp = currentTimeStamp;
        touchPoint.xCoord = Float.parseFloat( tokens[5] );
        touchPoint.yCoord = Float.parseFloat( tokens[6] );
        
        //println("add point id " + touchPoint.ID + " timeStamp " + touchPoint.timeStamp + " x " + touchPoint.xCoord + " y " + touchPoint.yCoord);
        
        tmpPoints.put(touchPoint.ID, touchPoint);
      }
    }
  }
  
  private void updatePoints()
  {
    // update all points array
    int bornPointCount = 0;
    int alivePointCount = 0;
    int diedPointCount = 0;
    
    for(int tpI=0; tpI<sMaxTouchPoints; ++tpI)
    {       
       if(tmpPoints.containsKey(tpI) == false)
       {
           if( allPoints[tpI].lifeStatus == 1 || allPoints[tpI].lifeStatus == 2 ) 
           {
               if(allPoints[tpI].deathTimeCounter++ > sDeathConfirmationDuration)
               {
                   allPoints[tpI].lifeStatus = 3;  
                   diedPointCount += 1;
               }
               else
               {
                  alivePointCount += 1;
               }
           }
       } 
       else
       {
         TouchPoint touchPoint = tmpPoints.get(tpI);
        
         allPoints[tpI].timeStamp = touchPoint.timeStamp;
         allPoints[tpI].deathTimeCounter = 0;
         
         if( allPoints[tpI].lifeStatus == 0 || allPoints[tpI].lifeStatus == 3 ) 
         {
           allPoints[tpI].xCoord = touchPoint.xCoord;
           allPoints[tpI].yCoord = touchPoint.yCoord;
           
           allPoints[tpI].lifeStatus = 2; 
           allPoints[tpI].bornTimeStamp = touchPoint.timeStamp;
           bornPointCount += 1;
         }
         else
         {
           float positionSmoothing;
           if( allPoints[tpI].lifeStatus == 2 ) positionSmoothing = 0.0;
           else positionSmoothing = sPointPositionSmoothing;
           
           allPoints[tpI].xCoord = allPoints[tpI].xCoord * positionSmoothing + touchPoint.xCoord * (1.0 - positionSmoothing);
           allPoints[tpI].yCoord = allPoints[tpI].yCoord * positionSmoothing + touchPoint.yCoord * (1.0 - positionSmoothing);
           
           allPoints[tpI].lifeStatus = 1; 
           alivePointCount += 1;
         }
       }
    }
    
    tmpPoints.clear();
    
    // update other arrays
    bornPoints = new TouchPoint[bornPointCount];
    alivePoints = new TouchPoint[alivePointCount];
    diedPoints = new TouchPoint[diedPointCount];
    
    int bornPointIndex = 0;
    int alivePointIndex = 0;
    int diedPointIndex = 0;
    
    for(int tpI=0; tpI<sMaxTouchPoints; ++tpI)
    {
      if( (allPoints[tpI].lifeStatus == 1 || allPoints[tpI].lifeStatus == 2 ) && alivePointIndex < alivePointCount)
      {
        alivePoints[alivePointIndex++] = allPoints[tpI];
      }
      
      if( allPoints[tpI].lifeStatus == 2 && bornPointIndex < bornPointCount)
      {
        bornPoints[bornPointIndex++] = allPoints[tpI];
      }
      
      if( allPoints[tpI].lifeStatus == 3 && diedPointIndex < diedPointCount)
      {
        diedPoints[diedPointIndex++] = allPoints[tpI];
      }
    }
  }
  
  private void calculateClusters()
  {
    // reset points for clusters
    for(int i=0; i<sClusterGroupCount; ++i)
    {
      clusterGroups[i].resetTouchPoints();
    }

    // assign points to clustes based on point x_coordinates
    int alivePointCount = alivePoints.length;
    
    for(int pI=0; pI<alivePointCount; ++pI)
    {      
        TouchPoint tPoint = alivePoints[pI];
        
        for(int cI=0; cI<sClusterGroupCount; ++cI)
        {
          if( tPoint.xCoord >= clusterGroups[cI].minXCoord && tPoint.xCoord < clusterGroups[cI].maxXCoord ) clusterGroups[cI].addTouchPoint(tPoint);
        }
    }
    
    for(int i=0; i<sClusterGroupCount; ++i)
    {
      clusterGroups[i].calculateClusters();
    }
  }
  
  public void display(PGraphics canvas)
  {
    for(int i=0; i<sClusterGroupCount; ++i)
    {
      clusterGroups[i].display(canvas);
    }
  }
};
