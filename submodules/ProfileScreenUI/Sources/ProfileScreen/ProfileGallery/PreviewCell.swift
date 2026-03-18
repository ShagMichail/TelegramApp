import Foundation
import UIKit
import AVFoundation
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import PhotoResources

final class PreviewCell: UICollectionViewCell {
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let spinner: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private var imageLoadingTask: Task<Void, Never>?


    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.backgroundColor = .darkGray
        self.layer.cornerRadius = 8
        self.clipsToBounds = true

        self.contentView.addSubview(self.imageView)
        self.contentView.addSubview(self.spinner)

        NSLayoutConstraint.activate([
            self.imageView.topAnchor.constraint(equalTo: self.contentView.topAnchor),
            self.imageView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
            self.imageView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
            self.imageView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor),

            self.spinner.centerXAnchor.constraint(equalTo: self.contentView.centerXAnchor),
            self.spinner.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }


    // MARK: - Override

    override func prepareForReuse() {
        super.prepareForReuse()
        self.imageLoadingTask?.cancel()
        self.imageLoadingTask = nil
        self.imageView.image = nil
        self.spinner.startAnimating()
        // Сброс трансформации перед переиспользованием ячейки
        self.transform = .identity
        self.alpha = 1.0
        self.layer.borderWidth = 0
    }


    // MARK: - Internal

    func configure(with urlString: String, isVideo: Bool = false) {
        self.imageLoadingTask?.cancel()
        self.spinner.startAnimating()
        
        guard let url = URL(string: urlString) else {
            self.spinner.stopAnimating()
            return
        }
        
        if isVideo {
            self.imageLoadingTask = Task { @MainActor in
                do {
                    let image = try await self.generateVideoThumbnail(from: url, at: 0.1)
                    if !Task.isCancelled {
                        self.imageView.image = image
                    }
                } catch {
                    if !Task.isCancelled {
                        print("Failed to generate video thumbnail: \(error)")
                    }
                }
                if !Task.isCancelled {
                    self.spinner.stopAnimating()
                }
            }
        } else {
            self.imageLoadingTask = Task { @MainActor in
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        if !Task.isCancelled {
                            self.imageView.image = image
                        }
                    }
                } catch {
                    if !Task.isCancelled {
                        print("Failed to load preview: \(error)")
                    }
                }
                if !Task.isCancelled {
                    self.spinner.stopAnimating()
                }
            }
        }
    }

    
    // MARK: - Private
    
    private func generateVideoThumbnail(from url: URL, at time: Double) async throws -> UIImage {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 150, height: 150) // Маленький размер для превью
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        // Используем старый API для iOS 13+
        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: cmTime)]) { _, cgImage, _, _, _ in
                if let cgImage = cgImage {
                    let image = UIImage(cgImage: cgImage)
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: NSError(domain: "ThumbnailGeneration", code: -1, userInfo: nil))
                }
            }
        }
    }
}