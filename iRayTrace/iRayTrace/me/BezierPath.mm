//
//  BezierPath.cpp
//  iRayTrace
//
//  Created by Aaron on 8/18/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include "BezierPath.h"

BezierPath::BezierPath(){
    reset();
}
void BezierPath::createPath(V3* center, int nodes, float spacing, float speed){
    
    
    //invaid paths
    if (nodes < 4 || nodes > MaxPathLength || speed <= 0.0f || spacing <= speed){
        NSLog(@"Camera: bad path args \n");
        return;
    }

    //reset everything
    reset();
    
    //set vars
    nodeSpacing = spacing;
    pathSpeed = speed;
    node = 0;
    t = 0.0f;
    hasPath = true;
    
    //make path
    int k;
    V3 prev = *center;
    V3 randDir = V3();
    for (k = 0; k < nodes; k++){
        
        //find position of new node
        randDir = randUnit3();
        randDir.z *= PathScaleZ;
        randDir = unit3(&randDir);
        randDir = mult3(&randDir, spacing);
        prev = add3(&prev, &randDir);
        
        //add to path
        path[pathLength] = prev;
        pathLength++;
        
    }
    
    //verlet the points a bit
    float dist = 0.0f;
    float offsetMag = 0.0f;
    int j = 0;
    int z = 0;
    V3 n0 = V3();
    V3 n1 = V3();
    V3 delta = V3();
    for (z = 0; z < PathSmoothIterations; z++){
        for (k = 0; k < pathLength; k++){
            n0 = path[k];
            for (j = k + 1; j < pathLength; j++){
                n1 = path[j];
                dist = dist3(&n0, &n1);
                offsetMag = nodeSpacing - dist;
                if (offsetMag > 0.0f){
                    //do verlet
                    delta = sub3(&n0, &n1);
                    delta = unit3(&delta);
                    delta = mult3(&delta, (nodeSpacing - dist) * 0.5f);
                    path[k] = add3(&path[k], &delta);
                    path[j] = sub3(&path[j], &delta);
                    
                }
            }
        }
    }

}
V3 BezierPath::getPathPos(){
    
    
    //estimate
    float idealDt = (pathSpeed / nodeSpacing);
    float idealStepDistance = (pathSpeed / LengthEstimationSteps);

    //test estimated dt
    V3 oldPos = getBezierPos(0.0f, false);
    V3 testPos = getBezierPos(idealDt, false);
    float testDist = dist3(&testPos, &oldPos);
    
    //refine dt estimate
    idealDt /= testDist / idealStepDistance;

    //iteratively find the distance
    float dtAccum = 0.0f;
    float distAccum = 0.0f;
    
    //default return val
    testPos = oldPos;

    int i = 0;
    int steps = LengthEstimationSteps * 2;
    for (i = 0; i < steps; i++){
            
        
        //get points
        if (i != 0) {
            oldPos = testPos;
            testPos = getBezierPos(dtAccum, false);
            testDist = dist3(&testPos, &oldPos);
        } else {
            testDist = 0.0f;
            
        }
        
        //increment and test
        dtAccum += idealDt;
        distAccum += testDist;

        //weve reached our goal
        if (distAccum > pathSpeed){
            getBezierPos(dtAccum, true);
            return testPos;
        }

    }
    return testPos;
    
}
V3 BezierPath::getBezierPos(float dt, bool copy){

    
    V3 bezierPos=V3();
    
    //one for each node
    unsigned int nodeIndex[4];
    V3 nodePos[4];
    
    //ratios
    float f0, f1, f2, f3;
    Vec4 px, py, pz;
    
    //local
    float currT = t;
    float currNode = node;
    
    //loop stuff
    int i;
    
    //if we have a path
    if (hasPath && pathSpeed > 0.0f && dt < 1.0f){
        
        //increment t and node
        currT += dt;
        if (currT >= 1.0f){
            currT -= 1.0f;
            currNode = getNextNode(currNode);
        }
    
        //get nodes we are working with
        for (i = 0; i < 4; i++){
            //indices
            if (i == 0){
                nodeIndex[i] = currNode;
            }else{
                nodeIndex[i] = nodeIndex[i - 1] + 1;
            }
            if (nodeIndex[i] >= pathLength)
                nodeIndex[i] = 0;
            
            //pos
            nodePos[i] = path[nodeIndex[i]];
        }
          
        //UNIFORM CUBIC B SPLINE////////////////////
        float t1 = currT;
        float t2 = t1 * t1;
        float t3 = t2 * t1;
        
        f0 = -t3 + 3.0f * t2 -3.0f * t1 + 1.0f;
        f1 = 3.0f * t3 -6.0f * t2 + 4.0f;
        f2 = -3.0f * t3 + 3.0f * t2 + 3.0f * t1 + 1.0f;
        f3 = t3;
        
        //times 1/6
        float sixth = 1.0f / 6.0f;
        f0 *= sixth;
        f1 *= sixth;
        f2 *= sixth;
        f3 *= sixth;
        
        px = Vec4(nodePos[0].x, nodePos[1].x, nodePos[2].x, nodePos[3].x);
        py = Vec4(nodePos[0].y, nodePos[1].y, nodePos[2].y, nodePos[3].y);
        pz = Vec4(nodePos[0].z, nodePos[1].z, nodePos[2].z, nodePos[3].z);
        
        //get position
        bezierPos.x = f0 * px[0] + f1 * px[1] + f2 * px[2] + f3 * px[3];
        bezierPos.y = f0 * py[0] + f1 * py[1] + f2 * py[2] + f3 * py[3];
        bezierPos.z = f0 * pz[0] + f1 * pz[1] + f2 * pz[2] + f3 * pz[3];
        //UNIFORM CUBIC B SPLINE////////////////////

        if (copy){
            t = currT;
            node = currNode;
        }
            
    }
    
    return(bezierPos);
}

void BezierPath::reset(){
    
    //bezier
    pathSpeed = 0.0f;
    t = 0.0f;
    node = 0;
    
    //path
    hasPath = false;
    pathLength = 0;
    
    int i;
    for (i = 0; i < MaxPathLength; i++)
        path[i] = V3();
    
	
}

unsigned int BezierPath::getNextNode(unsigned int node){
    node++;
    if (node >= pathLength)
        node = 0;
    
    return node;
}
