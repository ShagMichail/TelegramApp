import Foundation
import UIKit
import AVFoundation
import AVKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import PhotoResources

final class VideoGalleryCellNode: UICollectionViewCell {
    
    private let playerViewController = AVPlayerViewController()
    private let loadingSpinner = UIActivityIndicatorView(style: .large)
    private let muteBackground = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
    private let muteButton = UIButton(type: .system)
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?
    private var displayLink: CADisplayLink?

    private weak var nativeControlsView: UIView?


    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        startSyncingWithAppleControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        displayLink?.invalidate()
    }


    // MARK: - Override 
    
    override func prepareForReuse() {
        super.prepareForReuse()
        resetPlayer()
    }


    // MARK: - Internal

    func configure(with file: UserVideoFile) {
        resetPlayer()
        loadingSpinner.startAnimating()
        
        guard let urlString = file.fullUrl, let url = URL(string: urlString) else {
            loadingSpinner.stopAnimating()
            return
        }
        
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        player?.isMuted = false
        muteButton.setImage(UIImage(systemName: "speaker.wave.2.fill"), for: .normal)
        playerViewController.player = player
        
        statusObservation = playerItem?.observe(\.status, options:[.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                if item.status == .readyToPlay || item.status == .failed {
                    self?.loadingSpinner.stopAnimating()
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }
    
    func play() { player?.play() }
    func pause() { player?.pause() }
    

    // MARK: - Private
    
    private func setupViews() {
        self.backgroundColor = .black
        contentView.backgroundColor = .black
        
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        playerViewController.videoGravity = .resizeAspect
        playerViewController.showsPlaybackControls = true
        
        playerViewController.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
        contentView.addSubview(playerViewController.view)
        
        muteBackground.translatesAutoresizingMaskIntoConstraints = false
        muteBackground.layer.cornerRadius = 20
        muteBackground.clipsToBounds = true
        contentView.addSubview(muteBackground)
        
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.tintColor = .white
        muteButton.setImage(UIImage(systemName: "speaker.wave.2.fill"), for: .normal)
        muteButton.addTarget(self, action: #selector(toggleMute), for: .touchUpInside)
        muteBackground.contentView.addSubview(muteButton)
        
        loadingSpinner.color = .white
        loadingSpinner.hidesWhenStopped = true
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadingSpinner)
        
        NSLayoutConstraint.activate([
            playerViewController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            muteBackground.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            muteBackground.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 60),
            muteBackground.widthAnchor.constraint(equalToConstant: 40),
            muteBackground.heightAnchor.constraint(equalToConstant: 40),
            
            muteButton.centerXAnchor.constraint(equalTo: muteBackground.centerXAnchor),
            muteButton.centerYAnchor.constraint(equalTo: muteBackground.centerYAnchor),
            muteButton.widthAnchor.constraint(equalToConstant: 40),
            muteButton.heightAnchor.constraint(equalToConstant: 40),
            
            loadingSpinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    private func startSyncingWithAppleControls() {
        displayLink = CADisplayLink(target: self, selector: #selector(syncControlsVisibility))
        displayLink?.add(to: .main, forMode: .common)
    }

        private func getAppleControlsView() -> UIView? {
        if let cached = nativeControlsView, cached.superview != nil {
            return cached
        }
        guard let root = playerViewController.view else { return nil }
        nativeControlsView = recursiveSearchForControlsView(in: root)
        return nativeControlsView
    }
    
    private func recursiveSearchForControlsView(in view: UIView) -> UIView? {
        let className = String(describing: type(of: view))
        if className.contains("PlaybackControls") {
            return view
        }
        for subview in view.subviews {
            if let found = recursiveSearchForControlsView(in: subview) {
                return found
            }
        }
        return nil
    }

    private func resetPlayer() {
        statusObservation?.invalidate()
        statusObservation = nil
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        player?.pause()
        player = nil
        playerItem = nil
        playerViewController.player = nil
        loadingSpinner.stopAnimating()
        
        nativeControlsView = nil
        muteBackground.alpha = 1.0
        muteBackground.isHidden = false
    }
    

    // MARK: - @objc

    @objc private func syncControlsVisibility() {
        guard let controlsView = getAppleControlsView() else { return }
        let opacity = controlsView.layer.presentation()?.opacity ?? Float(controlsView.alpha)
        let targetAlpha = CGFloat(opacity)
        let isHidden = controlsView.isHidden || targetAlpha < 0.01
        
        if abs(muteBackground.alpha - targetAlpha) > 0.01 || muteBackground.isHidden != isHidden {
            muteBackground.alpha = targetAlpha
            muteBackground.isHidden = isHidden
        }
    }
    
    @objc private func toggleMute() {
        guard let player = player else { return }
        player.isMuted.toggle()
        let icon = player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        muteButton.setImage(UIImage(systemName: icon), for: .normal)
    }
}