import Foundation
import UIKit
import AVFoundation
import Display
import TelegramBaseController
import TelegramCore
import TelegramPresentationData
import AccountContext
import PhotoResources

public class ProfileGalleryController: TelegramBaseController {
    private var galleryNode: ProfileGalleryControllerNode {
        return self.displayNode as! ProfileGalleryControllerNode
    }
    private var presentationData: PresentationData
    private var photos: [UserPhoto]
    private var videos: [UserVideoItem]
    
    private let context: AccountContext
    private let initialIndex: Int
    private let isVideoGallery: Bool
    
    public var requestMoreData: (() -> Void)? {
        didSet {
            if self.isNodeLoaded {
                self.galleryNode.requestMoreData = requestMoreData
            }
        }
    }
    
    public init(
        context: AccountContext,
        photos: [UserPhoto] = [],
        videos: [UserVideoItem] = [],
        initialIndex: Int = 0,
        isVideoGallery: Bool = false
    ) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.photos = photos
        self.videos = videos
        self.initialIndex = initialIndex
        self.isVideoGallery = isVideoGallery
        
        let darkNavigationTheme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: .white,
            disabledButtonColor: UIColor(rgb: 0x525252),
            primaryTextColor: .white,
            backgroundColor: UIColor.black.withAlphaComponent(0.7),
            opaqueBackgroundColor: .black,
            enableBackgroundBlur: true,
            separatorColor: .clear,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear
        )
        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))
        
        super.init(context: context, navigationBarPresentationData: navigationBarData)
        
        self.statusBar.statusBarStyle = .White
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .all)
        
        let totalCount = isVideoGallery ? videos.count : photos.count
        self.title = "\(initialIndex + 1) of \(totalCount)"
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // При открытии галереи с видео переключаемся на .playback,
        // чтобы звук воспроизводился корректно через динамик.
        if isVideoGallery {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.galleryNode.pauseAllVideos()
        // Восстанавливаем .ambient чтобы после закрытия галереи
        // фоновая музыка других приложений возобновилась.
        if isVideoGallery {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ProfileGalleryControllerNode(
            context: self.context,
            presentationData: self.presentationData,
            photos: self.photos,
            videos: self.videos,
            initialIndex: self.initialIndex,
            isVideoGallery: self.isVideoGallery,
            controller: self
        )
        self.displayNode.backgroundColor = .black
        self.galleryNode.requestMoreData = self.requestMoreData
        
        self.galleryNode.onIndexChanged = { [weak self] index, total in
            self?.title = "\(index + 1) of \(total)"
        }
        
        self.displayNodeDidLoad()
    }
    
    public func updateData(photos: [UserPhoto], videos:[UserVideoItem]) {
        self.photos = photos
        self.videos = videos
        
        self.galleryNode.updateData(photos: photos, videos: videos)
        
        let totalCount = self.isVideoGallery ? videos.count : photos.count
        self.title = "\(self.galleryNode.currentIndex + 1) of \(totalCount)"
    }
    
    public func finishLoadingWithoutNewData() {
        self.galleryNode.finishLoadingWithoutNewData()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.galleryNode.containerLayoutUpdated(layout, transition: transition)
    }
}