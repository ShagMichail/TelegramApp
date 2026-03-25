// import Foundation
// import UIKit
// import AVFoundation
// import Display
// import TelegramBaseController
// import TelegramCore
// import TelegramPresentationData
// import AccountContext
// import PhotoResources

// public class ProfileGalleryController: TelegramBaseController {
//     private var galleryNode: ProfileGalleryControllerNode {
//         return self.displayNode as! ProfileGalleryControllerNode
//     }
//     private var presentationData: PresentationData
//     private var photos: [UserPhoto]
//     private var videos: [UserVideoItem]

//     private let context: AccountContext
//     private let initialIndex: Int
//     private let isVideoGallery: Bool
//     private let isOwnProfile: Bool

//     public var requestMoreData: (() -> Void)? {
//         didSet {
//             if self.isNodeLoaded {
//                 self.galleryNode.requestMoreData = requestMoreData
//             }
//         }
//     }
    
//     public var onDeletePublication: ((Int) -> Void)?

//     public init(
//         context: AccountContext,
//         photos: [UserPhoto] = [],
//         videos: [UserVideoItem] = [],
//         initialIndex: Int = 0,
//         isVideoGallery: Bool = false,
//         isOwnProfile: Bool = false
//     ) {
//         self.context = context
//         self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
//         self.photos = photos
//         self.videos = videos
//         self.initialIndex = initialIndex
//         self.isVideoGallery = isVideoGallery
//         self.isOwnProfile = isOwnProfile

//         let darkNavigationTheme = NavigationBarTheme(
//             overallDarkAppearance: true,
//             buttonColor: .white,
//             disabledButtonColor: UIColor(rgb: 0x525252),
//             primaryTextColor: .white,
//             backgroundColor: UIColor.black.withAlphaComponent(0.7),
//             opaqueBackgroundColor: .black,
//             enableBackgroundBlur: true,
//             separatorColor: .clear,
//             badgeBackgroundColor: .clear,
//             badgeStrokeColor: .clear,
//             badgeTextColor: .clear
//         )
//         let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))

//         super.init(context: context, navigationBarPresentationData: navigationBarData)

//         self.statusBar.statusBarStyle = .White
//         self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .all)

//         let totalCount = isVideoGallery ? videos.count : photos.count
//         self.title = "\(initialIndex + 1) of \(totalCount)"

//         if isOwnProfile {
//             let editButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Profile/MoreActionIcon"), color: .white)
//             let editButton = UIBarButtonItem(image: editButtonImg, style: .plain, target: self, action: #selector(self.editMenu))
//             self.navigationItem.rightBarButtonItem = editButton
//         }
//     }
    
//     required public init(coder aDecoder: NSCoder) {
//         fatalError("init(coder:) has not been implemented")
//     }
    
//     override public func viewWillAppear(_ animated: Bool) {
//         super.viewWillAppear(animated)
//         if isVideoGallery {
//             try? AVAudioSession.sharedInstance().setCategory(.playback)
//             try? AVAudioSession.sharedInstance().setActive(true)
//         }
//     }

//     override public func viewWillDisappear(_ animated: Bool) {
//         super.viewWillDisappear(animated)
//         self.galleryNode.pauseAllVideos()
//         if isVideoGallery {
//             try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
//             try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
//         }
//     }
    
//     override public func loadDisplayNode() {
//         self.displayNode = ProfileGalleryControllerNode(
//             context: self.context,
//             presentationData: self.presentationData,
//             photos: self.photos,
//             videos: self.videos,
//             initialIndex: self.initialIndex,
//             isVideoGallery: self.isVideoGallery,
//             isOwnProfile: self.isOwnProfile,
//             controller: self
//         )
//         self.displayNode.backgroundColor = .black
//         self.galleryNode.requestMoreData = self.requestMoreData

//         self.galleryNode.onIndexChanged = { [weak self] index, total in
//             self?.title = "\(index + 1) of \(total)"
//         }

//         self.displayNodeDidLoad()
//     }

//     @objc func editMenu() {
//         guard let publicationId = self.galleryNode.getCurrentPublicationId() else { return }
//         let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
//         let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
//             self?.performDeletePublication(id: publicationId)
//         }
        
//         let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
//         actionSheet.addAction(deleteAction)
//         actionSheet.addAction(cancelAction)
        
//         if let popoverController = actionSheet.popoverPresentationController {
//             popoverController.barButtonItem = self.navigationItem.rightBarButtonItem
//         }
        
//         self.present(actionSheet, animated: true, completion: nil)
//     }
    
//     private func performDeletePublication(id: Int) {
//         Task { @MainActor in
//             do {
//                 // Запрос к API
//                 let response: DeletePublicationResponse = try await DivoAPIClient.shared.request(
//                     path: "/user-gallery/\(id)",
//                     method: "DELETE"
//                 )
                
//                 if response.errors == nil {
//                     self.onDeletePublication?(id)
                    
//                     self.galleryNode.removePublication(withId: id)
                    
//                     if self.isVideoGallery {
//                         self.videos.removeAll { $0.id == id }
//                     } else {
//                         self.photos.removeAll { $0.id == id }
//                     }
                    
