#include <jni.h>
#include "byedpi_engine.h"

JNIEXPORT jint JNICALL
Java_com_github_tfox_flutter_1vless_xray_service_ByeDpiEngine_start(
        JNIEnv *env, jobject self, jint profile, jstring protect_path) {
    (void)self;
    const char *path = (*env)->GetStringUTFChars(env, protect_path, 0);
    if (!path) return 0;
    int port = byedpi_engine_start((int)profile, path, NULL);
    (*env)->ReleaseStringUTFChars(env, protect_path, path);
    return (jint)port;
}

JNIEXPORT jboolean JNICALL
Java_com_github_tfox_flutter_1vless_xray_service_ByeDpiEngine_stop(
        JNIEnv *env, jobject self) {
    (void)env; (void)self;
    return byedpi_engine_stop() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_github_tfox_flutter_1vless_xray_service_ByeDpiEngine_isRunning(
        JNIEnv *env, jobject self) {
    (void)env; (void)self;
    return byedpi_engine_is_running() ? JNI_TRUE : JNI_FALSE;
}
