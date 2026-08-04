import CoreGraphics
import Foundation

/// Converts an `EmulatorFrame` ARGB8888 buffer into a CoreGraphics image.
///
/// FreeJ2ME packs `TYPE_INT_ARGB` little-endian (`B,G,R,A` bytes). That layout
/// matches CoreGraphics `byteOrder32Little` + alpha `.first` (BGRA) with no
/// channel swizzle. Does not use Metal.
enum EmulatorFrameCGImageConverter {

    // MARK: - Public

    /// Builds a `CGImage` from a validated `EmulatorFrame`.
    ///
    /// - Returns: `nil` when the pixel format is unsupported or the buffer size
    ///   does not match `width × height × 4`.
    static func makeCGImage(from frame: EmulatorFrame) -> CGImage? {
        makeCGImage(
            width: frame.width,
            height: frame.height,
            pixelFormat: frame.pixelFormat,
            pixels: frame.pixels
        )
    }

    /// Builds a `CGImage` from raw LCD dimensions and packed pixels.
    ///
    /// Invalid dimensions, formats, or buffer lengths return `nil` without
    /// throwing — callers should ignore the frame.
    static func makeCGImage(
        width: Int,
        height: Int,
        pixelFormat: EmulatorPixelFormat,
        pixels: Data
    ) -> CGImage? {
        guard pixelFormat == .argb8888 else {
            return nil
        }
        guard width > 0, height > 0 else {
            return nil
        }

        let pixelCount = width * height
        let expectedByteCount = pixelCount * 4
        guard pixels.count == expectedByteCount else {
            return nil
        }

        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // LE ARGB ints → memory order B,G,R,A ≡ BGRA under little-endian.
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue)
        )

        guard let provider = CGDataProvider(data: pixels as CFData) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
