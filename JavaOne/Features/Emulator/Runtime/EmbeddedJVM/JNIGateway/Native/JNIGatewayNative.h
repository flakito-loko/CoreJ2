#ifndef JAVAONE_JNI_GATEWAY_NATIVE_H
#define JAVAONE_JNI_GATEWAY_NATIVE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Invoke HelloWorld.main using a cached global class ref id from cache_find_class.
int javaone_jni_gateway_invoke_hello_world_main_cached(
    uint64_t class_native_id,
    int32_t *out_frames_pushed,
    int32_t *out_frames_popped,
    char *out_exception_type,
    int32_t out_exception_type_len,
    char *out_exception_message,
    int32_t out_exception_message_len
);

/// FindClass → NewGlobalRef → DeleteLocalRef → store. out_id receives opaque native id.
int javaone_jni_gateway_cache_find_class(const char *binary_name, uint64_t *out_id);

/// GetMethodID / GetStaticMethodID → store.
int javaone_jni_gateway_cache_get_method(
    uint64_t class_id,
    const char *name,
    const char *signature,
    int32_t is_static,
    uint64_t *out_id
);

/// GetFieldID / GetStaticFieldID → store (foundation).
int javaone_jni_gateway_cache_get_field(
    uint64_t class_id,
    const char *name,
    const char *signature,
    int32_t is_static,
    uint64_t *out_id
);

/// DeleteGlobalRef all cached classes and objects; clear method/field tables.
void javaone_jni_gateway_cache_clear_all(void);

/// AllocObject → NewGlobalRef → DeleteLocalRef → store.
int javaone_jni_gateway_object_create_global(uint64_t class_id, uint64_t *out_id);

/// DeleteGlobalRef one object. Returns 1 if released, 0 if unknown.
int javaone_jni_gateway_object_release_global(uint64_t object_id);

/// Returns 1 if object GlobalRef slot is live.
int javaone_jni_gateway_object_contains(uint64_t object_id);

enum {
    JAVAONE_JGW_KIND_VOID = 0,
    JAVAONE_JGW_KIND_BOOLEAN = 1,
    JAVAONE_JGW_KIND_INT = 2,
    JAVAONE_JGW_KIND_LONG = 3,
    JAVAONE_JGW_KIND_FLOAT = 4,
    JAVAONE_JGW_KIND_DOUBLE = 5,
    JAVAONE_JGW_KIND_STRING = 6,
    JAVAONE_JGW_KIND_OBJECT = 7,
    JAVAONE_JGW_KIND_NULL = 8
};

#define JAVAONE_JGW_MAX_CALL_ARGS 16

typedef struct {
    int32_t kind;
    int32_t i32;
    int64_t i64;
    float f32;
    double f64;
    const char *str;
    uint64_t object_id;
} javaone_jgw_value;

/// NewObjectA(constructor) → NewGlobalRef → DeleteLocalRef → store.
int javaone_jni_gateway_object_new_global(
    uint64_t class_id,
    uint64_t constructor_method_id,
    const javaone_jgw_value *args,
    int32_t argc,
    uint64_t *out_id
);

/// Generic CallStatic* / Call* using cached class/method/object ids.
int javaone_jni_gateway_call(
    uint64_t class_id,
    uint64_t method_id,
    int32_t is_static,
    uint64_t receiver_object_id,
    const javaone_jgw_value *args,
    int32_t argc,
    int32_t return_kind,
    javaone_jgw_value *out_result,
    char *out_string,
    int32_t out_string_len,
    int32_t *out_frames_pushed,
    int32_t *out_frames_popped,
    char *out_exception_type,
    int32_t out_exception_type_len,
    char *out_exception_message,
    int32_t out_exception_message_len
);

int32_t javaone_jni_gateway_cache_find_class_count(void);
int32_t javaone_jni_gateway_cache_get_method_count(void);
int32_t javaone_jni_gateway_cache_get_field_count(void);
int32_t javaone_jni_gateway_cache_live_global_class_count(void);
int32_t javaone_jni_gateway_cache_live_global_object_count(void);

/// RegisterNatives for one method; `token` is the Swift registration id.
int javaone_jni_gateway_register_native(
    uint64_t class_id,
    const char *method_name,
    const char *signature,
    int32_t is_static,
    uint64_t token
);

int javaone_jni_gateway_unregister_native(uint64_t token);

void javaone_jni_gateway_unregister_all_natives(void);

/// Implemented in Swift (`@_cdecl`). Copies are already in `args`; no JNIEnv crosses this boundary.
void javaone_jni_gateway_trampoline_dispatch(
    uint64_t token,
    const javaone_jgw_value *args,
    int32_t argc,
    javaone_jgw_value *out_result
);

#ifdef __cplusplus
}
#endif

#endif /* JAVAONE_JNI_GATEWAY_NATIVE_H */
