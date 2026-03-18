import Foundation
import UIKit
import AVFoundation
import Display
import AsyncDisplayKit
import TelegramBaseController
import TelegramCore
import TelegramPresentationData
import AccountContext
import PhotoResources

// MARK: - Profile Gallery Controller

public class ProfileGalleryController: TelegramBaseController {

    private var galleryNode: ProfileGalleryControllerNode {
        return self.displayNode as! ProfileGalleryControllerNode
    }
    private var presentationData: PresentationData
    
    private let context: AccountContext
    private let photos: [UserPhoto]
    private let videos: [UserVideoItem]
    private let initialIndex: Int
    private let isVideoGallery: Bool
    

    // MARK: - Init

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


    // MARK: - Override

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.galleryNode.pauseAllVideos()
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
        
        self.galleryNode.onIndexChanged = { [weak self] index, total in
            self?.title = "\(index + 1) of \(total)"
        }
        
        self.displayNode.backgroundColor = .black
    
        self.galleryNode.onIndexChanged = {[weak self] index, total in
            self?.title = "\(index + 1) of \(total)"
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.galleryNode.containerLayoutUpdated(layout, transition: transition)
    }
}