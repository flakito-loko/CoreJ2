import Foundation

/// A discrete unit of work within an import pipeline session.
@MainActor
protocol ImportStep {
    /// Performs this step against the shared import session state.
    /// - Parameter context: Mutable state for the current import.
    /// - Throws: If the step encounters a fatal import error.
    func run(on context: ImportContext) throws
}
