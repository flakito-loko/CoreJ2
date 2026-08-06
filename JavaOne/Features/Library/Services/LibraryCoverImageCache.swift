import UIKit

/// In-memory cover image cache for smooth library scrolling.
final class LibraryCoverImageCache: @unchecked Sendable {

    static let shared = LibraryCoverImageCache()

    private let cache = NSCache<NSURL, UIImage>()
    private let lock = NSLock()

    private init() {
        cache.countLimit = 120
        cache.totalCostLimit = 40 * 1024 * 1024
    }

    func image(at url: URL) -> UIImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        lock.lock()
        defer { lock.unlock() }

        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }

        let cost = data.count
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }

    func clear() {
        cache.removeAllObjects()
    }
}
