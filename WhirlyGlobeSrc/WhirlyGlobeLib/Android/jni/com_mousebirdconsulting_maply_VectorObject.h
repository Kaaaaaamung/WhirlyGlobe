/* DO NOT EDIT THIS FILE - it is machine generated */
#include <jni.h>
/* Header for class com_mousebirdconsulting_maply_VectorObject */

#ifndef _Included_com_mousebirdconsulting_maply_VectorObject
#define _Included_com_mousebirdconsulting_maply_VectorObject
#ifdef __cplusplus
extern "C" {
#endif
/*
 * Class:     com_mousebirdconsulting_maply_VectorObject
 * Method:    getAttributes
 * Signature: ()Lcom/mousebirdconsulting/maply/AttrDictionary;
 */
JNIEXPORT jobject JNICALL Java_com_mousebirdconsulting_maply_VectorObject_getAttributes
  (JNIEnv *, jobject);

/*
 * Class:     com_mousebirdconsulting_maply_VectorObject
 * Method:    addPoint
 * Signature: (Lcom/mousebirdconsulting/maply/Point2d;)V
 */
JNIEXPORT void JNICALL Java_com_mousebirdconsulting_maply_VectorObject_addPoint
  (JNIEnv *, jobject, jobject);

/*
 * Class:     com_mousebirdconsulting_maply_VectorObject
 * Method:    addLinear
 * Signature: ([Lcom/mousebirdconsulting/maply/Point2d;)V
 */
JNIEXPORT void JNICALL Java_com_mousebirdconsulting_maply_VectorObject_addLinear
  (JNIEnv *, jobject, jobjectArray);

/*
 * Class:     com_mousebirdconsulting_maply_VectorObject
 * Method:    addAreal
 * Signature: ([Lcom/mousebirdconsulting/maply/Point2d;)V
 */
JNIEXPORT void JNICALL Java_com_mousebirdconsulting_maply_VectorObject_addAreal
  (JNIEnv *, jobject, jobjectArray);

/*
 * Class:     com_mousebirdconsulting_maply_VectorObject
 * Method:    fromGeoJSON
 * Signature: (Ljava/lang/String;)Z
 */
JNIEXPORT jboolean JNICALL Java_com_mousebirdconsulting_maply_VectorObject_fromGeoJSON
  (JNIEnv *, jobject, jstring);

/*
 * Class:     com_mousebirdconsulting_maply_VectorObject
 * Method:    FromGeoJSONAssembly
 * Signature: (Ljava/lang/String;)Ljava/util/Map;
 */
JNIEXPORT jobject JNICALL Java_com_mousebirdconsulting_maply_VectorObject_FromGeoJSONAssembly
  (JNIEnv *, jclass, jstring);

/*
 * Class:     com_mousebirdconsulting_maply_VectorObject
 * Method:    readFromFile
 * Signature: (Ljava/lang/String;)Z
 */
JNIEXPORT jboolean JNICALL Java_com_mousebirdconsulting_maply_VectorObject_readFromFile
  (JNIEnv *, jobject, jstring);

/*
 * Class:     com_mousebirdconsulting_maply_VectorObject
 * Method:    writeToFile
 * Signature: (Ljava/lang/String;)Z
 */
JNIEXPORT jboolean JNICALL Java_com_mousebirdconsulting_maply_VectorObject_writeToFile
  (JNIEnv *, jobject, jstring);

/*
 * Class:     com_mousebirdconsulting_maply_VectorObject
 * Method:    initialise
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_mousebirdconsulting_maply_VectorObject_initialise
  (JNIEnv *, jobject);

/*
 * Class:     com_mousebirdconsulting_maply_VectorObject
 * Method:    dispose
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_mousebirdconsulting_maply_VectorObject_dispose
  (JNIEnv *, jobject);

#ifdef __cplusplus
}
#endif
#endif
