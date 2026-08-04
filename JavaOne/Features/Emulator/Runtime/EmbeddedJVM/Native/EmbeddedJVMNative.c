#include "EmbeddedJVMNative.h"

#include <jni.h>

#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
static JavaVM *g_vm = NULL;
static int g_created = 0;

enum {
    JAVAONE_DESTROY_TIMEOUT_SEC = 3,
    JAVAONE_DESTROY_TIMED_OUT = -301
};

static void javaone_clear_exception(JNIEnv *env) {
    if (env == NULL) {
        return;
    }
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
}

int javaone_embedded_jvm_is_created(void) {
    int value;
    pthread_mutex_lock(&g_lock);
    value = g_created;
    pthread_mutex_unlock(&g_lock);
    return value;
}

void *javaone_embedded_jvm_javavm(void) {
    void *vm;
    pthread_mutex_lock(&g_lock);
    vm = (void *)g_vm;
    pthread_mutex_unlock(&g_lock);
    return vm;
}

int javaone_embedded_jvm_create(const char *java_home, const char *classpath) {
    if (java_home == NULL || classpath == NULL) {
        return -100;
    }

    pthread_mutex_lock(&g_lock);
    if (g_created || g_vm != NULL) {
        pthread_mutex_unlock(&g_lock);
        return -101; /* second JVM rejected */
    }

    char classpath_opt[4096];
    char java_home_opt[4096];
    int n = snprintf(classpath_opt, sizeof(classpath_opt), "-Djava.class.path=%s", classpath);
    if (n <= 0 || (size_t)n >= sizeof(classpath_opt)) {
        pthread_mutex_unlock(&g_lock);
        return -102;
    }
    n = snprintf(java_home_opt, sizeof(java_home_opt), "-Djava.home=%s", java_home);
    if (n <= 0 || (size_t)n >= sizeof(java_home_opt)) {
        pthread_mutex_unlock(&g_lock);
        return -103;
    }

    JavaVMOption options[6];
    memset(options, 0, sizeof(options));
    options[0].optionString = classpath_opt;
    options[1].optionString = java_home_opt;
    options[2].optionString = "-Xrs";
    options[3].optionString = "-Xmx64m";
    options[4].optionString = "-Djava.awt.headless=true";
    options[5].optionString = "-XX:+UseSerialGC";

    JavaVMInitArgs args;
    memset(&args, 0, sizeof(args));
    args.version = JNI_VERSION_10;
    args.nOptions = 6;
    args.options = options;
    args.ignoreUnrecognized = JNI_FALSE;

    JNIEnv *env = NULL;
    jint rc = JNI_CreateJavaVM(&g_vm, (void **)&env, &args);
    if (rc != JNI_OK || g_vm == NULL) {
        g_vm = NULL;
        g_created = 0;
        pthread_mutex_unlock(&g_lock);
        return (int)rc;
    }

    g_created = 1;
    pthread_mutex_unlock(&g_lock);
    return 0;
}

