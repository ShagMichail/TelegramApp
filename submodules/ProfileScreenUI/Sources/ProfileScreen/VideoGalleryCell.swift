import UIKit
import AVKit
import Display

final class VideoGalleryCell: UICollectionViewCell {
    static let reuseIdentifier = "VideoGalleryCell"

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .black
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let playerLayer: AVPlayerLayer = {
        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspectFill
        layer.backgroundColor = UIColor.clear.cgColor
        return layer
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(12)
        label.textColor = .white
        label.numberOfLines = 2
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let durationContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let durationLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(10)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let shimmerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var player: AVPlayer?
    private var isPlaying: Bool = false
    private var playerItemStatusObservation: NSKeyValueObservation?
    private var canAutoPlay: Bool = false

    private var currentVideoUrl: URL?
    private var retryCount = 0
    private let maxRetries = 3

    private var timeObserverToken: Any?
    private var totalDurationSeconds: Double = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.clipsToBounds = true

        contentView.addSubview(thumbnailImageView)
        contentView.layer.addSublayer(playerLayer)
        contentView.addSubview(shimmerContainer)
        contentView.addSubview(titleLabel)

        contentView.addSubview(durationContainer)
        durationContainer.addSubview(durationLabel)

        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            shimmerContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            shimmerContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            shimmerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            shimmerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            durationContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            durationContainer.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -6),

            durationLabel.topAnchor.constraint(equalTo: durationContainer.topAnchor, constant: 2),
            durationLabel.bottomAnchor.constraint(equalTo: durationContainer.bottomAnchor, constant: -2),
            durationLabel.leadingAnchor.constraint(equalTo: durationContainer.leadingAnchor, constant: 4),
            durationLabel.trailingAnchor.constraint(equalTo: durationContainer.trailingAnchor, constant: -4)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = contentView.bounds
        if self.window != nil && !shimmerContainer.isHidden {
            shimmerContainer.stopShimmering()
            shimmerContainer.startShimmering()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        layoutIfNeeded()
    }

    func configure(with videoUrl: String, previewUrl: String? = nil, title: String? = nil) {
        titleLabel.text = title ?? ""
        durationContainer.isHidden = true

        self.canAutoPlay = Int.random(in: 1...4) == 1

        shimmerContainer.isHidden = false
        shimmerContainer.alpha = 1.0
        if self.window != nil && !shimmerContainer.isHidden {
            shimmerContainer.stopShimmering()
            shimmerContainer.startShimmering()
        }

        guard let url = URL(string: videoUrl) else {
            hideShimmer()
            return
        }

        self.currentVideoUrl = url
        self.retryCount = 0

        loadThumbnail(for: url, fallbackPreviewUrl: previewUrl, attempt: 1)
        setupPlayer(with: url)
    }

    private func setupPlayer(with url: URL) {
        cleanUpPlayerObservers()

        let asset = AVAsset(url: url)
        loadDuration(from: asset)

        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.isMuted = true
        player?.actionAtItemEnd = .none
        playerLayer.player = player

        setupTimeObserver()

        playerItemStatusObservation = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    self.hideShimmer()
                    self.durationContainer.isHidden = false
                } else if item.status == .failed {
                    self.handlePlayerError()
                }
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    private func handlePlayerError() {
        guard retryCount < maxRetries, let url = currentVideoUrl else {
            hideShimmer()
            return
        }

        retryCount += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, !self.shimmerContainer.isHidden else { return }
            self.setupPlayer(with: url)
        }
    }

    private func setupTimeObserver() {
        guard let player = player else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, self.totalDurationSeconds > 0 else { return }

            let currentSeconds = CMTimeGetSeconds(time)
            let remainingSeconds = max(0, self.totalDurationSeconds - currentSeconds)

            self.durationLabel.text = self.formatDuration(seconds: remainingSeconds)
        }
    }

    private func loadDuration(from asset: AVAsset) {
        asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "duration", error: &error)

            if status == .loaded {
                let duration = asset.duration
                let seconds = CMTimeGetSeconds(duration)

                if !seconds.isNaN && !seconds.isInfinite {
                    DispatchQueue.main.async {
                        self?.totalDurationSeconds = seconds
                        self?.durationLabel.text = self?.formatDuration(seconds: seconds)
                    }
                }
            }
        }
    }

    private func formatDuration(seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func loadThumbnail(for videoUrl: URL, fallbackPreviewUrl: String?, attempt: Int) {
        if let previewString = fallbackPreviewUrl, let previewURL = URL(string: previewString) {
            // TODO: integrate ImageLoader to load preview image if needed
            _ = previewURL
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: videoUrl)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true

            let time = CMTime(seconds: 0.1, preferredTimescale: 600)

            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let image = UIImage(cgImage: cgImage)

                DispatchQueue.main.async { [weak self] in
                    self?.thumbnailImageView.image = image
                }
            } catch {
                if attempt < self.maxRetries {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.loadThumbnail(for: videoUrl, fallbackPreviewUrl: fallbackPreviewUrl, attempt: attempt + 1)
                    }
                }
            }
        }
    }

    private func hideShimmer() {
        shimmerContainer.stopShimmering()
        UIView.animate(withDuration: 0.3) {
            self.shimmerContainer.alpha = 0
        } completion: { _ in
            self.shimmerContainer.isHidden = true
        }
    }

    func play() {
        guard canAutoPlay else {
            return
        }

        guard let player = player, !isPlaying else { return }
        player.play()
        isPlaying = true
    }

    func pause() {
        guard let player = player, isPlaying else { return }
        player.pause()
        isPlaying = false
    }

    func stop() {
        guard let player = player else { return }
        player.pause()
        player.seek(to: .zero)
        isPlaying = false
        durationLabel.text = formatDuration(seconds: totalDurationSeconds)
    }

    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        player?.seek(to: .zero)
        player?.play()
    }

    private func cleanUpPlayerObservers() {
        playerItemStatusObservation?.invalidate()
        playerItemStatusObservation = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stop()
        cleanUpPlayerObservers()

        playerLayer.player = nil
        player = nil
        titleLabel.text = nil
        thumbnailImageView.image = nil
        canAutoPlay = false
        currentVideoUrl = nil
        totalDurationSeconds = 0

        durationContainer.isHidden = true
        durationLabel.text = ""

        shimmerContainer.layer.removeAllAnimations()
        shimmerContainer.alpha = 1.0
        shimmerContainer.isHidden = false
    }

    deinit {
        cleanUpPlayerObservers()
    }
}

