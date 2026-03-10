import Foundation
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

final class ModelsFeedNode: ASDisplayNode, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, CardCellDelegate {
    private final class PaginationShimmerCell: UICollectionViewCell {
        private let cardShimmer = ShimmerView()
        private let avatarShimmer = ShimmerView()
        private let nameLine1 = ShimmerView()
        private let nameLine2 = ShimmerView()
        private let actionLine = ShimmerView()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .white

            cardShimmer.layer.cornerRadius = 0
            addSubview(cardShimmer)

            avatarShimmer.layer.cornerRadius = 35
            avatarShimmer.layer.masksToBounds = true
            addSubview(avatarShimmer)

            nameLine1.layer.cornerRadius = 6
            nameLine1.layer.masksToBounds = true
            addSubview(nameLine1)

            nameLine2.layer.cornerRadius = 6
            nameLine2.layer.masksToBounds = true
            addSubview(nameLine2)

            actionLine.layer.cornerRadius = 10
            actionLine.layer.masksToBounds = true
            addSubview(actionLine)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let w = bounds.width
            let h = bounds.height
            cardShimmer.frame = bounds
            avatarShimmer.frame = CGRect(x: 15, y: h - 200, width: 70, height: 70)
            nameLine1.frame = CGRect(x: 95, y: h - 195, width: w * 0.45, height: 18)
            nameLine2.frame = CGRect(x: 95, y: h - 170, width: w * 0.3, height: 18)
            actionLine.frame = CGRect(x: 15, y: h - 110, width: 100, height: 36)
        }

        override func prepareForReuse() {
            super.prepareForReuse()
            [cardShimmer, avatarShimmer, nameLine1, nameLine2, actionLine].forEach { $0.stopShimmer() }
        }

