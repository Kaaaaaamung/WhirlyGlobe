/*
 *  ShapeLayer.mm
 *  WhirlyGlobeLib
 *
 *  Created by Steve Gifford on 9/28/11.
 *  Copyright 2011-2013 mousebird consulting. All rights reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#import "ShapeLayer.h"
#import "NSDictionary+Stuff.h"
#import "UIColor+Stuff.h"
#import "GlobeMath.h"
#import "VectorData.h"
#import "ShapeDrawableBuilder.h"

using namespace WhirlyKit;

namespace WhirlyKit
{

ShapeSceneRep::ShapeSceneRep()
{
}
    
ShapeSceneRep::ShapeSceneRep(SimpleIdentity inId)
: Identifiable(inId)
{    
}
    
ShapeSceneRep::~ShapeSceneRep()
{
}
    
void ShapeSceneRep::clearContents(SelectionManager *selectManager,std::vector<ChangeRequest *> &changeRequests)
{
    for (SimpleIDSet::iterator idIt = drawIDs.begin();
         idIt != drawIDs.end(); ++idIt)
        changeRequests.push_back(new RemDrawableReq(*idIt));
    if (selectManager)
        for (SimpleIDSet::iterator it = selectIDs.begin();it != selectIDs.end(); ++it)
            selectManager->removeSelectable(*it);
}
}

@interface WhirlyKitShape()


@end

@interface WhirlyKitShape()

- (void)makeGeometryWithBuilder:(WhirlyKit::ShapeDrawableBuilder *)regBuilder triBuilder:(WhirlyKit::ShapeDrawableBuilderTri *)triBuilder scene:(WhirlyKit::Scene *)scene selectManager:(SelectionManager *)selectManager sceneRep:(ShapeSceneRep *)sceneRep;

@end

@implementation WhirlyKitShape

@synthesize isSelectable;
@synthesize selectID;
@synthesize useColor;
@synthesize color;

// Base shape doesn't make anything
- (void)makeGeometryWithBuilder:(WhirlyKit::ShapeDrawableBuilder *)regBuilder triBuilder:(WhirlyKit::ShapeDrawableBuilderTri *)triBuilder scene:(WhirlyKit::Scene *)scene selectManager:(SelectionManager *)selectManager sceneRep:(ShapeSceneRep *)sceneRep
{
}

@end

// Number of samples for a circle.
// Note: Make this a parameter
static int CircleSamples = 10;

@implementation WhirlyKitCircle

@synthesize loc;
@synthesize radius;
@synthesize height;

// Build the geometry for a circle in display space
- (void)makeGeometryWithBuilder:(WhirlyKit::ShapeDrawableBuilder *)regBuilder triBuilder:(WhirlyKit::ShapeDrawableBuilderTri *)triBuilder scene:(WhirlyKit::Scene *)scene selectManager:(SelectionManager *)selectManager sceneRep:(ShapeSceneRep *)sceneRep
{
    CoordSystemDisplayAdapter *coordAdapter = scene->getCoordAdapter();
    
    RGBAColor theColor = (useColor ? color : [regBuilder->getShapeInfo().color asRGBAColor]);
    
    Point3f localPt = coordAdapter->getCoordSystem()->geographicToLocal(loc);
    Point3f dispPt = coordAdapter->localToDisplay(localPt);
    dispPt += coordAdapter->normalForLocal(localPt) * height;
    Point3f norm = coordAdapter->normalForLocal(localPt);
    
    // Construct a set of axes to build the circle around
    Point3f up = norm;
    Point3f xAxis,yAxis;
    if (coordAdapter->isFlat())
    {
        xAxis = Point3f(1,0,0);
        yAxis = Point3f(0,1,0);
    } else {
        Point3f north(0,0,1);
        // Note: Also check if we're at a pole
        xAxis = north.cross(up);  xAxis.normalize();
        yAxis = up.cross(xAxis);  yAxis.normalize();
    }
        
    // Calculate the locations, using the axis from the center
    std::vector<Point3f> samples;
    samples.resize(CircleSamples);
    for (unsigned int ii=0;ii<CircleSamples;ii++)
        samples[ii] =  xAxis * radius * sinf(2*M_PI*ii/(float)(CircleSamples-1)) + radius * yAxis * cosf(2*M_PI*ii/(float)(CircleSamples-1)) + dispPt;
    
    // We need the bounding box in the local coordinate system
    Mbr shapeMbr;
    for (unsigned int ii=0;ii<samples.size();ii++)
    {
        Point3f thisLocalPt = coordAdapter->displayToLocal(samples[ii]);
        // Note: If this shape has height, this is insufficient
        shapeMbr.addPoint(Point2f(thisLocalPt.x(),thisLocalPt.y()));
    }
    
    triBuilder->addConvexOutline(samples,norm,theColor,shapeMbr);
}

@end

static const float sqrt2 = 1.4142135623;

@implementation WhirlyKitSphere

@synthesize loc;
@synthesize height;
@synthesize radius;

// Note: We could make these parameters
static const float SphereTessX = 10;
static const float SphereTessY = 10;

- (void)makeGeometryWithBuilder:(WhirlyKit::ShapeDrawableBuilder *)regBuilder triBuilder:(WhirlyKit::ShapeDrawableBuilderTri *)triBuilder scene:(WhirlyKit::Scene *)scene selectManager:(SelectionManager *)selectManager sceneRep:(ShapeSceneRep *)sceneRep
{
    CoordSystemDisplayAdapter *coordAdapter = scene->getCoordAdapter();

    RGBAColor theColor = (useColor ? color : [regBuilder->getShapeInfo().color asRGBAColor]);

    // Get the location in display coordinates
    Point3f localPt = coordAdapter->getCoordSystem()->geographicToLocal(loc);
    Point3f dispPt = coordAdapter->localToDisplay(localPt);
    Point3f norm = coordAdapter->normalForLocal(localPt);
    
    // Run it up a bit by the height
    dispPt = dispPt + norm*height;
    
    // It's lame, but we'll use lat/lon coordinates to tesselate the sphere
    // Note: Replace this with something less lame
    std::vector<Point3f> locs,norms;
    locs.reserve((SphereTessX+1)*(SphereTessX+1));
    norms.reserve((SphereTessX+1)*(SphereTessY+1));
    std::vector<RGBAColor> colors;
    colors.reserve((SphereTessX+1)*(SphereTessX+1));
    Point2f geoIncr(2*M_PI/SphereTessX,M_PI/SphereTessY);
    for (unsigned int iy=0;iy<SphereTessY+1;iy++)
        for (unsigned int ix=0;ix<SphereTessX+1;ix++)
        {
            GeoCoord geoLoc(-M_PI+ix*geoIncr.x(),-M_PI/2.0 + iy*geoIncr.y());
			if (geoLoc.x() < -M_PI)  geoLoc.x() = -M_PI;
			if (geoLoc.x() > M_PI) geoLoc.x() = M_PI;
			if (geoLoc.y() < -M_PI/2.0)  geoLoc.y() = -M_PI/2.0;
			if (geoLoc.y() > M_PI/2.0) geoLoc.y() = M_PI/2.0;
            
            Point3f spherePt = FakeGeocentricDisplayAdapter::LocalToDisplay(Point3f(geoLoc.lon(),geoLoc.lat(),0.0));
            Point3f thisPt = dispPt + spherePt * radius;
            
            norms.push_back(spherePt);
            locs.push_back(thisPt);
            colors.push_back(theColor);
        }
    
    // Two triangles per cell
    std::vector<BasicDrawable::Triangle> tris;
    tris.reserve(2*SphereTessX*SphereTessY);
    for (unsigned int iy=0;iy<SphereTessY;iy++)
        for (unsigned int ix=0;ix<SphereTessX;ix++)
        {
			BasicDrawable::Triangle triA,triB;
			triA.verts[0] = iy*(SphereTessX+1)+ix;
			triA.verts[1] = iy*(SphereTessX+1)+(ix+1);
			triA.verts[2] = (iy+1)*(SphereTessX+1)+(ix+1);
			triB.verts[0] = triA.verts[0];
			triB.verts[1] = triA.verts[2];
			triB.verts[2] = (iy+1)*(SphereTessX+1)+ix;
            tris.push_back(triA);
            tris.push_back(triB);
        }
    
    triBuilder->addTriangles(locs,norms,colors,tris);

    // Add a selection region
    if (isSelectable)
    {
        Point3f pts[8];
        float dist = radius * sqrt2;
        pts[0] = dispPt + dist * Point3f(-1,-1,-1);
        pts[1] = dispPt + dist * Point3f(1,-1,-1);
        pts[2] = dispPt + dist * Point3f(1,1,-1);
        pts[3] = dispPt + dist * Point3f(-1,1,-1);
        pts[4] = dispPt + dist * Point3f(-1,-1,1);
        pts[5] = dispPt + dist * Point3f(1,-1,1);
        pts[6] = dispPt + dist * Point3f(1,1,1);
        pts[7] = dispPt + dist * Point3f(-1,1,1);
        selectManager->addSelectableRectSolid(selectID,pts,triBuilder->getShapeInfo().minVis,triBuilder->getShapeInfo().maxVis);
        sceneRep->selectIDs.insert(selectID);
    }
}

@end

@implementation WhirlyKitCylinder

@synthesize loc;
@synthesize baseHeight;
@synthesize radius;
@synthesize height;

static std::vector<Point3f> circleSamples;

// Build the geometry for a circle in display space
- (void)makeGeometryWithBuilder:(WhirlyKit::ShapeDrawableBuilder *)regBuilder triBuilder:(WhirlyKit::ShapeDrawableBuilderTri *)triBuilder scene:(WhirlyKit::Scene *)scene selectManager:(SelectionManager *)selectManager sceneRep:(ShapeSceneRep *)sceneRep
{
    CoordSystemDisplayAdapter *coordAdapter = scene->getCoordAdapter();
    
    RGBAColor theColor = (useColor ? color : [regBuilder->getShapeInfo().color asRGBAColor]);

    Point3f localPt = coordAdapter->getCoordSystem()->geographicToLocal(loc);
    Point3f dispPt = coordAdapter->localToDisplay(localPt);
    Point3f norm = coordAdapter->normalForLocal(localPt);
    
    // Move up by baseHeight
    dispPt += norm * baseHeight;
    
    // Construct a set of axes to build the circle around
    Point3f up = norm;
    Point3f xAxis,yAxis;
    if (coordAdapter->isFlat())
    {
        xAxis = Point3f(1,0,0);
        yAxis = Point3f(0,1,0);
    } else {
        Point3f north(0,0,1);
        // Note: Also check if we're at a pole
        xAxis = north.cross(up);  xAxis.normalize();
        yAxis = up.cross(xAxis);  yAxis.normalize();
    }
    
    // Generate the circle ones
    if (circleSamples.empty())
    {
        circleSamples.resize(CircleSamples);
        for (unsigned int ii=0;ii<CircleSamples;ii++)
            circleSamples[ii] = xAxis * sinf(2*M_PI*ii/(float)(CircleSamples-1)) + yAxis * cosf(2*M_PI*ii/(float)(CircleSamples-1));
    }

    // Calculate samples around the bottom
    std::vector<Point3f> samples;
    samples.resize(CircleSamples);
    for (unsigned int ii=0;ii<CircleSamples;ii++)
        samples[ii] =  radius * circleSamples[ii] + dispPt;
    
    // We need the bounding box in the local coordinate system
    // Note: This is not handling height correctly
    Mbr shapeMbr;
    for (unsigned int ii=0;ii<samples.size();ii++)
    {
        Point3f thisLocalPt = coordAdapter->displayToLocal(samples[ii]);
        // Note: If this shape has height, this is insufficient
        shapeMbr.addPoint(Point2f(thisLocalPt.x(),thisLocalPt.y()));
    }
    
    // For the top we just offset
    std::vector<Point3f> top = samples;
    for (unsigned int ii=0;ii<top.size();ii++)
    {
        Point3f &pt = top[ii];
        pt = pt + height * norm;
    }
    triBuilder->addConvexOutline(top,norm,theColor,shapeMbr);
    
    // For the sides we'll just run things bottom to top
    for (unsigned int ii=0;ii<CircleSamples;ii++)
    {
        std::vector<Point3f> pts(4);
        pts[0] = samples[ii];
        pts[1] = samples[(ii+1)%samples.size()];
        pts[2] = top[(ii+1)%top.size()];
        pts[3] = top[ii];
        Point3f thisNorm = (pts[0]-pts[1]).cross(pts[2]-pts[1]);
        thisNorm.normalize();
        triBuilder->addConvexOutline(pts, thisNorm, theColor, shapeMbr);
    }
    
    // Note: Would be nice to keep these around
    circleSamples.clear();
    
    // Add a selection region
    if (isSelectable)
    {
        Point3f pts[8];
        float dist1 = radius * sqrt2;
        pts[0] = dispPt - dist1 * xAxis - dist1 * yAxis;
        pts[1] = dispPt + dist1 * xAxis - dist1 * yAxis;
        pts[2] = dispPt + dist1 * xAxis + dist1 * yAxis;
        pts[3] = dispPt - dist1 * xAxis + dist1 * yAxis;
        pts[4] = pts[0] + height * norm;
        pts[5] = pts[1] + height * norm;
        pts[6] = pts[2] + height * norm;
        pts[7] = pts[3] + height * norm;
        selectManager->addSelectableRectSolid(selectID,pts,triBuilder->getShapeInfo().minVis,triBuilder->getShapeInfo().maxVis);
        sceneRep->selectIDs.insert(selectID);
    }
}

@end

@implementation WhirlyKitShapeLinear

@synthesize pts;
@synthesize mbr;
@synthesize lineWidth;

- (void)makeGeometryWithBuilder:(WhirlyKit::ShapeDrawableBuilder *)regBuilder triBuilder:(WhirlyKit::ShapeDrawableBuilderTri *)triBuilder scene:(WhirlyKit::Scene *)scene selectManager:(SelectionManager *)selectManager sceneRep:(ShapeSceneRep *)sceneRep
{
    RGBAColor theColor = (useColor ? color : [regBuilder->getShapeInfo().color asRGBAColor]);

    regBuilder->addPoints(pts, theColor, mbr, lineWidth, false);
}

@end

@implementation WhirlyKitShapeLayer

- (void)clear
{
    for (ShapeSceneRepSet::iterator it = shapeReps.begin();
         it != shapeReps.end(); ++it)
        delete *it;
    shapeReps.clear();    
}

- (void)dealloc
{
    [self clear];
}

// Called in the layer thread
- (void)startWithThread:(WhirlyKitLayerThread *)inLayerThread scene:(Scene *)inScene
{
    layerThread = inLayerThread;
    scene = inScene;
}

- (void)shutdown
{
    std::vector<ChangeRequest *> changeRequests;
    SelectionManager *selectManager = scene->getSelectionManager();
    
    for (ShapeSceneRepSet::iterator it = shapeReps.begin();
         it != shapeReps.end(); ++it)
        (*it)->clearContents(selectManager,changeRequests);
    
    [layerThread addChangeRequests:(changeRequests)];
    
    [self clear];
}

// Add a single shape
- (SimpleIdentity) addShape:(WhirlyKitShape *)shape desc:(NSDictionary *)desc
{
    return [self addShapes:[NSArray arrayWithObject:shape] desc:desc];
}

// Do the work for adding shapes
- (void)runAddShapes:(WhirlyKitShapeInfo *)shapeInfo
{
    if (!scene)
    {
        NSLog(@"Shape layer called before initialization.  Dropping data on floor.");
        return;
    }
    SelectionManager *selectManager = scene->getSelectionManager();
    
    ShapeSceneRep *sceneRep = new ShapeSceneRep(shapeInfo.shapeId);
    sceneRep->fade = shapeInfo.fade;

    std::vector<ChangeRequest *> changeRequests;
    ShapeDrawableBuilderTri drawBuildTri(scene->getCoordAdapter(),shapeInfo);
    ShapeDrawableBuilder drawBuildReg(scene->getCoordAdapter(),shapeInfo,true);

    // Work through the shapes
    for (WhirlyKitShape *shape in shapeInfo.shapes)
        [shape makeGeometryWithBuilder:&drawBuildReg triBuilder:&drawBuildTri scene:scene selectManager:selectManager sceneRep:sceneRep];
    
    // Flush out remaining geometry
    drawBuildReg.flush();
    drawBuildReg.getChanges(changeRequests, sceneRep->drawIDs);
    drawBuildTri.flush();
    drawBuildTri.getChanges(changeRequests, sceneRep->drawIDs);
    
    [layerThread addChangeRequests:(changeRequests)];
    
    shapeReps.insert(sceneRep);
}

// Do the work for removing shapes
- (void)runRemoveShapes:(NSNumber *)num
{
    SimpleIdentity shapeId = [num unsignedIntValue];
    SelectionManager *selectManager = scene->getSelectionManager();
    
    ShapeSceneRep dummyRep(shapeId);
    ShapeSceneRepSet::iterator it = shapeReps.find(&dummyRep);
    NSTimeInterval curTime = CFAbsoluteTimeGetCurrent();
    if (it != shapeReps.end())
    {
        ShapeSceneRep *shapeRep = *it;
        
        std::vector<ChangeRequest *> changeRequests;
        if (shapeRep->fade > 0.0)
        {
            for (SimpleIDSet::iterator idIt = shapeRep->drawIDs.begin();
                 idIt != shapeRep->drawIDs.end(); ++idIt)
                changeRequests.push_back(new FadeChangeRequest(*idIt, curTime, curTime+shapeRep->fade));
            [self performSelector:@selector(runRemoveShapes:) withObject:num afterDelay:shapeRep->fade];
            shapeRep->fade = 0.0;
        } else {
            shapeRep->clearContents(selectManager, changeRequests);
            shapeReps.erase(it);
            delete shapeRep;
        }
        
        [layerThread addChangeRequests:(changeRequests)];
    }
}

// Add a whole bunch of shapes
- (SimpleIdentity) addShapes:(NSArray *)shapes desc:(NSDictionary *)desc
{
   if (!layerThread)
   {
       NSLog(@"ShapeLayer: Tried to call shape layer before it was initialized.  Dropping shapes on floor.");
       return EmptyIdentity;
   }

   WhirlyKitShapeInfo *shapeInfo = [[WhirlyKitShapeInfo alloc] initWithShapes:shapes desc:desc];
    
    if (!layerThread || ([NSThread currentThread] == layerThread))
        [self runAddShapes:shapeInfo];
    else
        [self performSelector:@selector(runAddShapes:) onThread:layerThread withObject:shapeInfo waitUntilDone:NO];
    
    return shapeInfo.shapeId;
}

// Remove a group of shapes
- (void) removeShapes:(WhirlyKit::SimpleIdentity)shapeID
{
    NSNumber *num = [NSNumber numberWithUnsignedInt:shapeID];
    if (!layerThread || ([NSThread currentThread] == layerThread))
        [self runRemoveShapes:num];
    else
        [self performSelector:@selector(runRemoveShapes:) onThread:layerThread withObject:num waitUntilDone:NO];
}

@end

