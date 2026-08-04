import Foundation

/// Opaque native operations required by `EmbeddedJVMManager` (Phase 1).
///
/// This is **not** the JNI Gateway (Fase 2). Implementations may call
/// `JNI_CreateJavaVM` / `DestroyJavaVM` / a single Hello World `main` invoke only.
public protocol EmbeddedJVMNativeRuntime: Sendable {
    /// Creates at most one JVM in the process. Returns `JNI_OK` (0) on success.
    func createJVM(javaHomePath: String, classpath: String) throws

    /// Invokes `HelloWorld.main` on the existing JVM. Must not load FreeJ2ME or any JAR product.
    func runHelloWorld(mainClassJNI: String) throws

    /// Destroys the process JVM.
    func destroyJVM() throws

    /// Whether a JVM created by this runtime is currently alive.
    var isJVMCreated: Bool { get }
}
