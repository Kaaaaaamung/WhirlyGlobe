/*
 *  Cullable.java
 *  WhirlyGlobeLib
 *
 *  Created by jmnavarro
 *  Copyright 2011-2015 mousebird consulting
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
package com.mousebird.maply;

import java.util.ArrayList;

public class Cullable {

    long id = Identifiable.genID();

    public Cullable(CoordSystemDisplayAdapter coordSystem, Mbr localMbr, int depth){
        initialise(coordSystem, localMbr, depth);
    }

    public void finalise(){
        dispose();
    }

    public native void addDrawable(CullTree cullTree, Mbr localMbr, Drawable drawable);

    public native ArrayList<Drawable> getDrawables();

    public native ArrayList<Drawable> getChildDrawables();

    public native boolean hasChildren();

    public native boolean isEmpty();

    public native Cullable getChild(int which);

    public native Mbr getMbr();

    public native int countNodes();

    native void dispose();

    native void initialise(CoordSystemDisplayAdapter coordSystem, Mbr localMbr, int depth);
    static
    {
        nativeInit();
    }
    private static native void nativeInit();
    private long nativeHandle;

}