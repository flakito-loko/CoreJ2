import Foundation

#if canImport(Darwin)

@_silgen_name("javaone_embedded_jvm_is_created")
func javaone_embedded_jvm_is_created() -> Int32

@_silgen_name("javaone_embedded_jvm_create")
func javaone_embedded_jvm_create(
    _ javaHome: UnsafePointer<CChar>?,
    _ classpath: UnsafePointer<CChar>?
) -> Int32

@_silgen_name("javaone_embedded_jvm_run_hello_world")
func javaone_embedded_jvm_run_hello_world(_ mainClassJNI: UnsafePointer<CChar>?) -> Int32

@_silgen_name("javaone_embedded_jvm_destroy")
func javaone_embedded_jvm_destroy() -> Int32

/// Real native runtime using `JNI_CreateJavaVM` (Phase 1 harness — JVM lifecycle only).
/// HelloWorld product invokes must go through `JNIGateway` (E2-US001).
public final class JNICreateJavaVMNativeRuntime: EmbeddedJVMNativeRuntime, @unchecked Sendable {
    public init() {}

    public var isJVMCreated: Bool {
        javaone_embedded_jvm_is_created() != 0
    }

    public func createJVM(javaHomePath: String, classpath: String) throws {
        let code = javaHomePath.withCString { homePtr in
            classpath.withCString { cpPtr in
                javaone_embedded_jvm_create(homePtr, cpPtr)
            }
        }
        if code == -101 {
            throw EmbeddedJVMError.secondJVMRejected
        }
        if code != 0 {
            throw EmbeddedJVMError.nativeCreateFailed(Int32(code))
        }
    }

    public func runHelloWorld(mainClassJNI: String) throws {
        // Kept for Phase-1 harness compatibility; production path is JNIGateway.
        let code = mainClassJNI.withCString { javaone_embedded_jvm_run_hello_world($0) }
        if code != 0 {
            throw EmbeddedJVMError.nativeHelloFailed(Int32(code))
        }
    }

    public func destroyJVM() throws {
        let code = javaone_embedded_jvm_destroy()
        if code == -301 {
            throw EmbeddedJVMError.nativeDestroyTimedOut
        }
        if code != 0 {
            throw EmbeddedJVMError.nativeDestroyFailed(Int32(code))
        }
    }
}

#endif
