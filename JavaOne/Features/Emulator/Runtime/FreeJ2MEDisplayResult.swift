import Foundation

/// Typed success result of FreeJ2ME Display lifecycle verification after `runJar()`.
///
/// Produced when the Display singleton exists and a current `Displayable` is active
/// (MIDlet called `Display.setCurrent`). Does not imply repaint, painter flush, or pixels.
struct FreeJ2MEDisplayResult: Equatable, Sendable {

    /// Display name from the JAR's `MIDlet-1` manifest attribute.
    let midletName: String

    /// Absolute `file://` URL string loaded into FreeJ2ME.
    let jarURLString: String

    /// `true` when FreeJ2ME's Display singleton is non-null.
    let displayInitialized: Bool

    /// `true` when `Display.getCurrent()` is non-null.
    let hasCurrentDisplayable: Bool

    /// Simple class name of the current Displayable, if any.
    let currentDisplayableClassName: String?

    /// `true` when Display lifecycle reached an active Displayable (`setCurrent` effect).
    var displayLifecycleReached: Bool {
        displayInitialized && hasCurrentDisplayable
    }
}
