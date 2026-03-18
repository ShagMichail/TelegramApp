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
import GalleryUI

public final class PublicProfileScreenController: TelegramBaseController {

    private func debugLog(_ message: String) {
        #if DEBUG
        Logger.shared.log("PublicProfile", message)
        #endif
    }
    
    private var controllerNode: PublicProfileScreenNode {
        return self.displayNode as! PublicProfileScreenNode
    }
    
    private var customBackSwipeGestureRecognizer: UIScreenEdgePanGestureRecognizer?
    
    private let model: ProfileModel
    private var userDetailModel: UserDetail? = nil
    private var userProfileData: UserProfileData? = nil
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private let createWorkExperienceDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    
    private var navigationBarIsTransparent = true
    private let peer: Peer?
    
    private let contextSourceNode = ContextReferenceContentNode()
    
    private var galleryLoaded: Bool = false
    private var profileLoaded: Bool = false

    private var containerLayout: (ContainerViewLayout, CGFloat)?

    // для разработки
    private var isMyProfile: Bool = false
    
    internal var currentGalleryPhotos: [UserPhoto] = []
    internal var currentGalleryVideos: [UserVideoItem] = []
    
    internal func clearGalleryData() {
        currentGalleryPhotos = []
        currentGalleryVideos = []
    }
    
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
            badgeTextColor: .clear
        )
        
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

        if isMyProfile {
            let editButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Profile/EditActionIcon"), color: .white)
            
            let editButton = UIBarButtonItem(
                image: editButtonImg,
                style: .plain,
                target: self,
                action: #selector(self.showEditMenuPressed)
            )
            
            self.navigationItem.rightBarButtonItems = [editButton, moreButton]
        } else {
            self.navigationItem.rightBarButtonItems = [moreButton]
        }
    }
    
    @objc private func showEditMenuPressed() {
        // debug: removed
        
        let items: [EditMenuViewController.MenuItem] = [
            .init(title: "Edit Profile", action: { [weak self] in
                self?.navigateToEditProfile()
            }),
            .init(title: "Change Profile Background", action: { [weak self] in
                self?.navigateToChangeBackground()
            }),
            .init(title: "Edit Social Links", action: { [weak self] in
                self?.navigateToEditSocialLinks()
            }),
            .init(title: "Manage Work Experience", action: { [weak self] in
                self?.navigateToManageExperience()
            })
        ]
        
        var sourcePoint = CGPoint(x: UIScreen.main.bounds.width - 20, y: 90)
        
        if let (_, navigationBarHeight) = self.containerLayout {
            sourcePoint.y = navigationBarHeight
        }
        
        let menuVC = EditMenuViewController(items: items, sourcePoint: sourcePoint)
        
        self.present(menuVC, animated: false, completion: nil)
    }

    private func navigateToEditProfile() {
        // debug: removed
        let socialLinksController = EditProfileController(context: self.context, presentationData: self.presentationData, userDetailData: userDetailModel, updatePhoto: { [weak self] image in
            self?.controllerNode.currentPhoto = image
        })
        self.push(socialLinksController)
    }
    
    private func navigateToChangeBackground() {
        // debug: removed
        // Открытие пикера или контроллера
    }
    
    private func navigateToEditSocialLinks() {
        let socialLinksController = EditSocialLinksController(context: self.context, presentationData: self.presentationData, userDetailData: userDetailModel)
        self.push(socialLinksController)
    }
    
    private func navigateToManageExperience() {
        let historyController = WorkExperienceController(context: self.context, model: self.model)
        self.push(historyController)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PublicProfileScreenNode(
            controller: self,
            context: self.context,
            presentationData: self.presentationData,
            model: model
        )

        self.controllerNode.onLikesTapped = {[weak self] in
            self?.presentInteractionSheet(type: .likes)
        }

        self.controllerNode.onViewsTapped = { [weak self] in
            self?.presentInteractionSheet(type: .views)
        }

        self.controllerNode.onSavesTapped = {[weak self] in
            self?.presentInteractionSheet(type: .saves)
        }

        self.controllerNode.onGalleryItemTapped = { [weak self] tabIndex, itemIndex in
            self?.openFullScreenGallery(tabIndex: tabIndex, itemIndex: itemIndex)
        }

        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.containerLayout = (layout, self.navigationLayout(layout: layout).navigationFrame.maxY)
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getUserProfile()
        getUserGalleryProfile()
    }
    
    private func getUserProfile() {
        guard let userId = model.userId else { return }
        Task {
            do {
                guard !profileLoaded else { return }
                profileLoaded = true
                var requestPath: String
                if !isMyProfile {
                    requestPath = model.isMyProfile ? "/user/info" : "/user/\(userId)"
                } else {
                    // для тестов модели 31999
                    requestPath = isMyProfile ? "/user/info" : "/user/\(userId)"
                }
                let response: UserDetailResponse = try await DivoAPIClient.shared.request(
                    path: requestPath
                )
                await MainActor.run {
                    self.userDetailModel = response.data
                    if !isMyProfile {
                        self.controllerNode.updateWithUserDetail(response.data, self.model.isMyProfile)
                    } else {
                        // для тестов модели 31999
                        self.controllerNode.updateWithUserDetail(response.data, self.isMyProfile)
                    }
                }
            } catch {
                self.debugLog("[DivoAPI] user/\(userId) error: \(error)")
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
    
    @objc func moreMenu() {

    }
}

// Загрузка фотографий
extension PublicProfileScreenController {
    func loadGalleryPage(userId: Int, offset: Int) {
        // Устанавливаем флаг загрузки перед запросом
        controllerNode.setGalleryLoading(true)

        var body: GalleryListRequest
        if !isMyProfile {
            body = GalleryListRequest(offset: offset, limit: 6, userId: userId)
        } else {
            // для тестов модели 31999
            body = GalleryListRequest(offset: offset, limit: 6, userId: 31999)
        }

        Task {
            do {
                let response: UserGalleryResponse = try await DivoAPIClient.shared.request(
                    path: "/user-gallery/list",
                    method: "POST",
                    body: body
                )
                await MainActor.run {
                    if !isMyProfile {
                        self.controllerNode.appendGalleryPhotos(response.data, isMyProfile: model.isMyProfile)
                        self.currentGalleryPhotos.append(contentsOf: response.data.items)
                    } else {
                        // для тестов своего профиля
                        self.controllerNode.appendGalleryPhotos(response.data, isMyProfile: isMyProfile)
                        self.currentGalleryPhotos.append(contentsOf: response.data.items)
                    }
                }
            } catch {
                self.debugLog("[DivoAPI] user/\(userId) error: \(error)")
                // Сбрасываем флаг при ошибке
                controllerNode.setGalleryLoading(false)
            }
        }
    }
    
    // Открытие галереи на полный экран
    private func openFullScreenGallery(tabIndex: Int, itemIndex: Int) {
        print("🖼️ [GALLERY] Opening full-screen gallery, tabIndex=\(tabIndex), itemIndex=\(itemIndex)")
        
        guard itemIndex >= 0 else {
            print("⚠️ [GALLERY] Invalid itemIndex: \(itemIndex)")
            return
        }
        
        let galleryController: ProfileGalleryController
        
        if tabIndex == 0 {
            // Photos tab
            guard !currentGalleryPhotos.isEmpty else {
                print("⚠️ [GALLERY] No photos to display")
                return
            }
            guard itemIndex < currentGalleryPhotos.count else {
                print("⚠️ [GALLERY] itemIndex \(itemIndex) out of range (photos: \(currentGalleryPhotos.count))")
                return
            }
            print("📸 [GALLERY] Opening photo gallery with \(currentGalleryPhotos.count) photos, initial index: \(itemIndex)")
            galleryController = ProfileGalleryController(
                context: self.context,
                photos: currentGalleryPhotos,
                initialIndex: itemIndex,
                isVideoGallery: false
            )
        } else if tabIndex == 1 {
            // Videos tab
            guard !currentGalleryVideos.isEmpty else {
                print("⚠️ [GALLERY] No videos to display")
                return
            }
            guard itemIndex < currentGalleryVideos.count else {
                print("⚠️ [GALLERY] itemIndex \(itemIndex) out of range (videos: \(currentGalleryVideos.count))")
                return
            }
            print("🎬 [GALLERY] Opening video gallery with \(currentGalleryVideos.count) videos, initial index: \(itemIndex)")
            galleryController = ProfileGalleryController(
                context: self.context,
                videos: currentGalleryVideos,
                initialIndex: itemIndex,
                isVideoGallery: true
            )
        } else {
            print("⚠️ [GALLERY] Invalid tabIndex: \(tabIndex)")
            return
        }
        
        self.push(galleryController)
        print("✅ [GALLERY] Gallery controller pushed")
    }
}

// Загрузка видео
extension PublicProfileScreenController {
    func loadVideoGalleryPage(userId: Int, offset: Int) {
        // Важно: выставляем флаг загрузки синхронно ДО старта async Task.
        // Иначе при быстром скролле может уйти второй запрос с тем же offset.
        controllerNode.setVideoGalleryLoading(true)
        var body: GalleryListRequest
        if !isMyProfile {
            body = GalleryListRequest(offset: offset, limit: 6, userId: userId)
        } else {
            // для тестов модели 31999
            body = GalleryListRequest(offset: offset, limit: 6, userId: 31999)
        }
        Task {
            do {
                let response: UserVideoGalleryResponse = try await DivoAPIClient.shared.request(
                    path: "/publication/list",
                    method: "POST",
                    body: body
                )
                print("📥 [VIDEO RESPONSE] items=\(response.data.items.count), offset=\(response.data.pagination.meta.currentOffset), total=\(response.data.pagination.meta.totalCount)")

                await MainActor.run {
                    let validVideoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "webm"]
                    
                    let videoItems: [UserVideoItem] = response.data.items.filter { item in
                        guard let firstFile = item.files.first,
                              let ext = firstFile.fileExtension?.lowercased() else {
                            return false
                        }
                        return validVideoExtensions.contains(ext)
                    }
                    
                    if !isMyProfile {
                        self.controllerNode.appendVideoGalleryItems(
                            response.data.items,
                            pagination: response.data.pagination.meta,
                            isMyProfile: model.isMyProfile
                        )
                        self.currentGalleryVideos.append(contentsOf: videoItems)
                    } else {
                        // для тестов своего профиля
                        self.controllerNode.appendVideoGalleryItems(
                            response.data.items,
                            pagination: response.data.pagination.meta,
                            isMyProfile: isMyProfile
                        )
                        self.currentGalleryVideos.append(contentsOf: videoItems)
                    }
                    
                    print("🎬 [VIDEO] Stored \(videoItems.count) video items (filtered from \(response.data.items.count) total)")
                }
            } catch {
                self.debugLog("[DivoAPI] user-videos error: \(error)")
                await MainActor.run {
                    controllerNode.videoGalleryRequestDidFail(offset: offset)
                    controllerNode.setVideoGalleryLoading(false)
                }
            }
        }
    }
}

// Загрузка каналов телеграмма
extension PublicProfileScreenController {
    func loadTelegramChannels() {
        guard let userId = model.userId else {
            debugLog("❌ [CHANNELS] userId is nil")
            return
        }

        debugLog("📢 [CHANNELS] Starting load for userId: \(userId)")

        let mockChannels: [ProfileChannelItem] = [
            ProfileChannelItem(
                peer: "vogue",
                title: "Vogue",
                followersCount: 1250000,
                isPremium: true,
                customAvatarURL: nil
            ),
            ProfileChannelItem(
                peer: "model_agency_nyc",
                title: "Model Agency NYC",
                followersCount: 85000,
                isPremium: false,
                customAvatarURL: nil
            ),
            ProfileChannelItem(
                peer: "fashionweek",
                title: "Fashion Week",
                followersCount: 2300000,
                isPremium: true,
                customAvatarURL: nil
            ),
            ProfileChannelItem(
                peer: "photography_daily",
                title: "Photography Daily",
                followersCount: 450000,
                isPremium: false,
                customAvatarURL: nil
            ),
            ProfileChannelItem(
                peer: "style_beauty",
                title: "Style & Beauty",
                followersCount: 670000,
                isPremium: true,
                customAvatarURL: nil
            ),
            ProfileChannelItem(
                peer: "style_beauty",
                title: "Style & Beauty",
                followersCount: 670000,
                isPremium: true,
                customAvatarURL: nil
            ),
            ProfileChannelItem(
                peer: "style_beauty",
                title: "Style & Beauty",
                followersCount: 670000,
                isPremium: true,
                customAvatarURL: nil
            ),
            ProfileChannelItem(
                peer: "style_beauty",
                title: "Style & Beauty",
                followersCount: 670000,
                isPremium: true,
                customAvatarURL: nil
            ),
            ProfileChannelItem(
                peer: "style_beauty",
                title: "Style & Beauty",
                followersCount: 670000,
                isPremium: true,
                customAvatarURL: nil
            ),
            ProfileChannelItem(
                peer: "style_beauty",
                title: "Style & Beauty",
                followersCount: 670000,
                isPremium: true,
                customAvatarURL: nil
            ),
            ProfileChannelItem(
                peer: "style_beauty",
                title: "Style & Beauty",
                followersCount: 670000,
                isPremium: true,
                customAvatarURL: nil
            ),
            ProfileChannelItem(
                peer: "style_beauty",
                title: "Style & Beauty",
                followersCount: 670000,
                isPremium: true,
                customAvatarURL: nil
            )
        ]
        
        debugLog("📢 [CHANNELS] Created \(mockChannels.count) mock channels")
        
        DispatchQueue.main.async { [weak self] in
            self?.debugLog("📢 [CHANNELS] Calling updateChannelsList with \(mockChannels.count) items")
            self?.controllerNode.updateChannelsList(mockChannels)
        }
    }
}

// Загрузка моделей, состоящих в агенстве
extension PublicProfileScreenController {
    func loadModels() {
        guard let userId = model.userId else {
            debugLog("❌ [MODELS] userId is nil")
            return
        }

        debugLog("📢 [MODELS] Starting load for userId: \(userId)")

        let mockModels: [ModelItem] = [
            ModelItem(
                name: "Vogue",
                role: "Model",
                isPremium: true,
                customAvatarURL: nil,
                localAvatarName: "Models/image5"
            ),
            ModelItem(
                name: "Vogue",
                role: "Model",
                isPremium: true,
                customAvatarURL: nil,
                localAvatarName: "Models/image5"
            ),
            ModelItem(
                name: "Vogue",
                role: "Model",
                isPremium: false,
                customAvatarURL: nil,
                localAvatarName: "Models/image5"
            ),
            ModelItem(
                name: "Vogue",
                role: "Model",
                isPremium: false,
                customAvatarURL: nil,
                localAvatarName: "Models/image5"
            ),
            ModelItem(
                name: "Vogue",
                role: "Model",
                isPremium: false,
                customAvatarURL: nil,
                localAvatarName: "Models/image5"
            ),
            ModelItem(
                name: "Vogue",
                role: "Model",
                isPremium: true,
                customAvatarURL: nil,
                localAvatarName: "Models/image5"
            ),
            ModelItem(
                name: "Vogue",
                role: "Model",
                isPremium: true,
                customAvatarURL: nil,
                localAvatarName: "Models/image5"
            ),
            ModelItem(
                name: "Vogue",
                role: "Model",
                isPremium: true,
                customAvatarURL: nil,
                localAvatarName: "Models/image5"
            ),
            ModelItem(
                name: "Vogue",
                role: "Model",
                isPremium: false,
                customAvatarURL: nil,
                localAvatarName: "Models/image5"
            ),
            ModelItem(
                name: "Vogue",
                role: "Model",
                isPremium: false,
                customAvatarURL: nil,
                localAvatarName: "Models/image5"
            ),
            ModelItem(
                name: "Vogue",
                role: "Model",
                isPremium: true,
                customAvatarURL: nil,
                localAvatarName: "Models/image5"
            ),
            ModelItem(
                name: "Vogue",
                role: "Model",
                isPremium: false,
                customAvatarURL: nil,
                localAvatarName: "Models/image5"
            )
        ]
        
        debugLog("📢 [MODELS] Created \(mockModels.count) mock models")
        
        DispatchQueue.main.async { [weak self] in
            self?.debugLog("📢 [MODELS] Calling updateModelsList with \(mockModels.count) items")
            self?.controllerNode.updateModelsList(mockModels)
        }
    }
}

// Загрузка событий
extension PublicProfileScreenController {
    func loadEvents() {
        guard let userId = model.userId else {
            debugLog("❌ [EVENTS] userId is nil")
            return
        }

        debugLog("📢 [EVENTS] Starting load for userId: \(userId)")

        let mockEvents: [EventItem] = [
            EventItem(
                name: "EventItem",
                data: "June 24",
                time: "5:00 PM",
                countryFlag: "🇺🇸",
                city: "New York",
                customAvatarURL: nil
            ),
            EventItem(
                name: "EventItem",
                data: "June 24",
                time: "5:00 PM",
                countryFlag: "🇺🇸",
                city: "New York",
                customAvatarURL: nil
            ),
            EventItem(
                name: "EventItem",
                data: "June 24",
                time: "5:00 PM",
                countryFlag: "🇺🇸",
                city: "New York",
                customAvatarURL: nil
            ),
            EventItem(
                name: "EventItem",
                data: "June 24",
                time: "5:00 PM",
                countryFlag: "🇺🇸",
                city: "New York",
                customAvatarURL: nil
            ),
            EventItem(
                name: "EventItem",
                data: "June 24",
                time: "5:00 PM",
                countryFlag: "🇺🇸",
                city: "New York",
                customAvatarURL: nil
            ),
            EventItem(
                name: "EventItem",
                data: "June 24",
                time: "5:00 PM",
                countryFlag: "🇺🇸",
                city: "New York",
                customAvatarURL: nil
            ),
            EventItem(
                name: "EventItem",
                data: "June 24",
                time: "5:00 PM",
                countryFlag: "🇺🇸",
                city: "New York",
                customAvatarURL: nil
            ),
            EventItem(
                name: "EventItem",
                data: "June 24",
                time: "5:00 PM",
                countryFlag: "🇺🇸",
                city: "New York",
                customAvatarURL: nil
            ),
            EventItem(
                name: "EventItem",
                data: "June 24",
                time: "5:00 PM",
                countryFlag: "🇺🇸",
                city: "New York",
                customAvatarURL: nil
            ),
            EventItem(
                name: "EventItem",
                data: "June 24",
                time: "5:00 PM",
                countryFlag: "🇺🇸",
                city: "New York",
                customAvatarURL: nil
            ),
            EventItem(
                name: "EventItem",
                data: "June 24",
                time: "5:00 PM",
                countryFlag: "🇺🇸",
                city: "New York",
                customAvatarURL: nil
            ),
            EventItem(
                name: "EventItem",
                data: "June 24",
                time: "5:00 PM",
                countryFlag: "🇺🇸",
                city: "New York",
                customAvatarURL: nil
            )
        ]
        
        debugLog("📢 [EVENTS] Created \(mockEvents.count) mock events")
        
        DispatchQueue.main.async { [weak self] in
            self?.debugLog("📢 [EVENTS] Calling updateEventsList with \(mockEvents.count) items")
            self?.controllerNode.updateEventsList(mockEvents)
        }
    }
}

// Загрузка лайков, просмотров и созраненок
extension PublicProfileScreenController {
    
    private func presentInteractionSheet(type: InteractionListType) {
        let sheetVC = InteractionListViewController(type: type)
        
        // Настраиваем, откуда шторка будет брать данные
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
        } else {

        }
        
        self.present(sheetVC, animated: true, completion: nil)
    }
    
    private func loadInteractionData(type: InteractionListType, completion: @escaping ([InteractionUser]) -> Void) {
        guard let userId = model.userId else { return }

        debugLog("📡 [INTERACTIONS] Requesting data for \(type.title), userId: \(userId)")
        
        // TODO: Здесь будет сетевой запрос. Например:
        // let path = (type == .likes) ? "/user/likes" : "/user/views"
        // let response = try await DivoAPIClient.shared.request(...)
        
        // Имитация сетевой задержки в 1 секунду
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            
            // Мок-данные. Вы можете сделать разные массивы для лайков и просмотров.
            let mockData = [
                InteractionUser(id: 1, name: "Kristina Reach", role: "Model", avatarUrl: nil, isPremium: true),
                InteractionUser(id: 2, name: "Vogue Inside", role: "Agency", avatarUrl: nil, isPremium: false),
                InteractionUser(id: 3, name: "Capsule Wardrobe", role: "Fan", avatarUrl: nil, isPremium: true),
                InteractionUser(id: 4, name: "Mode & Mood", role: "Model", avatarUrl: nil, isPremium: true),
                InteractionUser(id: 5, name: "Street Luxe", role: "New Talent", avatarUrl: nil, isPremium: false),
                InteractionUser(id: 6, name: "Trend Lab", role: "Model", avatarUrl: nil, isPremium: false),
                InteractionUser(id: 7, name: "Haute Daily", role: "Agency", avatarUrl: nil, isPremium: false)
            ]
            
            self.debugLog("📥 [INTERACTIONS] Loaded \(mockData.count) users for \(type.title)")
            
            // Возвращаем данные в контроллер шторки на главный поток
            DispatchQueue.main.async {
                completion(mockData)
            }
        }
    }
}
