import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import TelegramBaseController
import LegacyMediaPickerUI
import Postbox
import MapResourceToAvatarSizes
import ContextUI

public final class PublicProfileScreenController: TelegramBaseController {
    
    private var controllerNode: PublicProfileScreenNode {
        return self.displayNode as! PublicProfileScreenNode
    }
    
    private var customBackSwipeGestureRecognizer: UIScreenEdgePanGestureRecognizer?
    
    private let model: ProfileModel
    private var userProfileData: UserProfileData? = nil
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private let createWorkExperienceDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    
    private var navigationBarIsTransparent = true
    private let peer: Peer?
    
    private let contextSourceNode = ContextReferenceContentNode()
    
    public init(context: AccountContext, model: ProfileModel, peer: Peer? = nil) {
        self.context = context
        self.model = model
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.peer = peer
        let darkNavigationTheme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: .white,
            disabledButtonColor: UIColor(rgb: 0x525252),
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .clear,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)

        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))

        super.init(context: context, navigationBarPresentationData: navigationBarData)
        
        updateNavigation()
    }
    
    deinit {
        self.supportPeerDisposable.dispose()
        self.createWorkExperienceDisposable.dispose()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateNavigation() {
        self.statusBar.statusBarStyle = .White
        
        let moreButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Profile/MoreActionIcon"), color: .white)
        let moreButton = UIBarButtonItem(image: moreButtonImg, style: .plain, target: self, action: #selector(self.moreMenu))
        
        self.navigationItem.rightBarButtonItems = [moreButton]
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PublicProfileScreenNode(
            controller: self,
            context: self.context,
            presentationData: self.presentationData,
            model: model
        )
        
        // Hook interactions sheet callbacks
        self.controllerNode.onLikesTapped = { [weak self] in
            self?.presentInteractionSheet(type: .likes)
        }
        self.controllerNode.onViewsTapped = { [weak self] in
            self?.presentInteractionSheet(type: .views)
        }
        self.controllerNode.onSavesTapped = { [weak self] in
            self?.presentInteractionSheet(type: .saves)
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    private var galleryLoaded: Bool = false

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getUserProfile()
        getUserGalleryProfile()
    }

    private func getUserProfile() {
        guard let userId = model.userId else { return }
        Task {
            do {
                let response: UserDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/user/\(userId)"
                )
                await MainActor.run {
                    self.controllerNode.updateWithUserDetail(response.data)
                    // Загружаем связанное видео один раз вместе с профилем
                    self.loadVideoGalleryPage(userId: userId, offset: 0)
                }
            } catch {
                print("[DivoAPI] user/\(userId) error: \(error)")
            }
        }
    }

    private func getUserGalleryProfile() {
        guard let userId = model.userId else { return }
        guard !galleryLoaded else { return }
        galleryLoaded = true
        controllerNode.resetGalleryPagination()
        loadGalleryPage(userId: userId, offset: 0)
    }

    func loadGalleryPage(userId: Int, offset: Int) {
        print("📡 [GALLERY REQUEST] offset=\(offset), limit=6, userId=\(userId)")
        // Устанавливаем флаг загрузки перед запросом
        controllerNode.setGalleryLoading(true)
        Task {
            do {
                let response: UserGalleryResponse = try await DivoAPIClient.shared.request(
                    path: "/user-gallery/list",
                    method: "POST",
                    body: GalleryListRequest(offset: offset, limit: 6, userId: userId)
                )
                print("📥 [GALLERY RESPONSE] items=\(response.data.items.count), pagination.offset=\(response.data.pagination.meta.currentOffset), pagination.total=\(response.data.pagination.meta.totalCount)")
                await MainActor.run {
                    self.controllerNode.appendGalleryPhotos(response.data)
                }
            } catch {
                print("[DivoAPI] user/\(userId) error: \(error)")
                // Сбрасываем флаг при ошибке
                controllerNode.setGalleryLoading(false)
            }
        }
    }
    
    // Загрузка видео-галереи (упрощённая версия из dummy)
    func loadVideoGalleryPage(userId: Int, offset: Int) {
        print("🎬 [VIDEO REQUEST] offset=\(offset), limit=6, userId=\(userId)")
        Task {
            do {
                let response: UserVideoGalleryResponse = try await DivoAPIClient.shared.request(
                    path: "/publication/list",
                    method: "POST",
                    body: GalleryListRequest(offset: offset, limit: 6, userId: userId)
                )
                print("📥 [VIDEO RESPONSE] items=\(response.data.items.count)")
                await MainActor.run {
                    self.controllerNode.appendVideoGalleryItems(response.data.items)
                }
            } catch {
                print("[DivoAPI] user-videos error: \(error)")
            }
        }
    }
    
    @objc func moreMenu() {
        
    }
}

// MARK: - Interactions sheet (likes / views / saves)

extension PublicProfileScreenController {
    private func presentInteractionSheet(type: InteractionListType) {
        let sheetVC = InteractionListViewController(type: type)
        
        sheetVC.requestData = { [weak self, weak sheetVC] in
            self?.loadInteractionData(type: type) { users in
                sheetVC?.updateData(users)
            }
        }
        
        if #available(iOS 15.0, *) {
            if let sheet = sheetVC.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 24
            }
        }
        
        self.present(sheetVC, animated: true, completion: nil)
    }
    
    private func loadInteractionData(type: InteractionListType, completion: @escaping ([InteractionUser]) -> Void) {
        guard let userId = model.userId else { return }
        print("📡 [INTERACTIONS] Requesting data for \(type.title), userId: \(userId)")
        
        // Пока что используем мок-данные как в dummy.
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            let mockData = [
                InteractionUser(id: 1, name: "Kristina Reach", role: "Model", avatarUrl: nil, isPremium: true),
                InteractionUser(id: 2, name: "Vogue Inside", role: "Agency", avatarUrl: nil, isPremium: false),
                InteractionUser(id: 3, name: "Capsule Wardrobe", role: "Fan", avatarUrl: nil, isPremium: true),
                InteractionUser(id: 4, name: "Mode & Mood", role: "Model", avatarUrl: nil, isPremium: true),
                InteractionUser(id: 5, name: "Street Luxe", role: "New Talent", avatarUrl: nil, isPremium: false)
            ]
            
            DispatchQueue.main.async {
                completion(mockData)
            }
        }
    }
}