        func setLoading(_ isLoading: Bool) {
            if isLoading {
                [cardShimmer, avatarShimmer, nameLine1, nameLine2, actionLine].forEach { $0.startShimmer() }
            } else {
                [cardShimmer, avatarShimmer, nameLine1, nameLine2, actionLine].forEach { $0.stopShimmer() }
            }
        }
    }

    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData

    private var containerLayout: (ContainerViewLayout, CGFloat)?

    private let _ready = ValuePromise<Bool>()
    private var didSetReady = false
    var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    private var storiesCollectionView: UICollectionView!
    private var mainCollectionView: UICollectionView!

    private let stories: [StoryModel] = [
        StoryModel(name: "Add Story", avatarName: "Chat List/AddIcon", isLive: false, isAdd: true),
        StoryModel(name: "Jack D.", avatarName: "Models/image5", isLive: false, isAdd: false),
        StoryModel(name: "Joshua", avatarName: "", isLive: false, isAdd: false),
        StoryModel(name: "waggles", avatarName: "", isLive: true, isAdd: false),
        StoryModel(name: "steve.loves", avatarName: "", isLive: true, isAdd: false),
    ]

    private var cards: [CardModel] = []

    private let tabTitles = ["SUBSCRIBED MODELS", "ALL USERS", "AGENCIES & PRO MEMBERS"]
    private var selectedTabIndex = 0

    private let tabsScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.backgroundColor = .white
        return sv
    }()

    private let tabsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 20
        stack.alignment = .center
        return stack
    }()

    private let tabIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.cornerRadius = 4
        view.layer.masksToBounds = true
        return view
    }()

    private let tabSeparatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        return view
    }()

    private var loadingPlaceholderView: UIView?
    var isPaginating: Bool = false {
        didSet {
            guard oldValue != isPaginating else { return }
            mainCollectionView.reloadData()
        }
    }

    var isLoading: Bool = false {
        didSet {
            if isLoading && cards.isEmpty {
                showLoadingPlaceholder()
            } else {
                hideLoadingPlaceholder()
            }
        }
    }

    var showProfile: ((CardModel) -> Void)?
    var loadMore: (() -> Void)?

    func updateCards(_ newCards: [CardModel]) {
        self.cards = newCards
        self.mainCollectionView.reloadData()
        if !newCards.isEmpty {
            hideLoadingPlaceholder()
        }
    }

    func appendCards(_ newCards: [CardModel]) {
        guard !newCards.isEmpty else { return }
        let startIndex = cards.count
        cards.append(contentsOf: newCards)
        let indexPaths = (startIndex..<cards.count).map { IndexPath(item: $0, section: 0) }
        mainCollectionView.performBatchUpdates {
            mainCollectionView.insertItems(at: indexPaths)
        }
    }

    init(controller: ViewController, context: AccountContext, presentationData: PresentationData) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData

        super.init()

        let storiesFlowLayout = UICollectionViewFlowLayout()
        storiesFlowLayout.scrollDirection = .horizontal
        storiesFlowLayout.minimumInteritemSpacing = 10
        storiesFlowLayout.minimumLineSpacing = 0
        storiesFlowLayout.sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        storiesFlowLayout.headerReferenceSize = .zero
        storiesFlowLayout.footerReferenceSize = .zero
        storiesFlowLayout.estimatedItemSize = CGSize(width: 70, height: 90)

        self.storiesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: storiesFlowLayout)
        self.storiesCollectionView.backgroundColor = .clear
        self.storiesCollectionView.dataSource = self
        self.storiesCollectionView.delegate = self
        self.storiesCollectionView.showsHorizontalScrollIndicator = false
        self.storiesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            self.storiesCollectionView.contentInsetAdjustmentBehavior = .never
        }
        self.storiesCollectionView.contentInset = .zero
        self.storiesCollectionView.register(StoryCollectionViewCell.self, forCellWithReuseIdentifier: "StoryCell")

        let mainFlowLayout = UICollectionViewFlowLayout()

        self.mainCollectionView = UICollectionView(frame: .zero, collectionViewLayout: mainFlowLayout)
        self.mainCollectionView.backgroundColor = .white
        self.mainCollectionView.dataSource = self
        self.mainCollectionView.delegate = self
        self.mainCollectionView.translatesAutoresizingMaskIntoConstraints = false
        self.mainCollectionView.delaysContentTouches = false
        self.mainCollectionView.canCancelContentTouches = true

        self.mainCollectionView.register(CardCollectionViewCell.self, forCellWithReuseIdentifier: "CardCell")
        self.mainCollectionView.register(PaginationShimmerCell.self, forCellWithReuseIdentifier: "PaginationShimmerCell")

        self.view.addSubview(self.mainCollectionView)
        self.mainCollectionView.addSubview(self.storiesCollectionView)
        self.mainCollectionView.addSubview(self.tabsScrollView)
        self.tabsScrollView.addSubview(self.tabsStackView)
        self.tabsScrollView.addSubview(self.tabIndicatorView)
        self.tabsScrollView.addSubview(self.tabSeparatorView)

        for (index, title) in tabTitles.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: index == 0 ? .bold : .regular)
            button.setTitleColor(index == 0 ? .black : UIColor(white: 0.5, alpha: 1.0), for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
            tabsStackView.addArrangedSubview(button)
        }

        self.storiesCollectionView.reloadData()
        self.mainCollectionView.reloadData()

        self.didSetReady = true
        self._ready.set(true)
    }

    @objc private func tabButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedTabIndex else { return }
        selectedTabIndex = index
        for case let button as UIButton in tabsStackView.arrangedSubviews {
            let isSelected = button.tag == index
            button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: isSelected ? .bold : .regular)
            button.setTitleColor(isSelected ? .black : UIColor(white: 0.5, alpha: 1.0), for: .normal)
        }
        UIView.animate(withDuration: 0.25) {
            self.layoutTabIndicator()
        }
    }

    private func layoutTabIndicator() {
        guard selectedTabIndex < tabsStackView.arrangedSubviews.count else { return }
        let selectedButton = tabsStackView.arrangedSubviews[selectedTabIndex]
        let frame = selectedButton.convert(selectedButton.bounds, to: tabsScrollView)
        let indicatorHeight: CGFloat = 2
        tabIndicatorView.frame = CGRect(
            x: floor(frame.minX),
            y: floor(tabsScrollView.bounds.height - indicatorHeight),
            width: ceil(frame.width),
            height: indicatorHeight
        )
        tabsScrollView.bringSubviewToFront(tabIndicatorView)
    }

    override func layout() {
        super.layout()
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)

        let insets = layout.insets(options: [.input])
        let safeAreaInsets = layout.safeInsets

        self.mainCollectionView.frame = CGRect(origin: .zero, size: layout.size)

        let storiesHeight: CGFloat = 90
        self.storiesCollectionView.frame = CGRect(x: 0,
                                                  y: navigationBarHeight,
                                                  width: layout.size.width,
                                                  height: storiesHeight)
        if #available(iOS 11.0, *) {
            self.storiesCollectionView.contentInsetAdjustmentBehavior = .never
        }
        self.storiesCollectionView.contentInset = .zero
        self.storiesCollectionView.scrollIndicatorInsets = .zero

        let tabsHeight: CGFloat = 36
        self.tabsScrollView.frame = CGRect(x: 0,
                                           y: self.storiesCollectionView.frame.maxY,
                                           width: layout.size.width,
                                           height: tabsHeight)
        let stackSize = tabsStackView.systemLayoutSizeFitting(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: tabsHeight),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .required)
        let stackWidth = max(stackSize.width + 30, layout.size.width)
        tabsStackView.frame = CGRect(x: 15, y: 0, width: stackWidth, height: tabsHeight - 2)
        tabsScrollView.contentSize = CGSize(width: stackWidth + 30, height: tabsHeight)
        tabSeparatorView.frame = CGRect(x: 0, y: tabsHeight - 1, width: max(stackWidth + 30, layout.size.width), height: 1)
        layoutTabIndicator()

        if let mainFlowLayout = self.mainCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            mainFlowLayout.sectionInset = UIEdgeInsets(top: self.tabsScrollView.frame.maxY,
                                                       left: safeAreaInsets.left,
                                                       bottom: insets.bottom,
                                                       right: safeAreaInsets.right)

            let cardWidth = layout.size.width - safeAreaInsets.left - safeAreaInsets.right
            let cardHeight = layout.size.height - mainFlowLayout.sectionInset.top - insets.bottom
            mainFlowLayout.itemSize = CGSize(width: cardWidth, height: cardHeight)
            mainFlowLayout.minimumLineSpacing = 0
        }

        self.mainCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        layoutLoadingPlaceholder()
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === storiesCollectionView {
            return stories.count
        } else if collectionView === mainCollectionView {
            return cards.count + (isPaginating ? 1 : 0)
        }
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        if collectionView === storiesCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StoryCell", for: indexPath) as? StoryCollectionViewCell else {
                fatalError("Unable to dequeue StoryCollectionViewCell")
            }
            cell.configure(with: stories[indexPath.item])
            return cell

        } else if collectionView === mainCollectionView {
            if isPaginating && indexPath.item == cards.count {
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PaginationShimmerCell", for: indexPath) as? PaginationShimmerCell else {
                    fatalError("Unable to dequeue PaginationShimmerCell")
                }
                cell.setLoading(true)
                return cell
            }

            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CardCell", for: indexPath) as? CardCollectionViewCell else {
                fatalError("Unable to dequeue CardCollectionViewCell")
            }

            let card = cards[indexPath.item]
            cell.configure(with: card, delegate: self)

            return cell
        }

        return UICollectionViewCell()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        if collectionView === storiesCollectionView {
            return CGSize(width: 70, height: 90)

        } else if collectionView === mainCollectionView {
            if let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout {
                if isPaginating && indexPath.item == cards.count {
                    return flowLayout.itemSize
                }
                let card = cards[indexPath.item]
                if card.previewImagesName.isEmpty && card.previewImageURLs.isEmpty {
                    return CGSize(width: flowLayout.itemSize.width, height: 360)
                }
                return flowLayout.itemSize
            }
        }

        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === storiesCollectionView {
            print("didSelectItemAt Story: \(stories[indexPath.item].name)")
        } else if collectionView === mainCollectionView {
            guard indexPath.item < cards.count else { return }
            showProfile?(cards[indexPath.item])
            print("didSelectItemAt: \(cards[indexPath.item].name)")
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === mainCollectionView, !cards.isEmpty else { return }
        let threshold: CGFloat = 500
        let contentOffsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.height
        if contentOffsetY + frameHeight + threshold > contentHeight {
            loadMore?()
        }
    }

    func cardCell(_ cell: CardCollectionViewCell, didTapReaction reaction: ReactionType, for cardName: String, isSelected: Bool) {
        guard let indexPath = mainCollectionView.indexPath(for: cell) else { return }
        var card = self.cards[indexPath.item]

        if isSelected {
             card.userReaction = reaction
         } else {
             card.userReaction = nil
         }

        switch reaction {
        case .like:
            print("👍 didSelectItemAt 'Like': \(cardName)")
        case .heart:
            print("❤️ didSelectItemAt 'Heart': \(cardName)")
        case .dislike:
            print("👎 didSelectItemAt 'Dislike': \(cardName)")
        case .fire:
            print("🔥 didSelectItemAt 'Fire': \(cardName)")
        }

        self.cards[indexPath.item] = card
    }

    // MARK: - Loading Placeholder

    private func showLoadingPlaceholder() {
        guard loadingPlaceholderView == nil else { return }

        let placeholder = UIView()
        placeholder.backgroundColor = .white
        placeholder.clipsToBounds = true

        let cardShimmer = ShimmerView()
        cardShimmer.layer.cornerRadius = 0
        cardShimmer.tag = 100
        placeholder.addSubview(cardShimmer)

        let avatarShimmer = ShimmerView()
        avatarShimmer.layer.cornerRadius = 35
        avatarShimmer.layer.masksToBounds = true
        avatarShimmer.tag = 101
        placeholder.addSubview(avatarShimmer)

        let nameLine1 = ShimmerView()
        nameLine1.layer.cornerRadius = 6
        nameLine1.layer.masksToBounds = true
        nameLine1.tag = 102
        placeholder.addSubview(nameLine1)

        let nameLine2 = ShimmerView()
        nameLine2.layer.cornerRadius = 6
        nameLine2.layer.masksToBounds = true
        nameLine2.tag = 103
        placeholder.addSubview(nameLine2)

        let actionLine = ShimmerView()
        actionLine.layer.cornerRadius = 10
        actionLine.layer.masksToBounds = true
        actionLine.tag = 104
        placeholder.addSubview(actionLine)

        self.view.addSubview(placeholder)
        loadingPlaceholderView = placeholder

        layoutLoadingPlaceholder()

        placeholder.subviews.compactMap { $0 as? ShimmerView }.forEach { $0.startShimmer() }
    }

    private func hideLoadingPlaceholder() {
        guard let placeholder = loadingPlaceholderView else { return }
        UIView.animate(withDuration: 0.25, animations: {
            placeholder.alpha = 0
        }, completion: { _ in
            placeholder.subviews.compactMap { $0 as? ShimmerView }.forEach { $0.stopShimmer() }
            placeholder.removeFromSuperview()
        })
        loadingPlaceholderView = nil
    }

    private func layoutLoadingPlaceholder() {
        guard let placeholder = loadingPlaceholderView,
              let (layout, navigationBarHeight) = containerLayout else { return }

        let topOffset = navigationBarHeight + 90 + 36
        placeholder.frame = CGRect(x: 0, y: topOffset, width: layout.size.width, height: layout.size.height - topOffset)

        let w = placeholder.bounds.width
        let h = placeholder.bounds.height

        if let cardShimmer = placeholder.viewWithTag(100) {
            cardShimmer.frame = placeholder.bounds
        }
        if let avatar = placeholder.viewWithTag(101) {
            avatar.frame = CGRect(x: 15, y: h - 200, width: 70, height: 70)
        }
        if let line1 = placeholder.viewWithTag(102) {
            line1.frame = CGRect(x: 95, y: h - 195, width: w * 0.45, height: 18)
        }
        if let line2 = placeholder.viewWithTag(103) {
            line2.frame = CGRect(x: 95, y: h - 170, width: w * 0.3, height: 18)
        }
        if let action = placeholder.viewWithTag(104) {
            action.frame = CGRect(x: 15, y: h - 110, width: 100, height: 36)
        }
    }
}