int javaone_embedded_jvm_run_hello_world(const char *main_class_jni) {
    if (main_class_jni == NULL) {
        return -200;
    }

    pthread_mutex_lock(&g_lock);
    if (!g_created || g_vm == NULL) {
        pthread_mutex_unlock(&g_lock);
        return -201;
    }
    JavaVM *vm = g_vm;
    pthread_mutex_unlock(&g_lock);

    JNIEnv *env = NULL;
    jint attach = (*vm)->GetEnv(vm, (void **)&env, JNI_VERSION_10);
    if (attach == JNI_EDETACHED) {
        attach = (*vm)->AttachCurrentThread(vm, (void **)&env, NULL);
    }
    if (attach != JNI_OK || env == NULL) {
        return -202;
    }

    jclass cls = (*env)->FindClass(env, main_class_jni);
    if (cls == NULL) {
        javaone_clear_exception(env);
        return -203;
    }

    jmethodID main_mid = (*env)->GetStaticMethodID(env, cls, "main", "([Ljava/lang/String;)V");
    if (main_mid == NULL) {
        javaone_clear_exception(env);
        return -204;
    }

    jclass string_cls = (*env)->FindClass(env, "java/lang/String");
    if (string_cls == NULL) {
        javaone_clear_exception(env);
        return -205;
    }
    jobjectArray empty_args = (*env)->NewObjectArray(env, 0, string_cls, NULL);
    if (empty_args == NULL) {
        javaone_clear_exception(env);
        return -206;
    }

    (*env)->CallStaticVoidMethod(env, cls, main_mid, empty_args);
    if ((*env)->ExceptionCheck(env)) {
        javaone_clear_exception(env);
        return -207;
    }

    jfieldID completed_fid = (*env)->GetStaticFieldID(env, cls, "completed", "Z");
    if (completed_fid == NULL) {
        javaone_clear_exception(env);
        return -208;
    }
    jboolean completed = (*env)->GetStaticBooleanField(env, cls, completed_fid);
    if (!completed) {
        return -209;
    }

    return 0;
}

typedef struct {
    JavaVM *vm;
    jint rc;
    int finished;
    pthread_mutex_t mu;
    pthread_cond_t cv;
} JavaOneDestroyJob;

static void *javaone_destroy_thread_main(void *arg) {
    JavaOneDestroyJob *job = (JavaOneDestroyJob *)arg;
    jint rc = (*job->vm)->DestroyJavaVM(job->vm);
    pthread_mutex_lock(&job->mu);
    job->rc = rc;
    job->finished = 1;
    pthread_cond_signal(&job->cv);
    pthread_mutex_unlock(&job->mu);
    return NULL;
}

int javaone_embedded_jvm_destroy(void) {
    pthread_mutex_lock(&g_lock);
    if (!g_created || g_vm == NULL) {
        g_created = 0;
        g_vm = NULL;
        pthread_mutex_unlock(&g_lock);
        return 0;
    }
    JavaVM *vm = g_vm;
    g_vm = NULL;
    g_created = 0;
    pthread_mutex_unlock(&g_lock);

    /* Release the creating thread's JNI attachment before destroy when possible. */
    JNIEnv *env = NULL;
    if ((*vm)->GetEnv(vm, (void **)&env, JNI_VERSION_10) == JNI_OK && env != NULL) {
        (void)(*vm)->DetachCurrentThread(vm);
    }

    JavaOneDestroyJob job;
    memset(&job, 0, sizeof(job));
    job.vm = vm;
    job.rc = JNI_ERR;
    job.finished = 0;
    pthread_mutex_init(&job.mu, NULL);
    pthread_cond_init(&job.cv, NULL);

    pthread_t thread;
    if (pthread_create(&thread, NULL, javaone_destroy_thread_main, &job) != 0) {
        pthread_mutex_destroy(&job.mu);
        pthread_cond_destroy(&job.cv);
        /* Last resort: block on calling thread. */
        return (int)(*vm)->DestroyJavaVM(vm);
    }

    struct timespec deadline;
    clock_gettime(CLOCK_REALTIME, &deadline);
    deadline.tv_sec += JAVAONE_DESTROY_TIMEOUT_SEC;

    pthread_mutex_lock(&job.mu);
    while (!job.finished) {
        int wr = pthread_cond_timedwait(&job.cv, &job.mu, &deadline);
        if (wr == ETIMEDOUT) {
            break;
        }
    }
    int finished = job.finished;
    jint rc = job.rc;
    pthread_mutex_unlock(&job.mu);

    if (!finished) {
        /* HotSpot may block forever in Threads::destroy_vm; reclaim on process exit. */
        pthread_detach(thread);
        pthread_mutex_destroy(&job.mu);
        pthread_cond_destroy(&job.cv);
        return JAVAONE_DESTROY_TIMED_OUT;
    }

    pthread_join(thread, NULL);
    pthread_mutex_destroy(&job.mu);
    pthread_cond_destroy(&job.cv);
    return (int)rc;
}
