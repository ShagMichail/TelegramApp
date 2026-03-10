import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import AppBundle
import LocalizedPeerData
import ContextUI
import TelegramBaseController
import ProfileScreenUI

public final class ModelsFeedController: TelegramBaseController {
    private var controllerNode: ModelsFeedNode {
        return self.displayNode as! ModelsFeedNode
    }

    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
        return self._ready
    }

    private let context: AccountContext

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    private let peerViewDisposable = MetaDisposable()

    private var isEmpty: Bool?

    private var feedlineOffset = 0
    private var isLoadingFeedline = false
    private var hasMoreFeedline = true
    private let feedlinePageSize = 10

    private let createActionDisposable = MetaDisposable()
    private let clearDisposable = MetaDisposable()

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let navTheme = NavigationBarTheme(overallDarkAppearance: true, buttonColor: .black, disabledButtonColor: UIColor(rgb: 0x525252), primaryTextColor: .white, backgroundColor: .clear, opaqueBackgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(theme: navTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))

        let icon: UIImage?
        icon = UIImage(bundleImageName: "Models/IconModels")
        self.tabBarItem.title = self.presentationData.strings.ModelsFeed_TabTitle
        self.tabBarItem.image = icon
        self.tabBarItem.selectedImage = icon

        updateNavigation()

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
            }
        }).strict()
    }

    private func updateNavigation() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style

        let searchButton = UIBarButtonItem(image: PresentationResourcesRootController.navigationSearchIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.searchPressed))

        self.navigationItem.rightBarButtonItems = [searchButton]

        let titleLabel = UILabel()
        titleLabel.text = self.presentationData.strings.ModelsFeed_TabTitle.uppercased()
        titleLabel.font = Font.helveticaNeue(34)
        titleLabel.textColor = self.presentationData.theme.rootController.navigationBar.primaryTextColor
        titleLabel.sizeToFit()

        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        containerView.addSubview(titleLabel)
        titleLabel.frame.origin.x = -10
        titleLabel.frame.origin.y = 10

        self.navigationItem.titleView = containerView
        self.navigationController?.hidesBarsOnSwipe = true
    }

    private var lastContentOffset: CGPoint = .zero

    public func updateContentOffset(offset: CGPoint) {
    }

    @objc private func searchPressed() {
//        let controller = EventsSearchController(context: context)
//
//        if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
//            navigationController.pushViewController(controller)
//        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func showProfile(_ model: CardModel) {
        let profileModel = ProfileModel(
            name: model.name,
            age: 0,
            location: "",
            mainImageName: model.mainImageName,
            avatarImageName: model.avatarImageName,
            isVerified: false,
            likesCount: "\(model.likesCount)",
            viewsCount: "0",
            savesCount: "0",
            biography: "",
            socialMediaHandles: [],
            galleryImageNames: [],
            galleryImageURLs: [],
            userId: model.userId,
            mainImageURL: model.mainImageURL,
            avatarImageURL: model.avatarImageURL
        )
        let detailController = PublicProfileScreenController(context: context, model: profileModel)
        if let nav = self.navigationController as? NavigationController {
            nav.pushViewController(detailController, animated: true)
        } else {
            (self.navigationController as? NavigationController)?.pushViewController(detailController, animated: true)
        }
    }

    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.peerViewDisposable.dispose()
        self.clearDisposable.dispose()
    }

    override public func loadDisplayNode() {
        self.displayNode = ModelsFeedNode(controller: self, context: self.context, presentationData: self.presentationData)
        self.controllerNode.showProfile = { [weak self] model in
            self?.showProfile(model)
        }
        self.controllerNode.loadMore = { [weak self] in
            self?.loadNextPage()
        }

        self.displayNodeDidLoad()
        loadFeedline(reset: true)
    }

    private func loadNextPage() {
        guard !isLoadingFeedline, hasMoreFeedline else { return }
        loadFeedline(reset: false)
    }

    private func loadFeedline(reset: Bool) {
        guard !isLoadingFeedline else { return }
        isLoadingFeedline = true
        if reset {
            controllerNode.isLoading = true
            controllerNode.isPaginating = false
        } else {
            controllerNode.isPaginating = true
        }

        if reset {
            feedlineOffset = 0
            hasMoreFeedline = true
        }

        let offset = feedlineOffset
        let limit = feedlinePageSize

        Task {
            do {
                let response: FeedlineResponse = try await DivoAPIClient.shared.request(
                    path: "/feedline/list",
                    method: "POST",
                    body: FeedlineListRequest(offset: offset, limit: limit)
                )
                let cards = response.data.items.map { Self.mapCard($0) }
                await MainActor.run {
                    if reset {
                        self.controllerNode.updateCards(cards)
                    } else {
                        self.controllerNode.appendCards(cards)
                    }
                    self.feedlineOffset = offset + cards.count
                    self.hasMoreFeedline = cards.count >= limit
                    self.isLoadingFeedline = false
                    self.controllerNode.isLoading = false
                    self.controllerNode.isPaginating = false
                }
            } catch {
                print("[DivoAPI] feedline/list error: \(error)")
                await MainActor.run {
                    self.isLoadingFeedline = false
                    self.controllerNode.isLoading = false
                    self.controllerNode.isPaginating = false
                }
            }
        }
    }

    private static func mapCard(_ item: FeedlineItem) -> CardModel {
        let mainURL = item.files.first.flatMap { URL(string: $0.fullUrl) }
        let avatarURL = item.searchImage.flatMap { URL(string: $0.fullUrl) }
        let previewURLs = item.files.dropFirst().compactMap { URL(string: $0.fullUrl) }
        return CardModel(
            name: item.title,
            userId: item.user.id,
            mainImageURL: mainURL,
            avatarImageURL: avatarURL,
            previewImageURLs: previewURLs,
            likesCount: item.likesCount,
            isFavorite: item.isFavoriteByUser
        )
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