//                     let totalCount = self.isVideoGallery ? self.videos.count : self.photos.count
//                     if totalCount > 0 {
//                         let currentIndex = min(self.galleryNode.currentIndex, totalCount - 1)
//                         self.title = "\(currentIndex + 1) of \(totalCount)"
//                     } else {
//                         if let nav = self.navigationController as? NavigationController {
//                             _ = nav.popViewController(animated: true)
//                         } else {
//                             self.dismiss()
//                         }
//                     }
//                 } else {
//                     self.showAlert(text: response.errors?.first ?? "Failed to delete")
//                 }
//             } catch {
//                 print("❌ Error deleting publication: \(error)")
//                 self.showAlert(text: error.localizedDescription)
//             }
//         }
//     }
    
//     private func showAlert(text: String) {
//         let alert = UIAlertController(title: "Error", message: text, preferredStyle: .alert)
//         alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
//         self.present(alert, animated: true)
//     }
    
//     public func updateData(photos: [UserPhoto], videos:[UserVideoItem]) {
//         self.photos = photos
//         self.videos = videos
        
//         self.galleryNode.updateData(photos: photos, videos: videos)
        
//         let totalCount = self.isVideoGallery ? videos.count : photos.count
//         self.title = "\(self.galleryNode.currentIndex + 1) of \(totalCount)"
//     }
    
//     public func finishLoadingWithoutNewData() {
//         self.galleryNode.finishLoadingWithoutNewData()
//     }
    
//     override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
//         super.containerLayoutUpdated(layout, transition: transition)
//         self.galleryNode.containerLayoutUpdated(layout, transition: transition)
//     }
// }



import Foundation
import UIKit
import AVFoundation
import Display
import TelegramBaseController
import TelegramCore
import TelegramPresentationData
import AccountContext

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
    private let isOwnProfile: Bool
    
    public var requestMoreData: (() -> Void)? {
        didSet {
            if self.isNodeLoaded {
                self.galleryNode.requestMoreData = requestMoreData
            }
        }
    }
    
    public var onDeletePublication: ((Int) -> Void)?
    
    public init(
        context: AccountContext,
        photos: [UserPhoto] = [],
        videos: [UserVideoItem] = [],
        initialIndex: Int = 0,
        isVideoGallery: Bool = false,
        isOwnProfile: Bool = false
    ) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.photos = photos
        self.videos = videos
        self.initialIndex = initialIndex
        self.isVideoGallery = isVideoGallery
        self.isOwnProfile = isOwnProfile
        
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
        
        if isOwnProfile {
            let editButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Profile/MoreActionIcon"), color: .white)
            let editButton = UIBarButtonItem(image: editButtonImg, style: .plain, target: self, action: #selector(self.editMenu))
            self.navigationItem.rightBarButtonItem = editButton
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isVideoGallery {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.galleryNode.pauseAllVideos()
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
            isOwnProfile: self.isOwnProfile,
            controller: self
        )
        self.displayNode.backgroundColor = .black
        self.galleryNode.requestMoreData = self.requestMoreData
        
        self.galleryNode.onIndexChanged = { [weak self] index, total in
            self?.title = "\(index + 1) of \(total)"
        }
        
        self.displayNodeDidLoad()
    }
    
    @objc func editMenu() {
        guard let publicationId = self.galleryNode.getCurrentPublicationId() else { return }
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeletePublication(id: publicationId)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        actionSheet.addAction(deleteAction)
        actionSheet.addAction(cancelAction)
        
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.barButtonItem = self.navigationItem.rightBarButtonItem
        }
        
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    private func performDeletePublication(id: Int) {
        Task { @MainActor in
            do {
                var path = ""
                if self.isVideoGallery {
                    path = "/publication/\(id)"
                } else {
                    path = "/user-gallery/\(id)"
                }
                
                let response: DeletePublicationResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "DELETE"
                )
                
                if response.errors == nil {
                    self.onDeletePublication?(id)
                    
                    self.galleryNode.removePublication(withId: id)
                    
                    if self.isVideoGallery {
                        self.videos.removeAll { $0.id == id }
                    } else {
                        self.photos.removeAll { $0.id == id }
                    }
                    
                    let totalCount = self.isVideoGallery ? self.videos.count : self.photos.count
                    if totalCount > 0 {
                        let currentIndex = min(self.galleryNode.currentIndex, totalCount - 1)
                        self.title = "\(currentIndex + 1) of \(totalCount)"
                    } else {
                        if let nav = self.navigationController as? NavigationController {
                            _ = nav.popViewController(animated: true)
                        } else {
                            self.dismiss()
                        }
                    }
                } else {
                    self.showAlert(text: response.errors?.first ?? "Failed to delete")
                }
            } catch {
                print("❌ Error deleting publication: \(error)")
                self.showAlert(text: error.localizedDescription)
            }
        }
    }
    
    private func showAlert(text: String) {
        let alert = UIAlertController(title: "Error", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true)
    }
    
    public func updateData(photos: [UserPhoto], videos: [UserVideoItem]) {
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
