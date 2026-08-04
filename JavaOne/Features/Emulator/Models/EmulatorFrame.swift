import Foundation

/// Pixel layout of an `EmulatorFrame` buffer.
enum EmulatorPixelFormat: String, Equatable, Sendable {

    /// Packed 32-bit ARGB as produced by FreeJ2ME `BufferedImage.getRGB`
    /// (`TYPE_INT_ARGB`), stored little-endian in `EmulatorFrame.pixels`.
    case argb8888
}

/// One LCD framebuffer delivered to the app through `RuntimeEvent.frameAvailable`.
///
/// Contains CPU-side pixels only — no Metal texture, UIImage, or SwiftUI view.
struct EmulatorFrame: Equatable, Sendable {

    /// LCD width in pixels.
    let width: Int

    /// LCD height in pixels.
    let height: Int

    /// Interpretation of `pixels`.
    let pixelFormat: EmulatorPixelFormat

    /// Packed pixels (`width * height * 4` bytes for `.argb8888`).
    ///
    /// Ownership: this `Data` is an independent copy owned by the event consumer.
    /// The FreeJ2ME `BufferedImage` is never shared across the process boundary.
    let pixels: Data

    /// `width * height`.
    var pixelCount: Int {
        width * height
    }

    /// - Returns: `nil` when dimensions / buffer size are inconsistent.
    init?(width: Int, height: Int, pixelFormat: EmulatorPixelFormat, pixels: Data) {
        let expected = width * height * 4
        guard width > 0, height > 0, pixels.count == expected else {
            return nil
        }
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.pixels = pixels
    }
}
