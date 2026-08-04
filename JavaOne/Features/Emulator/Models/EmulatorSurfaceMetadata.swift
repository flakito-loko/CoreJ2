import Foundation

/// LCD surface metadata held by `EmulatorViewModel` after a frame arrives.
///
/// Pixels are intentionally omitted from published UI state in this skeleton —
/// only dimensions and format are exposed for the SwiftUI surface.
struct EmulatorSurfaceMetadata: Equatable, Sendable {

    /// LCD width in pixels from the latest `EmulatorFrame`.
    let width: Int

    /// LCD height in pixels from the latest `EmulatorFrame`.
    let height: Int

    /// Pixel layout of the latest frame.
    let pixelFormat: EmulatorPixelFormat

    /// `width * height` from the latest frame.
    let pixelCount: Int
}
