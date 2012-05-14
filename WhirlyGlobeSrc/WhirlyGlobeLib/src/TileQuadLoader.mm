/*
 *  TileQuadLoader.mm
 *  WhirlyGlobeLib
 *
 *  Created by Steve Gifford on 4/27/12.
 *  Copyright 2011 mousebird consulting
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

#import "GlobeMath.h"
#import "GlobeLayerViewWatcher.h"
#import "UIImage+Stuff.h"
#import <boost/math/special_functions/fpclassify.hpp>
#import "TileQuadLoader.h"

using namespace Eigen;
using namespace WhirlyKit;
using namespace WhirlyGlobe;

@interface WhirlyGlobeQuadTileLoader()
- (void)buildTile:(Quadtree::NodeInfo *)nodeInfo draw:(BasicDrawable **)draw tex:(Texture **)tex texScale:(Point2f)texScale texOffset:(Point2f)texOffset lines:(bool)buildLines layer:(WhirlyGlobeQuadDisplayLayer *)layer imageData:(NSData *)imageData;
- (LoadedTile *)getTile:(Quadtree::Identifier)ident;
@end

namespace WhirlyGlobe
{
    
LoadedTile::LoadedTile()
{
    isOn = false;
    isLoading = false;
    drawId = EmptyIdentity;
    texId = EmptyIdentity;
    for (unsigned int ii=0;ii<4;ii++)
    {
        childIsOn[ii] = false;
        childDrawIds[ii] = false;
    }
}
    
LoadedTile::LoadedTile(const WhirlyKit::Quadtree::Identifier &ident)
{
    nodeInfo.ident = ident;
    isOn = false;
    isLoading = false;
    drawId = EmptyIdentity;
    texId = EmptyIdentity;
    for (unsigned int ii=0;ii<4;ii++)
    {
        childIsOn[ii] = false;
        childDrawIds[ii] = false;
    }    
}

// Add the geometry and texture to the scene for a given tile
void LoadedTile::addToScene(WhirlyGlobeQuadTileLoader *loader,WhirlyGlobeQuadDisplayLayer *layer,GlobeScene *scene,NSData *imageData)
{
    BasicDrawable *draw = NULL;
    Texture *tex = NULL;
    [loader buildTile:&nodeInfo draw:&draw tex:&tex texScale:Point2f(1.0,1.0) texOffset:Point2f(0.0,0.0) lines:layer.lineMode layer:layer imageData:imageData];
    drawId = draw->getId();
    if (tex)
        texId = tex->getId();
    else
        texId = EmptyIdentity;
    
    // Now for the changes to the scenegraph
    // Texture first, then drawable
    std::vector<ChangeRequest *> changeRequests;
    if (tex)
        changeRequests.push_back(new AddTextureReq(tex));
    changeRequests.push_back(new AddDrawableReq(draw));    
    scene->addChangeRequests(changeRequests);
    
    // Just in case, we don't have any child drawables here
    for (unsigned int ii=0;ii<4;ii++)
    {
        childIsOn[ii] = false;
        childDrawIds[ii] = EmptyIdentity;
    }
    
    isOn = true;
}

// Clean out the geometry and texture associated with the given tile
void LoadedTile::clearContents(WhirlyGlobeQuadTileLoader *loader,WhirlyGlobeQuadDisplayLayer *layer,GlobeScene *scene,std::vector<ChangeRequest *> &changeRequests)
{
    if (drawId != EmptyIdentity)
    {
        changeRequests.push_back(new RemDrawableReq(drawId));
        drawId = EmptyIdentity;
    }
    if (texId != EmptyIdentity)
    {
        changeRequests.push_back(new RemTextureReq(texId));
        texId = EmptyIdentity;
    }
    for (unsigned int ii=0;ii<4;ii++)
        if (childDrawIds[ii] != EmptyIdentity)
        {
            changeRequests.push_back(new RemDrawableReq(childDrawIds[ii]));
        }
}

// Make sure a given tile overlaps the real world
bool isValidTile(WhirlyGlobeQuadDisplayLayer *layer,Mbr theMbr)
{    
    return (theMbr.overlaps(layer.mbr));
}

// Update based on what children are doing
void LoadedTile::updateContents(WhirlyGlobeQuadTileLoader *loader,WhirlyGlobeQuadDisplayLayer *layer,Quadtree *tree,std::vector<ChangeRequest *> &changeRequests)
{
    //    NSLog(@"Updating children for node (%d,%d,%d)",nodeInfo.ident.x,nodeInfo.ident.y,nodeInfo.ident.level);
    
    bool childrenExist = false;
    
    {
        // Work through the possible children
        int whichChild = 0;
        for (unsigned int iy=0;iy<2;iy++)
            for (unsigned int ix=0;ix<2;ix++)
            {
                // Is it here?
                bool isPresent = false;
                Quadtree::Identifier childIdent(2*nodeInfo.ident.x+ix,2*nodeInfo.ident.y+iy,nodeInfo.ident.level+1);
                LoadedTile *childTile = [loader getTile:childIdent];
                isPresent = childTile && !childTile->isLoading;
                
                // If it exists, make sure we're not representing it here
                if (isPresent)
                {
                    //                    NSLog(@"  Child present: (%d,%d,%d)",childIdent.x,childIdent.y,childIdent.level);
                    // Turn the child back off
                    if (childDrawIds[whichChild] != EmptyIdentity)
                    {
                        changeRequests.push_back(new OnOffChangeRequest(childDrawIds[whichChild],false));
                        childIsOn[whichChild] = false;
                    }
                    
                    childrenExist = true;
                } else {
                    //                    NSLog(@"  Child missing: (%d,%d,%d)",childIdent.x,childIdent.y,childIdent.level);
                    
                    // It's not there, so make sure we're faking it with our texture
                    //                    if (!childIsOn[whichChild])
                    {
                        // May need to build the geometry
                        if (childDrawIds[whichChild] == EmptyIdentity)
                        {
                            Quadtree::NodeInfo childInfo = tree->generateNode(childIdent);
                            if (isValidTile(layer,childInfo.mbr))
                            {
                                BasicDrawable *childDraw = NULL;
                                [loader buildTile:&childInfo draw:&childDraw tex:NULL texScale:Point2f(0.5,0.5) texOffset:Point2f(0.5*ix,0.5*iy) lines:((texId == EmptyIdentity)||layer.lineMode) layer:layer imageData:nil];
                                childDrawIds[whichChild] = childDraw->getId();
                                if (!layer.lineMode && texId)
                                    childDraw->setTexId(texId);
                                changeRequests.push_back(new AddDrawableReq(childDraw));
                                childIsOn[whichChild] = true;
                            }
                        } else {
                            // Just turn it on
                            changeRequests.push_back(new OnOffChangeRequest(childDrawIds[whichChild],true));
                            childIsOn[whichChild] = true;
                        }
                    }
                }
                
                whichChild++;
            }
    }
    
    // No children, so turn the geometry for this tile back on
    if (!childrenExist)
    {
        //        if (!isOn)
        {
            changeRequests.push_back(new OnOffChangeRequest(drawId,true));
            isOn = true;
        }
        
        // Also turn off any children that may have been on
        for (unsigned int ii=0;ii<4;ii++)
            //            if (childIsOn[ii])
        {
            if (childDrawIds[ii] != EmptyIdentity)
            {
                changeRequests.push_back(new OnOffChangeRequest(childDrawIds[ii],false));
                childIsOn[ii] = false;
            }
        }
    } else {
        // Make sure our representation is off
        // if (isOn)
        changeRequests.push_back(new OnOffChangeRequest(drawId,false));
        isOn = false;
    }
    
    //    tree->Print();
}


void LoadedTile::Print(Quadtree *tree)
{
    NSLog(@"Node (%d,%d,%d), draw is %@, drawId = %d, texId = %d",nodeInfo.ident.x,nodeInfo.ident.y,nodeInfo.ident.level,(isOn ? @"on" : @"off"),(int)drawId,(int)texId);
    for (unsigned int ii=0;ii<4;ii++)
    {
        NSLog(@" Child %d is %@, drawId = %d",ii,(childIsOn[ii] ? @"on" : @"off"),(int)childDrawIds[ii]);
    }
    std::vector<Quadtree::Identifier> childIdents;
    tree->childrenForNode(nodeInfo.ident,childIdents);
    for (unsigned int ii=0;ii<childIdents.size();ii++)
        NSLog(@" Query child (%d,%d,%d)",childIdents[ii].x,childIdents[ii].y,childIdents[ii].level);
}
    
}

@implementation WhirlyGlobeQuadTileLoader

@synthesize drawOffset;
@synthesize drawPriority;
@synthesize color;
@synthesize hasAlpha;
@synthesize quadLayer;

- (id)initWithDataSource:(NSObject<WhirlyGlobeQuadTileImageDataSource> *)inDataSource;
{
    self = [super init];
    if (self)
    {
        dataSource = inDataSource;
        drawOffset = 0;
        drawPriority = 0;
        color = RGBAColor(255,255,255,255);
        hasAlpha = false;
        numFetches = 0;
    }
    
    return self;
}

- (void)clear
{
    for (LoadedTileSet::iterator it = tileSet.begin();
         it != tileSet.end(); ++it)
        delete *it;    
    tileSet.clear();

    for (unsigned int ii=0;ii<changeRequests.size();ii++)
        delete changeRequests[ii];
    changeRequests.clear();
    
    numFetches = 0;

    parents.clear();
}

- (void)dealloc
{
    [self clear];
}

- (void)setQuadLayer:(WhirlyGlobeQuadDisplayLayer *)layer
{
    quadLayer = layer;
}

- (void)shutdownLayer:(WhirlyGlobeQuadDisplayLayer *)layer scene:(WhirlyKit::Scene *)scene
{
    std::vector<ChangeRequest *> theChangeRequests;
    
    for (LoadedTileSet::iterator it = tileSet.begin();
         it != tileSet.end(); ++it)
    {
        LoadedTile *tile = *it;
        tile->clearContents(self,layer,(WhirlyGlobe::GlobeScene *)scene,theChangeRequests);
    }
    
    scene->addChangeRequests(theChangeRequests);
    
    
    [self clear];
}

// Tesselation for each chunk of the sphere
const int SphereTessX = 10, SphereTessY = 10;

- (void)buildTile:(Quadtree::NodeInfo *)nodeInfo draw:(BasicDrawable **)draw tex:(Texture **)tex texScale:(Point2f)texScale texOffset:(Point2f)texOffset lines:(bool)buildLines layer:(WhirlyGlobeQuadDisplayLayer *)layer imageData:(NSData *)imageData
{
    Mbr theMbr = nodeInfo->mbr;
    
    // Make sure this overlaps the area we care about
    Mbr mbr = layer.mbr;
    if (!theMbr.overlaps(mbr))
    {
        NSLog(@"Building bogus tile: (%d,%d,%d)",nodeInfo->ident.x,nodeInfo->ident.y,nodeInfo->ident.level);
    }
    
    // Snap to the designated area
    if (theMbr.ll().x() < mbr.ll().x())
        theMbr.ll().x() = mbr.ll().x();
    if (theMbr.ur().x() > mbr.ur().x())
        theMbr.ur().x() = mbr.ur().x();
    if (theMbr.ll().y() < mbr.ll().y())
        theMbr.ll().y() = mbr.ll().y();
    if (theMbr.ur().y() > mbr.ur().y())
        theMbr.ur().y() = mbr.ur().y();
    
    // Number of pieces at this level
    int xDim = 1<<nodeInfo->ident.level;
    int yDim = 1<<nodeInfo->ident.level;
    
    //    NSLog(@"Chunk ll = (%.4f,%.4f)  ur = (%.4f,%.4f)",mbr.ll().x(),mbr.ll().y(),mbr.ur().x(),mbr.ur().y());
    
    // Size of each chunk
    Point2f chunkSize = theMbr.ur() - theMbr.ll();
    
    // Unit size of each tesselation in spherical mercator
    Point2f incr(chunkSize.x()/SphereTessX,chunkSize.y()/SphereTessY);
    
    // Texture increment for each tesselation
    TexCoord texIncr(1.0/(float)SphereTessX,1.0/(float)SphereTessY);
    
	// We're viewing this as a parameterization from ([0->1.0],[0->1.0]) so we'll
	//  break up these coordinates accordingly
    Point2f paramSize(1.0/(xDim*SphereTessX),1.0/(yDim*SphereTessY));
    
    // We need the corners in geographic for the cullable
    Point2f chunkLL = theMbr.ll();
    Point2f chunkUR = theMbr.ur();
    CoordSystem *coordSys = layer.coordSys;
    GeoCoord geoLL(coordSys->localToGeographic(Point3f(chunkLL.x(),chunkLL.y(),0.0)));
    GeoCoord geoUR(coordSys->localToGeographic(Point3f(chunkUR.x(),chunkUR.y(),0.0)));
    
    // Get texture (locally)
    if (tex)
    {
        if (imageData)
        {
            UIImage *texImage = [UIImage imageWithData:imageData];
            if (texImage)
            {
                // Create the texture and set it up in OpenGL
                Texture *newTex = new Texture(texImage);
                [EAGLContext setCurrentContext:layer.layerThread.glContext];
                newTex->createInGL();
                *tex = newTex;
            }
        } else
            *tex = NULL;
    }
    
    if (draw)
    {
        // We'll set up and fill in the drawable
        BasicDrawable *chunk = new BasicDrawable((SphereTessX+1)*(SphereTessY+1),2*SphereTessX*SphereTessY);
        chunk->setDrawOffset(drawOffset);
        chunk->setDrawPriority(drawPriority);
        chunk->setAlpha(hasAlpha);
        chunk->setColor(color);
//        chunk->setGeoMbr(GeoMbr(geoLL,geoUR));
        // Note: This is bogus, but it fixes a display bug
        chunk->setGeoMbr(GeoMbr(GeoCoord::CoordFromDegrees(-180,-90),GeoCoord::CoordFromDegrees(180, 90)));
        
        // We're in line mode or the texture didn't load
        if (buildLines || (tex && !(*tex)))
        {
            chunk->setType(GL_LINES);
            
            // Two lines per cell
            for (unsigned int iy=0;iy<SphereTessY;iy++)
                for (unsigned int ix=0;ix<SphereTessX;ix++)
                {
                    Point3f org3D = coordSys->localToGeocentricish(Point3f(chunkLL.x()+ix*incr.x(),chunkLL.y()+iy*incr.y(),0.0));
                    Point3f ptA_3D = coordSys->localToGeocentricish(Point3f(chunkLL.x()+(ix+1)*incr.x(),chunkLL.y()+iy*incr.y(),0.0));
                    Point3f ptB_3D = coordSys->localToGeocentricish(Point3f(chunkLL.x()+ix*incr.x(),chunkLL.y()+(iy+1)*incr.y(),0.0));
                    
                    TexCoord texCoord(ix*texIncr.x()*texScale.x()+texOffset.x(),1.0-(iy*texIncr.y()*texScale.y()+texOffset.y()));
                    
                    chunk->addPoint(org3D);
                    chunk->addNormal(org3D);
                    chunk->addTexCoord(texCoord);
                    chunk->addPoint(ptA_3D);
                    chunk->addNormal(ptA_3D);
                    chunk->addTexCoord(texCoord);
                    
                    chunk->addPoint(org3D);
                    chunk->addNormal(org3D);
                    chunk->addTexCoord(texCoord);
                    chunk->addPoint(ptB_3D);
                    chunk->addNormal(ptB_3D);
                    chunk->addTexCoord(texCoord);
                }
        } else {
            chunk->setType(GL_TRIANGLES);
            // Generate point, texture coords, and normals
            for (unsigned int iy=0;iy<SphereTessY+1;iy++)
                for (unsigned int ix=0;ix<SphereTessX+1;ix++)
                {
                    Point3f loc3D = coordSys->localToGeocentricish(Point3f(chunkLL.x()+ix*incr.x(),chunkLL.y()+iy*incr.y(),0.0));
                    
                    // Do the texture coordinate seperately
                    TexCoord texCoord(ix*texIncr.x()*texScale.x()+texOffset.x(),1.0-(iy*texIncr.y()*texScale.y()+texOffset.y()));
                    
                    chunk->addPoint(loc3D);
                    chunk->addTexCoord(texCoord);
                    chunk->addNormal(loc3D);
                }
            
            // Two triangles per cell
            for (unsigned int iy=0;iy<SphereTessY;iy++)
            {
                for (unsigned int ix=0;ix<SphereTessX;ix++)
                {
                    BasicDrawable::Triangle triA,triB;
                    triA.verts[0] = iy*(SphereTessX+1)+ix;
                    triA.verts[1] = iy*(SphereTessX+1)+(ix+1);
                    triA.verts[2] = (iy+1)*(SphereTessX+1)+(ix+1);
                    triB.verts[0] = triA.verts[0];
                    triB.verts[1] = triA.verts[2];
                    triB.verts[2] = (iy+1)*(SphereTessX+1)+ix;
                    chunk->addTriangle(triA);
                    chunk->addTriangle(triB);
                }
            }
            
            if (tex && *tex)
                chunk->setTexId((*tex)->getId());
        }
        
        *draw = chunk;
    }    
}

// We'll get this before a series of unloads
- (void)quadDisplayLayerStartUpdates:(WhirlyGlobeQuadDisplayLayer *)layer
{
    // This should not happen
    if (!changeRequests.empty())
        for (unsigned int ii=0;ii<<changeRequests.size();ii++)
            delete changeRequests[ii];    
    changeRequests.clear();
}

// Make all the various parents update their child geometry
- (void)refreshParents:(WhirlyGlobeQuadDisplayLayer *)layer
{
    // Update just the parents that have changed recently
    for (std::set<Quadtree::Identifier>::iterator it = parents.begin();
         it != parents.end(); ++it)
    {
        LoadedTile *theTile = [self getTile:*it];
        NSLog(@"Updating parent (%d,%d,%d) isLoading = %@",theTile->nodeInfo.ident.x,theTile->nodeInfo.ident.y,
              theTile->nodeInfo.ident.level,(theTile->isLoading ? @"yes" : @"no"));
        if (theTile && !theTile->isLoading)
            theTile->updateContents(self, layer, layer.quadtree, changeRequests);
    }
    parents.clear();
    
    // Flush out all the changes at once for this step
    if (!changeRequests.empty())
    {
        layer.scene->addChangeRequests(changeRequests);
        changeRequests.clear();
    }        
}

// Thus ends the unloads.  Now we can update parents
- (void)quadDisplayLayerEndUpdates:(WhirlyGlobeQuadDisplayLayer *)layer
{
    [self refreshParents:layer];
}

#pragma mark - Loader delegate

// We can do another fetch if we haven't hit the max
- (bool)isReady
{
    return (numFetches < [dataSource maxSimultaneousFetches]);
}

// Ask the data source to start loading the image for this tile
- (void)quadDisplayLayer:(WhirlyGlobeQuadDisplayLayer *)layer loadTile:(WhirlyKit::Quadtree::NodeInfo)tileInfo
{
    // Build the new tile
    LoadedTile *newTile = new LoadedTile();
    newTile->nodeInfo = tileInfo;
    newTile->isLoading = true;

    tileSet.insert(newTile);
    numFetches++;
    [dataSource quadTileLoader:self startFetchForLevel:tileInfo.ident.level col:tileInfo.ident.x row:tileInfo.ident.y];
    
    NSLog(@"Started loading tile (%d,%d,%d)",tileInfo.ident.x,tileInfo.ident.y,tileInfo.ident.level);
}

// Check if we're in the process of loading the given tile
- (bool)quadDisplayLayer:(WhirlyGlobeQuadDisplayLayer *)layer canLoadChildrenOfTile:(WhirlyKit::Quadtree::NodeInfo)tileInfo
{
    LoadedTile dummyTile(tileInfo.ident);
    LoadedTileSet::iterator it = tileSet.find(&dummyTile);
    // This means the quad layer thinks we have a tile we don't.  No idea why that might be.
    if (it == tileSet.end())
        return false;    
    LoadedTile *tile = *it;
    
    // If it's not loading, sure
    return !tile->isLoading;
}

// When the data source loads the image, we'll get called here
- (void)dataSource:(NSObject<WhirlyGlobeQuadTileImageDataSource> *)dataSource loadedImage:(NSData *)image forLevel:(int)level col:(int)col row:(int)row
{
    // Look for the tile
    // If it's not here, just drop this on the floor
    LoadedTile dummyTile(Quadtree::Identifier(col,row,level));
    LoadedTileSet::iterator it = tileSet.find(&dummyTile);
    numFetches--;
    if (it == tileSet.end())
        return;
    
    LoadedTile *tile = *it;
    if (image)
    {
        tile->isLoading = false;
        tile->addToScene(self,quadLayer,quadLayer.scene,image);    
        [quadLayer loader:self tileDidLoad:tile->nodeInfo.ident];
    } else {
        // Shouldn't have a visual representation, so just lose it
        [quadLayer loader:self tileDidNotLoad:tile->nodeInfo.ident];
        tileSet.erase(it);
        delete tile;
    }

    NSLog(@"Loaded image for tile (%d,%d,%d)",col,row,level);
    
    // Various child state changed so let's update the parents
    if (level > 0)
        parents.insert(Quadtree::Identifier(col/2,row/2,level-1));
    [self refreshParents:quadLayer];
}

- (void)quadDisplayLayer:(WhirlyGlobeQuadDisplayLayer *)layer unloadTile:(WhirlyKit::Quadtree::NodeInfo)tileInfo
{
    // Get rid of an old tile
    LoadedTile dummyTile;
    dummyTile.nodeInfo.ident = tileInfo.ident;
    LoadedTileSet::iterator it = tileSet.find(&dummyTile);
    if (it != tileSet.end())
    {
        LoadedTile *theTile = *it;
        
        // Note: Debugging check
        std::vector<Quadtree::Identifier> childIDs;
        layer.quadtree->childrenForNode(theTile->nodeInfo.ident, childIDs);
        if (childIDs.size() > 0)
            NSLog(@" *** Deleting node with children *** ");
        
        theTile->clearContents(self,layer,layer.scene,changeRequests);
        tileSet.erase(it);
        delete theTile;
    }    

    NSLog(@"Unloaded tile (%d,%d,%d)",tileInfo.ident.x,tileInfo.ident.y,tileInfo.ident.level);

    // We'll put this on the list of parents to update, but it'll actually happen in EndUpdates
    if (tileInfo.ident.level > 0)
        parents.insert(Quadtree::Identifier(tileInfo.ident.x/2,tileInfo.ident.y/2,tileInfo.ident.level-1));
}

// Look for a specific tile
- (LoadedTile *)getTile:(Quadtree::Identifier)ident
{
//    LoadedTile dummyTile;
//    dummyTile.nodeInfo.ident = ident;
//    LoadedTileSet::iterator it = tileSet.find(&dummyTile);
//
//    if (it == tileSet.end())
//        return nil;
    
    for (LoadedTileSet::iterator it = tileSet.begin();
         it != tileSet.end(); ++it)
    {
        LoadedTile *tile = *it;
        if (tile->nodeInfo.ident.level == ident.level &&
            tile->nodeInfo.ident.x == ident.x &&
            tile->nodeInfo.ident.y == ident.y)
            return tile;
    }
    
    return nil;
}


@end
