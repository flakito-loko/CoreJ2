import Foundation

/// Test double for `EmbeddedJVMReadiness` without constructing a full manager.
final class StubEmbeddedJVMReadiness: EmbeddedJVMReadiness, @unchecked Sendable {
    var state: EmbeddedJVMState

    init(state: EmbeddedJVMState) {
        self.state = state
    }
}
