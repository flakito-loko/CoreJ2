#include "JNIGatewayNative.h"

#include <stddef.h>

/// App Target stub: no libjvm linked. Real implementation lives in JNIGatewayNative.c for harness.

int javaone_jni_gateway_invoke_hello_world_main_cached(
    uint64_t class_native_id,
    int32_t *out_frames_pushed,
    int32_t *out_frames_popped,
    char *out_exception_type,
    int32_t out_exception_type_len,
    char *out_exception_message,
    int32_t out_exception_message_len
) {
    (void)class_native_id;
    if (out_frames_pushed != NULL) {
        *out_frames_pushed = 0;
    }
    if (out_frames_popped != NULL) {
        *out_frames_popped = 0;
    }
    if (out_exception_type != NULL && out_exception_type_len > 0) {
        out_exception_type[0] = '\0';
    }
    if (out_exception_message != NULL && out_exception_message_len > 0) {
        out_exception_message[0] = '\0';
    }
    return -8; /* JAVAONE_JGW_UNAVAILABLE */
}

int javaone_jni_gateway_cache_find_class(const char *binary_name, uint64_t *out_id) {
    (void)binary_name;
    if (out_id != NULL) {
        *out_id = 0;
    }
    return -8;
}

int javaone_jni_gateway_cache_get_method(
    uint64_t class_id,
    const char *name,
    const char *signature,
    int32_t is_static,
    uint64_t *out_id
) {
    (void)class_id;
    (void)name;
    (void)signature;
    (void)is_static;
    if (out_id != NULL) {
        *out_id = 0;
    }
    return -8;
}

int javaone_jni_gateway_cache_get_field(
    uint64_t class_id,
    const char *name,
    const char *signature,
    int32_t is_static,
    uint64_t *out_id
) {
    (void)class_id;
    (void)name;
    (void)signature;
    (void)is_static;
    if (out_id != NULL) {
        *out_id = 0;
    }
    return -8;
}

void javaone_jni_gateway_cache_clear_all(void) {}

int javaone_jni_gateway_object_create_global(uint64_t class_id, uint64_t *out_id) {
    (void)class_id;
    if (out_id != NULL) {
        *out_id = 0;
    }
    return -8;
}

int javaone_jni_gateway_object_new_global(
    uint64_t class_id,
    uint64_t constructor_method_id,
    const javaone_jgw_value *args,
    int32_t argc,
    uint64_t *out_id
) {
    (void)class_id;
    (void)constructor_method_id;
    (void)args;
    (void)argc;
    if (out_id != NULL) {
        *out_id = 0;
    }
    return -8;
}

int javaone_jni_gateway_object_release_global(uint64_t object_id) {
    (void)object_id;
    return 0;
}

int javaone_jni_gateway_object_contains(uint64_t object_id) {
    (void)object_id;
    return 0;
}

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
) {
    (void)class_id;
    (void)method_id;
    (void)is_static;
    (void)receiver_object_id;
    (void)args;
    (void)argc;
    (void)return_kind;
    (void)out_result;
    if (out_string != NULL && out_string_len > 0) {
        out_string[0] = '\0';
    }
    if (out_frames_pushed != NULL) {
        *out_frames_pushed = 0;
    }
    if (out_frames_popped != NULL) {
        *out_frames_popped = 0;
    }
    if (out_exception_type != NULL && out_exception_type_len > 0) {
        out_exception_type[0] = '\0';
    }
    if (out_exception_message != NULL && out_exception_message_len > 0) {
        out_exception_message[0] = '\0';
    }
    return -8;
}

int32_t javaone_jni_gateway_cache_find_class_count(void) { return 0; }
int32_t javaone_jni_gateway_cache_get_method_count(void) { return 0; }
int32_t javaone_jni_gateway_cache_get_field_count(void) { return 0; }
int32_t javaone_jni_gateway_cache_live_global_class_count(void) { return 0; }
int32_t javaone_jni_gateway_cache_live_global_object_count(void) { return 0; }

int javaone_jni_gateway_register_native(
    uint64_t class_id,
    const char *method_name,
    const char *signature,
    int32_t is_static,
    uint64_t token
) {
    (void)class_id;
    (void)method_name;
    (void)signature;
    (void)is_static;
    (void)token;
    return -8;
}

int javaone_jni_gateway_unregister_native(uint64_t token) {
    (void)token;
    return -8;
}

void javaone_jni_gateway_unregister_all_natives(void) {}

