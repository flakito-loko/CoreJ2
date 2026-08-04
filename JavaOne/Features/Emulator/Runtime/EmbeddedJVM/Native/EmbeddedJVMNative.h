#ifndef JAVAONE_EMBEDDED_JVM_NATIVE_H
#define JAVAONE_EMBEDDED_JVM_NATIVE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Phase-1 only: create one JVM, run HelloWorld.main, destroy.
/// Not a JNI Gateway. Returns 0 on success; non-zero JNI / local error codes otherwise.

int javaone_embedded_jvm_create(const char *java_home, const char *classpath);
int javaone_embedded_jvm_run_hello_world(const char *main_class_jni);
int javaone_embedded_jvm_destroy(void);
int javaone_embedded_jvm_is_created(void);

/// Opaque process JavaVM for JNIGateway (NULL if not created). Do not destroy via Gateway.
void *javaone_embedded_jvm_javavm(void);

#ifdef __cplusplus
}
#endif

#endif /* JAVAONE_EMBEDDED_JVM_NATIVE_H */
