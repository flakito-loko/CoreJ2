import Foundation

/// Cold-start / footprint metrics for the Phase-1 Hello World spike.
public struct EmbeddedJVMMetrics: Sendable, Equatable {
    /// Wall time for `ensureStarted` (create VM → Ready), nanoseconds.
    public var startupNanoseconds: UInt64 = 0

    /// Wall time for Hello World invocation only, nanoseconds.
    public var helloWorldNanoseconds: UInt64 = 0

    /// Wall time for destroy (`Shutdown` → `Destroyed`), nanoseconds.
    public var destroyNanoseconds: UInt64 = 0

    /// Process resident size before JVM create (bytes), if sampled.
    public var rssBeforeCreateBytes: UInt64?

    /// Process resident size after Ready (bytes), if sampled.
    public var rssAfterReadyBytes: UInt64?

    /// Process resident size after Hello World (bytes), if sampled.
    public var rssAfterHelloBytes: UInt64?

    /// Process resident size after Destroyed (bytes), if sampled.
    public var rssAfterDestroyBytes: UInt64?

    /// On-disk size of the linked / loaded `libjvm` artifact (bytes).
    public var libjvmBytes: UInt64?

    /// On-disk size of `HelloWorld.class` (bytes).
    public var helloWorldClassBytes: UInt64?

    /// Backend label recorded by the harness (`openjdk-mobile` or `host-jdk`).
    public var backendLabel: String = ""

    /// `true` when `DestroyJavaVM` did not finish within the Phase-1 timeout
    /// (HotSpot host known issue); process exit still reclaims the VM.
    public var destroyTimedOut: Bool = false

    public init() {}

    public var startupMilliseconds: Double {
        Double(startupNanoseconds) / 1_000_000
    }

    public var helloWorldMilliseconds: Double {
        Double(helloWorldNanoseconds) / 1_000_000
    }

    public var destroyMilliseconds: Double {
        Double(destroyNanoseconds) / 1_000_000
    }

    public var rssDeltaCreateBytes: Int64? {
        guard let before = rssBeforeCreateBytes, let after = rssAfterReadyBytes else { return nil }
        return Int64(after) - Int64(before)
    }
}
