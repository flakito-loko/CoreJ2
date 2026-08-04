import Foundation

/// Where the Phase-1 spike loads `libjvm` / `java.home` from.
public enum EmbeddedJVMLibrarySource: Sendable, Equatable {
    /// Staged OpenJDK Mobile static/shared image from Fase 0 artifacts.
    case openJDKMobile(stagedRoot: URL, javaHome: URL)
    /// Host OpenJDK (engineering fallback until Mobile `libjvm` exists).
    case hostJDK(javaHome: URL)
}

/// Immutable configuration for one Embedded JVM process instance.
public struct EmbeddedJVMConfiguration: Sendable, Equatable {
    public var librarySource: EmbeddedJVMLibrarySource
    public var classpath: URL
    public var helloWorldMainClass: String
    public var libjvmURL: URL?

    public init(
        librarySource: EmbeddedJVMLibrarySource,
        classpath: URL,
        helloWorldMainClass: String = "org.javaone.embedded.spike.HelloWorld",
        libjvmURL: URL? = nil
    ) {
        self.librarySource = librarySource
        self.classpath = classpath
        self.helloWorldMainClass = helloWorldMainClass
        self.libjvmURL = libjvmURL
    }

    public var javaHomeURL: URL {
        switch librarySource {
        case .openJDKMobile(_, let javaHome), .hostJDK(let javaHome):
            return javaHome
        }
    }

    public var backendLabel: String {
        switch librarySource {
        case .openJDKMobile:
            return "openjdk-mobile"
        case .hostJDK:
            return "host-jdk"
        }
    }
}
