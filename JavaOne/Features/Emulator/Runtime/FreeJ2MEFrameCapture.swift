import Foundation

/// One FreeJ2ME LCD framebuffer capture (metadata + CPU pixel copy).
///
/// Produced when the registered painter runs and reads `MobilePlatform.getLCD()`.
/// No Metal / SwiftUI — pixels are for `RuntimeEvent.frameAvailable` only.
struct FreeJ2MEFrameCapture: Equatable, Sendable {

    /// 1-based painter invocation index within the host bootstrap session.
    let paintIndex: Int

    /// LCD width in pixels (`BufferedImage.getWidth()`).
    let width: Int

    /// LCD height in pixels (`BufferedImage.getHeight()`).
    let height: Int

    /// `width * height` — number of ARGB ints read via `getRGB`.
    let pixelCount: Int

    /// FNV-1a style checksum over packed ARGB pixels (detects framebuffer changes).
    let checksum: UInt64

    /// FreeJ2ME `BufferedImage` type name (e.g. `TYPE_INT_ARGB`).
    let pixelFormat: String

    /// Independent little-endian ARGB8888 copy (`pixelCount * 4` bytes).
    let pixels: Data

    /// Builds an app-facing `EmulatorFrame` when the capture is well-formed.
    func makeEmulatorFrame() -> EmulatorFrame? {
        guard pixelFormat == "TYPE_INT_ARGB" else {
            return nil
        }
        return EmulatorFrame(
            width: width,
            height: height,
            pixelFormat: .argb8888,
            pixels: pixels
        )
    }
}

/// Result of installing the FreeJ2ME painter and verifying framebuffer access.
struct FreeJ2MEPainterRegistrationResult: Equatable, Sendable {

    /// Number of times the painter callback ran during registration.
    let paintEventCount: Int

    /// Per-callback framebuffer snapshots (including pixel copies).
    let frames: [FreeJ2MEFrameCapture]
}
