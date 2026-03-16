import UIKit
import ObjectiveC

public final class ImageLoader {
    public static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 150
    }

    public func load(url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = cache.object(forKey: url as NSURL) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self?.cache.setObject(image, forKey: url as NSURL)
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }
}

private var currentURLKey: UInt8 = 0

public extension UIImageView {
    var currentLoadingURL: URL? {
        get { objc_getAssociatedObject(self, &currentURLKey) as? URL }
        set { objc_setAssociatedObject(self, &currentURLKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func loadImage(from url: URL?, placeholder: UIImage? = nil) {
        image = placeholder
        currentLoadingURL = url
        guard let url = url else {
            removeShimmerOverlay()
            return
        }

        addShimmerOverlay()

        ImageLoader.shared.load(url: url) { [weak self] loadedImage in
            guard self?.currentLoadingURL == url else { return }
            self?.image = loadedImage
            self?.removeShimmerOverlay()
        }
    }

    func cancelImageLoad() {
        currentLoadingURL = nil
        removeShimmerOverlay()
    }
}
