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

public final class EventsController: TelegramBaseController {
    private var controllerNode: EventsControllerNode {
        return self.displayNode as! EventsControllerNode
    }

    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
//        getEvents()
        return self._ready
    }

    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    private let peerViewDisposable = MetaDisposable()

    private var isEmpty: Bool?
    private var hasLoadedOnce = false

    private let createActionDisposable = MetaDisposable()
    private let clearDisposable = MetaDisposable()

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let navTheme = NavigationBarTheme(overallDarkAppearance: true, buttonColor: .black, disabledButtonColor: UIColor(rgb: 0x525252), primaryTextColor: .white, backgroundColor: .clear, opaqueBackgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(theme: navTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))

        let icon: UIImage?
        icon = UIImage(bundleImageName: "Chat List/Tabs/IconEvents")
        self.tabBarItem.title = self.presentationData.strings.Events_TabTitle
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

        let copperColor = UIColor(rgb: 0xBF7A54)

        let searchIcon = generateTintedImage(image: PresentationResourcesRootController.navigationSearchIcon(self.presentationData.theme), color: copperColor)
        let searchButton = UIBarButtonItem(image: searchIcon?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(self.searchPressed))

        let addIcon = generateTintedImage(image: PresentationResourcesRootController.navigationAddIcon(self.presentationData.theme), color: copperColor)
        let addButton = UIBarButtonItem(image: addIcon?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(self.addPressed))

        self.navigationItem.rightBarButtonItems = [addButton, searchButton]

        self.navigationItem.titleView = UIView()
    }

    private var lastContentOffset: CGPoint = .zero

    public func updateContentOffset(offset: CGPoint) {
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !hasLoadedOnce {
            hasLoadedOnce = true
            getEvents()
        }
    }

    private func getEvents() {
        let body = EventListRequest(offset: 0, limit: 30)
        Task {
            do {
                let response: EventListResponse = try await DivoAPIClient.shared.request(
                    path: "/event/list",
                    method: "POST",
                    body: body
                )
                let items = response.data.items
                if !items.isEmpty {
                    let eventDataArray: [EventData] = items.map { item in
                        let dateString = item.date?.prefix(while: { $0 != "T" }).description ?? ""
                        let coverURL = item.files?.first?.fullUrl
                        let avatarURL = item.user?.avatar?.fullUrl
                        let cityName = item.address?.city?.title ?? ""
                        return EventData(
                            id: item.id,
                            title: item.title,
                            subtitle: item.type?.title ?? "",
                            profileName: "@" + (item.user?.fullName ?? ""),
                            timeRemaining: "4d : 4h : 0m",
                            type: item.type?.title ?? "",
                            coverPhotoURL: coverURL,
                            profilePhotoURL: avatarURL,
                            location: cityName,
                            eventDateFormatted: dateString
                        )
                    }
                    await MainActor.run {
                        self.controllerNode.reloadEvents(events: eventDataArray)
                    }
                    return
                }
            } catch {
                // API failed or empty — fall through to mocks
            }
            // Show mocks when API returns empty or fails
            await MainActor.run {
                self.controllerNode.reloadEvents(events: EventData.mockEvents())
            }
        }
    }

    @objc private func searchPressed() {
        let controller = EventsSearchController(context: context)

        if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
            navigationController.pushViewController(controller)
        }
    }

    @objc private func addPressed() {
        let controller = CreateEventController(context: context)

        if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
            navigationController.pushViewController(controller)
        }

        print("Add button pressed")
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.peerViewDisposable.dispose()
        self.clearDisposable.dispose()
        self.supportPeerDisposable.dispose()
    }

    override public func loadDisplayNode() {
        self.displayNode = EventsControllerNode(controller: self, context: self.context, presentationData: self.presentationData)
        self.displayNodeDidLoad()


//        self._ready.set(combineLatest(queue: .mainQueue(),
////            self.contactsNode.contactListNode.ready,
////            self.contactsNode.storiesReady.get()
//        )
//        |> filter { a, b in
//            return a && b
//        }
//        |> take(1)
//        |> map { _ -> Bool in true })
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
