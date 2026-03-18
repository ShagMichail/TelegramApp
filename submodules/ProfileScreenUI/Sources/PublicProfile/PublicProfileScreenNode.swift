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

final class PublicProfileScreenNode: ASDisplayNode {
    private static let mockBiographyText = "No biograpy"
    private static let mockBiographyMyProfileText = "Fill in the information about you"
    private let model: ProfileModel
    private var modelRole: String = "model"
    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private var navigationBarTitleView: ProfileNavigationBarTitleView?
    private var navigationBarTitleHeightConstraint: NSLayoutConstraint!
    
    // Управление моментом, когда начинаем анимировать title в навбаре
    private var titleVisibilityActivated = false
    
    private var headerHeightConstraint: NSLayoutConstraint!
    private var socialHeightConstraint: NSLayoutConstraint!
    private let iconPlaceholder = "HeartActionIcon"
    private let fixedHeaderHeight: CGFloat = 540.0
    private let fixedProfileHeaderHeight: CGFloat = 240.0
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let contentViewStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let headerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        return view
    }()
    
    private let blurredHeaderImageView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemChromeMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private let headerImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.backgroundColor = .gray
        return iv
    }()
    
    var currentPhoto: UIImage? = nil {
        didSet {
            if let currentPhoto = self.currentPhoto {
                profileHeaderView.changeAvatar(with: currentPhoto)
            } else {
                profileHeaderView.changeAvatar(with: nil)
            }
        }
    }
    
    // MARK: - Profile Header Section
    
    private lazy var infoStack: UIStackView = {
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 0
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        return infoStack
    }()
    
    private lazy var profileHeaderView = ProfileHeaderView()
    
    private lazy var profileHeaderShimmerView = ProfileHeaderShimmerView()
    
    
    // MARK: - Actions Section
    
    private lazy var counterActionsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stack
    }()
    
    private let counterActionsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let actionsShimmerView: CounterActionsShimmerView = {
        let actionsShimmerView = CounterActionsShimmerView()
        actionsShimmerView.translatesAutoresizingMaskIntoConstraints = false
        return actionsShimmerView
    }()
    
    private let dmButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .black.withAlphaComponent(0.15)
        button.layer.cornerRadius = 6
        button.layer.borderWidth = 0.0
        button.layer.borderColor = UIColor.clear.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    private enum ActionViewTags {
        static let dmIcon = 9_101
        static let dmLabel = 9_102

        static let counterIcon = 9_201
        static let counterCountLabel = 9_202
        static let counterNameLabel = 9_203
    }
    
    private let likesView: UIControl = {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let viewsView: UIControl = {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let savesView: UIControl = {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    
    // MARK: - Profile Info Section
    
    private let profileInfoContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var profileInfoView: ProfileInfoView = {
        let view = ProfileInfoView(
            biography: model.biography.isEmpty ? Self.mockBiographyText : model.biography,
            appearance: []
        )
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    private let profileInfoShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Current Agency Section
    
    private let currentAgencyContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var currentAgencyView: CurrentAgencyView = {
        let view = CurrentAgencyView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let currentAgencyShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Work History Section
    
    private let addWorkHistoryContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let addWorkHistoryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("+  Add work history", for: .normal)
        button.setTitleColor(.white.withAlphaComponent(0.88), for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(13)
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        button.backgroundColor = .black.withAlphaComponent(0.15)
        button.layer.cornerRadius = 6
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    
    // MARK: - Social Media Section
    
    private let socialMediaContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleEditContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let titleEditStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let editLinksButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(.white, for: .normal)
        button.setTitle("EDIT LINKS", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let editLinksLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(14)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "My Links"
        return label
    }()
    
    private let socialMediaStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fillEqually
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let socialShimmerView: CounterSocialShimmerView = {
        let socialShimmerView = CounterSocialShimmerView()
        socialShimmerView.translatesAutoresizingMaskIntoConstraints = false
        return socialShimmerView
    }()
    
    
    // MARK: - Segmented Bar Section
    
    private lazy var segmentedBar: ProfileSegmentedBar = {
        let view = ProfileSegmentedBar()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        return view
    }()
    
    private let segmentedBarPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var segmentedBarTopConstraint: NSLayoutConstraint?
    private let segmentedBarHeight: CGFloat = 40.0
    
    
    // MARK: - Gallery Collections Section
    
    private let collectionsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()
    
    
    // MARK: - Tabs & Swipe Logic Variables
    
    private var galleryHeightConstraint: NSLayoutConstraint!
    private var videoHeightConstraint: NSLayoutConstraint!
    private var channelHeightConstraint: NSLayoutConstraint!
    private var modelHeightConstraint: NSLayoutConstraint!
    private var eventHeightConstraint: NSLayoutConstraint!
    
    private var currentTabIndex: Int = 0
    private var collectionsContainerHeightConstraint: NSLayoutConstraint!
    
    private let photoTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let videoTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let channelTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let modelTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let eventTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    
    // MARK: - Gallery Section
    
    private var galleryPhotos: [UserPhoto] = []
    private var galleryCurrentOffset: Int = 0
    private var galleryIsLoading: Bool = false
    private var galleryHasMore: Bool = true
    private var galleryInitialized: Bool = false
    private var galleryImageNames: [String] = []
    
    private lazy var galleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "GalleryCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let galleryStatusView: GalleryStatusView = {
        let view = GalleryStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Video Gallery Pagination
    
    private var videoGalleryInitialized: Bool = false
    private var videoGalleryImageNames: [String] = []
    private var videoGalleryItems: [UserPhoto] = []
    private var videoGalleryTotalCount: Int = 0
    private var videoGalleryCurrentOffset: Int = 0
    private var videoGalleryIsLoading: Bool = false
    private var videoGalleryHasMore: Bool = true
    /// Защита от повторного запроса одной и той же страницы (особенно offset=0)
    private var videoGalleryRequestedOffsets: Set<Int> = []
    /// Последний offset, который мы отправили в запросе. Нужен, чтобы корректно вычислять nextOffset
    /// независимо от того, что означает `pagination.meta.currentOffset` (current vs next).
    private var videoGalleryLastRequestedOffset: Int?
    
    private lazy var videoGalleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(VideoGalleryCell.self, forCellWithReuseIdentifier: VideoGalleryCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let videoGalleryStatusView: GalleryStatusView = {
        let view = GalleryStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Channels Gallery Section
    
    private var channelGalleryItems: [ProfileChannelItem] = []
    private var channelGalleryInitialized: Bool = false
    
    private lazy var channelGalleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.register(ChannelListCell.self, forCellWithReuseIdentifier: ChannelListCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let channelGalleryStatusView: GalleryStatusView = {
        let view = GalleryStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Models Gallery Section
    
    private var modelGalleryItems: [ModelItem] = []
    private var modelGalleryInitialized: Bool = false
    
    private lazy var modelGalleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.register(ModelListCell.self, forCellWithReuseIdentifier: ModelListCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let modelGalleryStatusView: GalleryStatusView = {
        let view = GalleryStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Models Gallery Section
    
    private var eventGalleryItems: [EventItem] = []
    private var eventGalleryInitialized: Bool = false
    
    private lazy var eventGalleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.register(EventListCell.self, forCellWithReuseIdentifier: EventListCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let eventGalleryStatusView: GalleryStatusView = {
        let view = GalleryStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Similar Profiles Section
    
    private var similarProfiles: [SimilarProfileItem] = []
    private var similarProfilesTotalCount: Int = 0
    private var similarProfilesOffset: Int = 0
    private var similarProfilesHasMore: Bool = true
    private var similarProfilesIsLoading: Bool = false
    
    private let similarProfilesCollectionContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let similarProfilesTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "You may be interested in similar profiles"
        label.font = Font.helveticaNeue(18)
        label.textColor = UIColor(hex: "#222222")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var similarProfilesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 6
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(SimilarProfileCell.self, forCellWithReuseIdentifier: SimilarProfileCell.reuseIdentifier)
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    
    // MARK: - Sheet View
    
    var onLikesTapped: (() -> Void)?
    var onViewsTapped: (() -> Void)?
    var onSavesTapped: (() -> Void)?
    
    
    // MARK: - Init
    
    init(controller: ViewController, context: AccountContext, presentationData: PresentationData, model: ProfileModel) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData
        self.model = model
        //        self.addPhoto = addPhoto
        super.init()
        
        self.view.backgroundColor = .black
        
        setupContent()
        configureNodes()
        loadSimilarProfiles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Override
    
    override func layout() {
        super.layout()
        
        guard let (layout, _) = self.containerLayout else { return }
        
        let stackWidth = layout.size.width
        
        contentViewStack.layoutIfNeeded()
        
        let contentHeight = contentViewStack.systemLayoutSizeFitting(
            CGSize(width: stackWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        
        contentViewStack.frame = CGRect(x: 0, y: 0, width: stackWidth, height: contentHeight)
        scrollView.contentSize = CGSize(width: stackWidth, height: contentHeight)
        
        applyGradientBlurMask()
        
        if !profileInfoShimmerView.isHidden {
            profileInfoShimmerView.stopShimmering()
            profileInfoShimmerView.startShimmering()
        }
        
        if !actionsShimmerView.isHidden {
            actionsShimmerView.startAnimation()
        }
        
        if !socialShimmerView.isHidden {
            socialShimmerView.startAnimation()
        }
        
        if !currentAgencyShimmerView.isHidden {
            currentAgencyShimmerView.stopShimmering()
            currentAgencyShimmerView.startShimmering()
        }
        
        updateSegmentedBarPosition()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if model.isMyProfile {
            dmButton.addTarget(self, action: #selector(dmButtonTapped), for: .touchUpInside)
        }
    }
    
    
    // MARK: - Private
    
    private func setupContent() {
        setupHeaderImageView()
        setupBlurredHeaderImageView()
        setupScrollView()
        setupContentViewStack()
        setupSegmentedBar()
        setupContentLayout()
        setupAllCollectionsLayers()
        setupSimilarProfiles()
    }
    
    private func setupHeaderImageView() {
        self.view.addSubview(headerImageView)
        
        NSLayoutConstraint.activate([
            headerImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            headerImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            headerImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            headerImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
    }
    
    private func setupBlurredHeaderImageView() {
        self.view.addSubview(blurredHeaderImageView)
        
        NSLayoutConstraint.activate([
            blurredHeaderImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            blurredHeaderImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            blurredHeaderImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            blurredHeaderImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
    }
    
    private func setupScrollView() {
        self.view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
        
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor)
        navigationBarTitleHeightConstraint.isActive = true
        
        scrollView.delegate = self
    }
    
    private func setupContentViewStack() {
        scrollView.addSubview(contentViewStack)
        
        NSLayoutConstraint.activate([
            contentViewStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentViewStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentViewStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentViewStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentViewStack.widthAnchor.constraint(equalTo: self.view.widthAnchor),
        ])
    }
    
    private func setupSegmentedBar() {
        self.view.addSubview(segmentedBar)
        
        NSLayoutConstraint.activate([
            segmentedBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            segmentedBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            segmentedBar.heightAnchor.constraint(equalToConstant: segmentedBarHeight)
        ])
        
        segmentedBarTopConstraint = segmentedBar.topAnchor.constraint(equalTo: self.view.topAnchor)
        segmentedBarTopConstraint?.isActive = true
    }
    
    private func setupContentLayout() {
        setupHeaderContainer()
        setupCounterActionsContainer()
        setupProfileInfoContainer()
        setupCurrentAgencyContainer()
        setupAddWorkHistoryContainer()
        setupSocialMediaContainer()
        setupSegmentedBarPlaceholder()
    }
    
    private func setupHeaderContainer() {
        contentViewStack.addArrangedSubview(headerContainer)
        headerHeightConstraint = headerContainer.heightAnchor.constraint(equalToConstant: fixedHeaderHeight)
        headerHeightConstraint.isActive = true
        
        headerContainer.addSubview(infoStack)
        infoStack.addArrangedSubview(profileHeaderView)
        infoStack.addArrangedSubview(profileHeaderShimmerView)
        
        NSLayoutConstraint.activate([
            headerContainer.widthAnchor.constraint(equalTo: contentViewStack.widthAnchor),
            
            infoStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            infoStack.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            infoStack.heightAnchor.constraint(equalToConstant: 85),
        ])
    }
    
    private func setupCounterActionsContainer() {
        contentViewStack.addArrangedSubview(counterActionsContainer)
        counterActionsContainer.addSubview(actionsShimmerView)
        counterActionsContainer.addSubview(counterActionsStack)
        
        counterActionsStack.addArrangedSubview(dmButton)
        counterActionsStack.addArrangedSubview(likesView)
        counterActionsStack.addArrangedSubview(viewsView)
        counterActionsStack.addArrangedSubview(savesView)
        
        NSLayoutConstraint.activate([
            counterActionsContainer.topAnchor.constraint(equalTo: infoStack.bottomAnchor, constant: 20),
            counterActionsContainer.heightAnchor.constraint(equalToConstant: 36),
            counterActionsContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            counterActionsContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            
            actionsShimmerView.leadingAnchor.constraint(equalTo: counterActionsContainer.leadingAnchor, constant: 16),
            actionsShimmerView.trailingAnchor.constraint(equalTo: counterActionsContainer.trailingAnchor, constant: -16),
            actionsShimmerView.topAnchor.constraint(equalTo: counterActionsContainer.topAnchor),
            actionsShimmerView.bottomAnchor.constraint(equalTo: counterActionsContainer.bottomAnchor),
            
            counterActionsStack.leadingAnchor.constraint(equalTo: counterActionsContainer.leadingAnchor, constant: 16),
            counterActionsStack.trailingAnchor.constraint(equalTo: counterActionsContainer.trailingAnchor, constant: -16),
            counterActionsStack.topAnchor.constraint(equalTo: counterActionsContainer.topAnchor),
            counterActionsStack.bottomAnchor.constraint(equalTo: counterActionsContainer.bottomAnchor),
        ])
        
        contentViewStack.setCustomSpacing(12, after: counterActionsStack)
        contentViewStack.setCustomSpacing(12, after: actionsShimmerView)
    }
    
    private func setupProfileInfoContainer() {
        contentViewStack.addArrangedSubview(profileInfoContainer)
        profileInfoContainer.addSubview(profileInfoView)
        profileInfoContainer.addSubview(profileInfoShimmerView)
        
        NSLayoutConstraint.activate([
            profileInfoContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            profileInfoContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            
            profileInfoView.leadingAnchor.constraint(equalTo: profileInfoContainer.leadingAnchor, constant: 16),
            profileInfoView.trailingAnchor.constraint(equalTo: profileInfoContainer.trailingAnchor, constant: -16),
            profileInfoView.topAnchor.constraint(equalTo: profileInfoContainer.topAnchor),
            profileInfoView.bottomAnchor.constraint(equalTo: profileInfoContainer.bottomAnchor),
            
            profileInfoShimmerView.leadingAnchor.constraint(equalTo: profileInfoContainer.leadingAnchor, constant: 16),
            profileInfoShimmerView.trailingAnchor.constraint(equalTo: profileInfoContainer.trailingAnchor, constant: -16),
            profileInfoShimmerView.topAnchor.constraint(equalTo: profileInfoContainer.topAnchor),
            profileInfoShimmerView.bottomAnchor.constraint(equalTo: profileInfoContainer.bottomAnchor),
        ])
        
        contentViewStack.setCustomSpacing(20, after: profileInfoView)
    }
    
    private func setupCurrentAgencyContainer() {
        contentViewStack.addArrangedSubview(currentAgencyContainer)
        currentAgencyContainer.addSubview(currentAgencyView)
        currentAgencyContainer.addSubview(currentAgencyShimmerView)
        
        NSLayoutConstraint.activate([
            currentAgencyContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            currentAgencyContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            
            currentAgencyView.leadingAnchor.constraint(equalTo: currentAgencyContainer.leadingAnchor, constant: 16),
            currentAgencyView.trailingAnchor.constraint(equalTo: currentAgencyContainer.trailingAnchor, constant: -16),
            currentAgencyView.topAnchor.constraint(equalTo: currentAgencyContainer.topAnchor),
            currentAgencyView.bottomAnchor.constraint(equalTo: currentAgencyContainer.bottomAnchor),
            
            currentAgencyShimmerView.leadingAnchor.constraint(equalTo: currentAgencyContainer.leadingAnchor, constant: 16),
            currentAgencyShimmerView.trailingAnchor.constraint(equalTo: currentAgencyContainer.trailingAnchor, constant: -16),
            currentAgencyShimmerView.topAnchor.constraint(equalTo: currentAgencyContainer.topAnchor),
            currentAgencyShimmerView.bottomAnchor.constraint(equalTo: currentAgencyContainer.bottomAnchor),
        ])
    }
    
    private func setupAddWorkHistoryContainer() {
        contentViewStack.addArrangedSubview(addWorkHistoryContainer)
        addWorkHistoryContainer.addSubview(addWorkHistoryButton)
        
        NSLayoutConstraint.activate([
            addWorkHistoryContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor, constant: 16),
            addWorkHistoryContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor, constant: -16),
            addWorkHistoryContainer.heightAnchor.constraint(equalToConstant: 36),
            addWorkHistoryButton.leadingAnchor.constraint(equalTo: addWorkHistoryContainer.leadingAnchor),
            addWorkHistoryButton.centerYAnchor.constraint(equalTo: addWorkHistoryContainer.centerYAnchor),
            addWorkHistoryButton.heightAnchor.constraint(equalToConstant: 36),
            addWorkHistoryButton.widthAnchor.constraint(equalToConstant: 160),
        ])
        
        contentViewStack.setCustomSpacing(12, after: addWorkHistoryContainer)
    }
    
    private func setupSocialMediaContainer() {
        contentViewStack.addArrangedSubview(titleEditContainer)
        titleEditContainer.addSubview(titleEditStack)
        titleEditStack.addArrangedSubview(editLinksLabel)
        titleEditStack.addArrangedSubview(UIView())
        titleEditStack.addArrangedSubview(editLinksButton)
        
        contentViewStack.addArrangedSubview(socialMediaContainer)
        socialMediaContainer.addSubview(socialMediaStack)
        socialMediaContainer.addSubview(socialShimmerView)
        
        NSLayoutConstraint.activate([
            titleEditContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            titleEditContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            
            titleEditStack.leadingAnchor.constraint(equalTo: titleEditContainer.leadingAnchor, constant: 16),
            titleEditStack.trailingAnchor.constraint(equalTo: titleEditContainer.trailingAnchor, constant: -16),
            titleEditStack.topAnchor.constraint(equalTo: titleEditContainer.topAnchor),
            titleEditStack.bottomAnchor.constraint(equalTo: titleEditContainer.bottomAnchor),
            
            socialMediaContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            socialMediaContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            socialMediaStack.leadingAnchor.constraint(equalTo: socialMediaContainer.leadingAnchor, constant: 16),
            socialMediaStack.trailingAnchor.constraint(equalTo: socialMediaContainer.trailingAnchor, constant: -16),
            socialMediaStack.topAnchor.constraint(equalTo: socialMediaContainer.topAnchor),
            socialMediaStack.bottomAnchor.constraint(equalTo: socialMediaContainer.bottomAnchor),
            socialMediaStack.heightAnchor.constraint(equalToConstant: 68),
            
            socialShimmerView.leadingAnchor.constraint(equalTo: socialMediaContainer.leadingAnchor, constant: 16),
            socialShimmerView.trailingAnchor.constraint(equalTo: socialMediaContainer.trailingAnchor, constant: -16),
            socialShimmerView.topAnchor.constraint(equalTo: socialMediaContainer.topAnchor),
            socialShimmerView.bottomAnchor.constraint(equalTo: socialMediaContainer.bottomAnchor),
            socialShimmerView.heightAnchor.constraint(equalToConstant: 68),
        ])
        
        contentViewStack.setCustomSpacing(8, after: socialMediaStack)
        contentViewStack.setCustomSpacing(8, after: socialShimmerView)
        contentViewStack.setCustomSpacing(4, after: titleEditContainer)
        
        socialHeightConstraint = socialMediaStack.heightAnchor.constraint(equalToConstant: 68)
        socialHeightConstraint.isActive = true
    }
    
    private func setupSegmentedBarPlaceholder() {
        contentViewStack.addArrangedSubview(segmentedBarPlaceholder)
        
        NSLayoutConstraint.activate([
            segmentedBarPlaceholder.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor, constant: 0),
            segmentedBarPlaceholder.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor, constant: 0),
            segmentedBarPlaceholder.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        contentViewStack.setCustomSpacing(0, after: segmentedBarPlaceholder)
    }
    
    private func setupAllCollectionsLayers() {
        contentViewStack.addArrangedSubview(collectionsContainer)
        
        collectionsContainerHeightConstraint = collectionsContainer.heightAnchor.constraint(equalToConstant: 160)
        collectionsContainerHeightConstraint.isActive = true
        
        let containers = [photoTabContainer, videoTabContainer, channelTabContainer, modelTabContainer, eventTabContainer]
        for container in containers {
            collectionsContainer.addSubview(container)
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: collectionsContainer.topAnchor),
                container.leadingAnchor.constraint(equalTo: collectionsContainer.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: collectionsContainer.trailingAnchor),
                container.bottomAnchor.constraint(equalTo: collectionsContainer.bottomAnchor)
            ])
        }
        
        // --- PHOTO ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        galleryHeightConstraint = galleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        galleryHeightConstraint.isActive = true
        
        photoTabContainer.addSubview(galleryStatusView)
        photoTabContainer.addSubview(galleryCollectionView)
        NSLayoutConstraint.activate([
            galleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            galleryStatusView.topAnchor.constraint(equalTo: photoTabContainer.topAnchor),
            galleryStatusView.leadingAnchor.constraint(equalTo: photoTabContainer.leadingAnchor, constant: 16),
            galleryStatusView.trailingAnchor.constraint(equalTo: photoTabContainer.trailingAnchor, constant: -16),
            
            galleryCollectionView.topAnchor.constraint(equalTo: photoTabContainer.topAnchor),
            galleryCollectionView.leadingAnchor.constraint(equalTo: photoTabContainer.leadingAnchor),
            galleryCollectionView.trailingAnchor.constraint(equalTo: photoTabContainer.trailingAnchor)
        ])
        galleryCollectionView.isHidden = true
        galleryStatusView.isHidden = false
        galleryStatusView.configure(isLoading: true, text: "Uploading Photos...", isMyProfile: false)
        
        // --- VIDEO ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        videoHeightConstraint = videoGalleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        videoHeightConstraint.isActive = true
        
        videoTabContainer.addSubview(videoGalleryStatusView)
        videoTabContainer.addSubview(videoGalleryCollectionView)
        NSLayoutConstraint.activate([
            videoGalleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            videoGalleryStatusView.topAnchor.constraint(equalTo: videoTabContainer.topAnchor),
            videoGalleryStatusView.leadingAnchor.constraint(equalTo: videoTabContainer.leadingAnchor, constant: 16),
            videoGalleryStatusView.trailingAnchor.constraint(equalTo: videoTabContainer.trailingAnchor, constant: -16),
            
            videoGalleryCollectionView.topAnchor.constraint(equalTo: videoTabContainer.topAnchor),
            videoGalleryCollectionView.leadingAnchor.constraint(equalTo: videoTabContainer.leadingAnchor),
            videoGalleryCollectionView.trailingAnchor.constraint(equalTo: videoTabContainer.trailingAnchor)
        ])
        videoGalleryCollectionView.isHidden = true
        videoGalleryStatusView.isHidden = false
        videoGalleryStatusView.configure(isLoading: true, text: "Uploading Videos...", isMyProfile: false)
        
        // --- CHANNELS ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        channelHeightConstraint = channelGalleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        channelHeightConstraint.isActive = true
        
        channelTabContainer.addSubview(channelGalleryStatusView)
        channelTabContainer.addSubview(channelGalleryCollectionView)
        NSLayoutConstraint.activate([
            channelGalleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            channelGalleryStatusView.topAnchor.constraint(equalTo: channelTabContainer.topAnchor),
            channelGalleryStatusView.leadingAnchor.constraint(equalTo: channelTabContainer.leadingAnchor, constant: 16),
            channelGalleryStatusView.trailingAnchor.constraint(equalTo: channelTabContainer.trailingAnchor, constant: -16),
            
            channelGalleryCollectionView.topAnchor.constraint(equalTo: channelTabContainer.topAnchor),
            channelGalleryCollectionView.leadingAnchor.constraint(equalTo: channelTabContainer.leadingAnchor),
            channelGalleryCollectionView.trailingAnchor.constraint(equalTo: channelTabContainer.trailingAnchor)
        ])
        channelGalleryCollectionView.isHidden = true
        channelGalleryStatusView.isHidden = false
        channelGalleryStatusView.configure(isLoading: true, text: "Loading channels...", isMyProfile: false)
        
        // --- MODELS ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        modelHeightConstraint = modelGalleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        modelHeightConstraint.isActive = true
        
        modelTabContainer.addSubview(modelGalleryStatusView)
        modelTabContainer.addSubview(modelGalleryCollectionView)
        NSLayoutConstraint.activate([
            modelGalleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            modelGalleryStatusView.topAnchor.constraint(equalTo: modelTabContainer.topAnchor),
            modelGalleryStatusView.leadingAnchor.constraint(equalTo: modelTabContainer.leadingAnchor, constant: 16),
            modelGalleryStatusView.trailingAnchor.constraint(equalTo: modelTabContainer.trailingAnchor, constant: -16),
            
            modelGalleryCollectionView.topAnchor.constraint(equalTo: modelTabContainer.topAnchor),
            modelGalleryCollectionView.leadingAnchor.constraint(equalTo: modelTabContainer.leadingAnchor),
            modelGalleryCollectionView.trailingAnchor.constraint(equalTo: modelTabContainer.trailingAnchor)
        ])
        modelGalleryCollectionView.isHidden = true
        modelGalleryStatusView.isHidden = false
        modelGalleryStatusView.configure(isLoading: true, text: "Loading models...", isMyProfile: false)
        
        // --- EVENTS ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        eventHeightConstraint = eventGalleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        eventHeightConstraint.isActive = true
        
        eventTabContainer.addSubview(eventGalleryStatusView)
        eventTabContainer.addSubview(eventGalleryCollectionView)
        NSLayoutConstraint.activate([
            eventGalleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            eventGalleryStatusView.topAnchor.constraint(equalTo: eventTabContainer.topAnchor),
            eventGalleryStatusView.leadingAnchor.constraint(equalTo: eventTabContainer.leadingAnchor, constant: 16),
            eventGalleryStatusView.trailingAnchor.constraint(equalTo: eventTabContainer.trailingAnchor, constant: -16),
            
            eventGalleryCollectionView.topAnchor.constraint(equalTo: eventTabContainer.topAnchor),
            eventGalleryCollectionView.leadingAnchor.constraint(equalTo: eventTabContainer.leadingAnchor),
            eventGalleryCollectionView.trailingAnchor.constraint(equalTo: eventTabContainer.trailingAnchor)
        ])
        eventGalleryCollectionView.isHidden = true
        eventGalleryStatusView.isHidden = false
        eventGalleryStatusView.configure(isLoading: true, text: "Loading events...", isMyProfile: false)
    }
    
    private func setupSimilarProfiles() {
        contentViewStack.addArrangedSubview(similarProfilesCollectionContainer)
        similarProfilesCollectionContainer.addSubview(similarProfilesTitleLabel)
        similarProfilesCollectionContainer.addSubview(similarProfilesCollectionView)
        
        NSLayoutConstraint.activate([
            similarProfilesTitleLabel.topAnchor.constraint(equalTo: similarProfilesCollectionContainer.topAnchor, constant: 16),
            similarProfilesTitleLabel.leadingAnchor.constraint(equalTo: similarProfilesCollectionContainer.leadingAnchor, constant: 16),
            similarProfilesTitleLabel.trailingAnchor.constraint(equalTo: similarProfilesCollectionContainer.trailingAnchor, constant: -16),
            
            similarProfilesCollectionView.topAnchor.constraint(equalTo: similarProfilesTitleLabel.topAnchor, constant: 16),
            similarProfilesCollectionView.leadingAnchor.constraint(equalTo: similarProfilesCollectionContainer.leadingAnchor),
            similarProfilesCollectionView.trailingAnchor.constraint(equalTo: similarProfilesCollectionContainer.trailingAnchor),
            similarProfilesCollectionView.bottomAnchor.constraint(equalTo: similarProfilesCollectionContainer.bottomAnchor, constant: -30),
            similarProfilesCollectionView.heightAnchor.constraint(equalToConstant: 232)
        ])
        
        contentViewStack.setCustomSpacing(0, after: collectionsContainer)
        
        contentViewStack.setCustomSpacing(0, after: videoGalleryCollectionView)
        contentViewStack.setCustomSpacing(0, after: videoGalleryStatusView)
        
        contentViewStack.setCustomSpacing(0, after: channelGalleryCollectionView)
        contentViewStack.setCustomSpacing(0, after: channelGalleryStatusView)
        
        contentViewStack.setCustomSpacing(0, after: modelGalleryCollectionView)
        contentViewStack.setCustomSpacing(0, after: modelGalleryStatusView)
        
        contentViewStack.setCustomSpacing(0, after: eventGalleryCollectionView)
        contentViewStack.setCustomSpacing(0, after: eventGalleryStatusView)
    }
    
    // Настройка шиммеров
    private func configureNodes() {
        profileHeaderShimmerView.isHidden = false
        profileHeaderView.isHidden = true
        
        actionsShimmerView.isHidden = false
        counterActionsStack.isHidden = true
        
        profileInfoShimmerView.isHidden = false
        profileInfoView.isHidden = true
        
        socialShimmerView.isHidden = false
        socialMediaStack.isHidden = true
        
        currentAgencyShimmerView.isHidden = false
        currentAgencyView.isHidden = true
        
        if !model.isMyProfile {
            self.addWorkHistoryContainer.removeFromSuperview()
        }
    }
    
    // Убираем шиммеры, после загрузки
    private func stopShimmers() {
        guard profileHeaderView.isHidden else { return }

        // Важно: переключение шиммеров на контент должно быть без каких-либо анимаций,
        // иначе некоторые блоки (например Current Agency) визуально «дергаются».
        UIView.performWithoutAnimation {
            // Полностью отключаем все implicit animations
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setAnimationDuration(0.0)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))

            // Мгновенно переключаем шиммеры на контент
            profileHeaderShimmerView.isHidden = true
            profileHeaderView.alpha = 1.0
            profileHeaderView.isHidden = false  // Убедимся, что view виден

            actionsShimmerView.isHidden = true
            counterActionsStack.alpha = 1.0
            counterActionsStack.isHidden = false

            profileInfoShimmerView.isHidden = true
            profileInfoView.alpha = 1.0
            profileInfoView.isHidden = false

            socialShimmerView.isHidden = true
            socialMediaStack.alpha = 1.0
            socialMediaStack.isHidden = false

            currentAgencyShimmerView.isHidden = true
            currentAgencyView.alpha = 1.0
            currentAgencyView.isHidden = false

            CATransaction.commit()

            // Принудительно обновляем layout
            self.contentViewStack.setNeedsLayout()
            self.contentViewStack.layoutIfNeeded()
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }
    
    private func applyGradientBlurMask() {
        let blurHeight = blurredHeaderImageView.bounds.height
        guard blurHeight > 0 else { return }
        let blurStartPoint = blurHeight * 0.02
        let blurFullPoint = blurHeight * 0.55
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = blurredHeaderImageView.bounds
        
        let startLocation = blurStartPoint / blurHeight
        let fullLocation = blurFullPoint / blurHeight
        
        let clampedStartLocation = max(0.0, min(1.0, startLocation))
        let clampedFullLocation = max(0.0, min(1.0, fullLocation))
        
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.white.cgColor]
        
        gradientLayer.locations = [NSNumber(value: Double(clampedStartLocation)),
                                   NSNumber(value: Double(clampedFullLocation))]
        
        blurredHeaderImageView.layer.mask = gradientLayer
    }
    
    // Настройка SegmentedBar для прилипания
    private func updateSegmentedBarPosition() {
        guard let (_, navigationBarHeight) = self.containerLayout else { return }
        
        let placeholderFrame = segmentedBarPlaceholder.convert(segmentedBarPlaceholder.bounds, to: self.view)
        
        let naturalY = placeholderFrame.minY
        
        let stickyY = navigationBarHeight
        
        let finalY = max(naturalY, stickyY)
        
        segmentedBarTopConstraint?.constant = finalY
        
        if finalY <= stickyY + 1 {
            segmentedBar.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        } else {
            segmentedBar.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        }
    }
    
    // Настройка кнопки чата/загрузки фотографии
    private func setupDmButtonContent() {
        var iconImageName = "Chat/Context Menu/MessageBubble"
        var labelText = "Send DM"
        if model.isMyProfile {
            iconImageName = "Avatar/AddAvatarIconLarge"
            labelText = "Upload your photos"
        }

        // Важно: не пересоздаем subviews каждый раз (иначе UI заметно дергается при обновлениях)
        if let iconImageView = dmButton.viewWithTag(ActionViewTags.dmIcon) as? UIImageView,
           let label = dmButton.viewWithTag(ActionViewTags.dmLabel) as? UILabel {
            iconImageView.image = UIImage(bundleImageName: iconImageName)
            label.text = labelText
            return
        }

        dmButton.subviews.forEach { $0.removeFromSuperview() }
        
        let iconImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.image = UIImage(bundleImageName: iconImageName)
            imageView.tintColor = .white
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.tag = ActionViewTags.dmIcon
            return imageView
        }()
        
        let label: UILabel = {
            let label = UILabel()
            label.text = labelText
            label.textColor = .white
            label.font = Font.helveticaNeue(13)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.tag = ActionViewTags.dmLabel
            return label
        }()
        
        let stackView: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [iconImageView, label])
            stack.axis = .horizontal
            stack.spacing = 4
            stack.alignment = .center
            stack.isUserInteractionEnabled = false
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        
        dmButton.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: dmButton.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: dmButton.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // Создание кнопок счетчиков (лайки, просмотры, сохраненки)
    private func setupCounterView(_ container: UIControl, count: String, name: String, iconName: String) {
        // Важно: не пересоздаем subviews/constraints каждый раз.
        // Иначе при повторных updateWithUserDetail / refresh будет заметный «рывок».
        if let iconImageView = container.viewWithTag(ActionViewTags.counterIcon) as? UIImageView,
           let countLabel = container.viewWithTag(ActionViewTags.counterCountLabel) as? UILabel,
           let nameLabel = container.viewWithTag(ActionViewTags.counterNameLabel) as? UILabel {
            iconImageView.image = UIImage(bundleImageName: iconName)
            countLabel.text = count
            nameLabel.text = name
            return
        }

        container.subviews.forEach { $0.removeFromSuperview() }
        
        let icon: UIImageView = {
            let imageView = UIImageView()
            imageView.image = UIImage(bundleImageName: iconName)
            imageView.tintColor = .white
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true
            imageView.tag = ActionViewTags.counterIcon
            return imageView
        }()
        
        let countLabel: UILabel = {
            let label = UILabel()
            label.text = count
            label.font = UIFont.boldSystemFont(ofSize: 14)
            label.textColor = .white
            label.tag = ActionViewTags.counterCountLabel
            return label
        }()
        
        let nameLabel: UILabel = {
            let label = UILabel()
            label.text = name
            label.font = UIFont.systemFont(ofSize: 10)
            label.textColor = .white
            label.tag = ActionViewTags.counterNameLabel
            return label
        }()
        
        let countStack: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [icon, countLabel])
            stack.axis = .horizontal
            stack.spacing = 2
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        
        let mainStack: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [countStack, nameLabel])
            stack.axis = .horizontal
            stack.spacing = 4
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.isUserInteractionEnabled = false
            return stack
        }()
        
        container.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            mainStack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 0),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: 0),
        ])
        
        container.removeTarget(nil, action: nil, for: .allEvents)
        container.addTarget(self, action: #selector(handleTouchDown(_:)), for: [.touchDown, .touchDragEnter])
        container.addTarget(self, action: #selector(handleTouchUp(_:)), for:[.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        
        if container === likesView {
            container.addTarget(self, action: #selector(likesViewDidTap), for: .touchUpInside)
        } else if container === viewsView {
            container.addTarget(self, action: #selector(viewsViewDidTap), for: .touchUpInside)
        } else if container === savesView {
            container.addTarget(self, action: #selector(savesViewDidTap), for: .touchUpInside)
        }
    }
    
    // Создание кнопок социальных сетей
    private func createSocialMediaButton(handle: String, iconName: String) -> UIView {
        let button = UIButton(type: .system)
        button.backgroundColor = .black.withAlphaComponent(0.12)
        button.layer.cornerRadius = 6
        
        let icon = UIImageView()
        icon.image = UIImage(bundleImageName: iconName)
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        let label = UILabel()
        label.text = handle
        label.font = Font.helveticaNeue(10)
        label.textColor = .white
        
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 5
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        return button
    }
    
    // Создание кнопоки социально сети, если она одна
    private func createSocialOneMediaButton(handle: String, iconName: String) -> UIView {
        let button = UIButton(type: .system)
        button.backgroundColor = .black.withAlphaComponent(0.12)
        button.layer.cornerRadius = 6
        
        let icon = UIImageView()
        icon.image = UIImage(bundleImageName: iconName)
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        let label = UILabel()
        label.text = handle
        label.font = Font.helveticaNeue(10)
        label.textColor = .white
        
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = 5
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        return button
    }
    
    // Добавление коллекции похожих профилей
    private func appendSimilarProfiles(_ profiles: [SimilarProfileItem], totalCount: Int) {
        let previousCount = self.similarProfiles.count
        self.similarProfiles.append(contentsOf: profiles)
        self.similarProfilesTotalCount = totalCount
        self.similarProfilesOffset = self.similarProfiles.count
        self.similarProfilesHasMore = self.similarProfiles.count < totalCount
        
        // debug: removed
        
        if previousCount == 0 {
            similarProfilesCollectionView.reloadData()
        } else {
            let newIndices = (previousCount..<(previousCount + profiles.count)).map { IndexPath(item: $0, section: 0) }
            similarProfilesCollectionView.insertItems(at: newIndices)
        }
    }
    
    // Вычисляем возраст от года рождения
    private func calculateAge(from birthdayString: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let birthday = formatter.date(from: birthdayString) else { return 0 }
        
        let now = Date()
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthday, to: now)
        return ageComponents.year ?? 0
    }
    
    // Создаем список критериев внешнего вида модели
    private func buildAppearanceList(from appearance: UserAppearance?, gender: UserGender?) -> [AppearanceAttribute] {
        
        var items: [AppearanceAttribute] = []
        
        if let gender = gender {
            items.append(.init(title: "Gender", value: "\(gender.title)"))
        }
        
        if let appearance = appearance {
            if let height = appearance.height {
                items.append(.init(title: "Height", value: "\(height.clean) cm"))
            }
            if let weight = appearance.weight {
                items.append(.init(title: "Weight", value: "\(weight.clean) kg"))
            }
            if let bust = appearance.breastSize {
                items.append(.init(title: "Bust", value: bust))
            }
            if let waist = appearance.waist {
                items.append(.init(title: "Waist", value: "\(waist.clean) cm"))
            }
            if let hips = appearance.hips {
                items.append(.init(title: "Hips", value: "\(hips.clean) cm"))
            }
            if let shoesSize = appearance.shoesSize {
                items.append(.init(title: "Shoes", value: "\(shoesSize.clean) EU"))
            }
            if let hairColor = appearance.hairColor?.title {
                items.append(.init(title: "Hair Color", value: hairColor))
            }
            if let hairLength = appearance.hairLength?.title {
                items.append(.init(title: "Hair Length", value: hairLength))
            }
            if let eyeColor = appearance.eyeColor?.title {
                items.append(.init(title: "Eye Color", value: eyeColor))
            }
            if let skinColor = appearance.skinColor?.title {
                items.append(.init(title: "Skin Color", value: skinColor))
            }
        }
        
        return items
    }
    
    // Создаем все кнопки социальный сетей
    private func populateSocialMedia(handles: [String], icons: [String]) {
        UIView.animate(withDuration: 0.3, animations: {
            
            if handles.isEmpty {
                self.socialMediaContainer.alpha = 0
                
                self.socialHeightConstraint?.isActive = false
                self.socialHeightConstraint = self.socialMediaContainer.heightAnchor.constraint(equalToConstant: 0)
                self.socialHeightConstraint.isActive = true
                self.titleEditContainer.removeFromSuperview()
                
            } else {
                self.socialMediaContainer.alpha = 1
                
                self.socialMediaStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
                
                for (index, handle) in handles.enumerated() {
                    let iconName = icons[safe: index] ?? self.iconPlaceholder
                    if handles.count == 1 {
                        self.socialMediaStack.addArrangedSubview(self.createSocialOneMediaButton(handle: handle, iconName: iconName))
                    } else {
                        self.socialMediaStack.addArrangedSubview(self.createSocialMediaButton(handle: handle, iconName: iconName))
                    }
                }
                
                self.socialHeightConstraint?.isActive = false
                let newHeight: CGFloat = (handles.count == 1) ? 44 : 68
                self.socialHeightConstraint = self.socialMediaContainer.heightAnchor.constraint(equalToConstant: newHeight)
                self.socialHeightConstraint.isActive = true
            }
            
            self.view.layoutIfNeeded()
            
        }) { completed in
            if completed && handles.isEmpty {
                self.socialMediaContainer.isHidden = true
            } else {
                self.socialMediaContainer.isHidden = false
            }
        }
    }
    
    // Получаем картинку флага в зависимости от кода страны
    private static func flag(for countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
    }
    
    // Первоначальная настройка титула NavigationBar
    private func setupNavigationBarTitle(name: String, info: String? = nil) {
        // Проверяем, не создаем ли мы titleView повторно
        if let existingTitleView = self.navigationBarTitleView {
            existingTitleView.configure(name: name, info: info)
        } else {
            let titleView = ProfileNavigationBarTitleView()
            
            titleView.configure(name: name, info: info)
            
            self.navigationBarTitleView = titleView
            
            if let controller = self.controller {
                controller.navigationItem.titleView = titleView
            }
        }

        // Важно: после загрузки titleView НЕ должен появляться мгновенно.
        // Делаем состояние консистентным сразу после конфигурации.
        if !titleVisibilityActivated {
            navigationBarTitleView?.alpha = 0.0
        }
        updateNavigationBarTitleVisibility()
    }
    
    // Обновление титула NavigationBar
    private func updateNavigationBarTitleVisibility() {
        guard let titleView = navigationBarTitleView,
              let (_, navigationBarHeight) = self.containerLayout else { return }

        // Пока мы не активировали механику появления заголовка (после загрузки данных),
        // держим его скрытым — он должен появляться только при скролле.
        guard titleVisibilityActivated else {
            if titleView.alpha != 0.0 {
                titleView.alpha = 0.0
            }
            return
        }
        
        let offsetY = scrollView.contentOffset.y
        
        let headerBottomPoint = fixedProfileHeaderHeight - navigationBarHeight
        
        let startShowingOffset = headerBottomPoint - 40
        let fullyVisibleOffset = headerBottomPoint + 60
        
        var alpha: CGFloat = 0.0
        
        if offsetY < startShowingOffset {
            alpha = 0.0
        } else if offsetY >= fullyVisibleOffset {
            alpha = 1.0
        } else {
            alpha = (offsetY - startShowingOffset) / (fullyVisibleOffset - startShowingOffset)
        }
        
        if titleView.alpha != alpha {
            titleView.alpha = alpha
        }
    }
    
    // Активация анимации заголовка навбара
    private func activateTitleVisibility() {
        guard !titleVisibilityActivated else { return }
        titleVisibilityActivated = true
        
        // Принудительно обновляем layout, чтобы анимация заголовка заработала
        self.setNeedsLayout()
        self.layoutIfNeeded()

        // И сразу же пересчитываем видимость заголовка для текущего offset.
        updateNavigationBarTitleVisibility()
    }
    
    
    // MARK: - Internal
    
    func loadSimilarProfiles() {
        // TODO: Заменить на API запрос
        let mockProfiles: [SimilarProfileItem] = [
            SimilarProfileItem(id: 1, name: "KRISTINA REACH", info: "22 y.o · 🇺🇸 New York", avatarURL: nil),
            SimilarProfileItem(id: 2, name: "SARAH PARKER", info: "24 y.o · 🇬🇧 London", avatarURL: nil),
            SimilarProfileItem(id: 3, name: "JESSICA WONG", info: "21 y.o · 🇨🇦 Toronto", avatarURL: nil),
            SimilarProfileItem(id: 4, name: "EMMA STONE", info: "26 y.o · 🇺🇸 Los Angeles", avatarURL: nil),
            SimilarProfileItem(id: 5, name: "OLIVIA WILD", info: "23 y.o · 🇦🇺 Sydney", avatarURL: nil)
        ]
        
        appendSimilarProfiles(mockProfiles, totalCount: mockProfiles.count)
    }
    
    // Обновляем Layout после загрузки контроллера
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        navigationBarTitleHeightConstraint.isActive = false
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: navigationBarHeight)
        navigationBarTitleHeightConstraint.isActive = true
        contentViewStack.setCustomSpacing((-235 - navigationBarHeight), after: headerContainer)
        
        applyGradientBlurMask()
        
        updateAllCollectionViewHeights(layout: layout)
        updateCollectionsContainerHeight(animated: false)
        
        galleryCollectionView.collectionViewLayout.invalidateLayout()
        videoGalleryCollectionView.collectionViewLayout.invalidateLayout()
        channelGalleryCollectionView.collectionViewLayout.invalidateLayout()
        modelGalleryCollectionView.collectionViewLayout.invalidateLayout()
        eventGalleryCollectionView.collectionViewLayout.invalidateLayout()
        
        updateNavigationBarTitleVisibility()
        
        self.layoutIfNeeded()
    }
    
    // Обновление профиля, после загрузки baseURL/user/userId
    func updateWithUserDetail(_ detail: UserDetail, _ isMyProfile: Bool) {
        var bio: String
        var appearance: [AppearanceAttribute]
        
        if !isMyProfile {
            similarProfilesCollectionContainer.isHidden = false
            dmButton.isHidden = false
            setupDmButtonContent()
            titleEditContainer.removeFromSuperview()
        } else {
            titleEditContainer.isHidden = false
        }
        
        if detail.role == "agency_employee" {
            self.modelRole = "agency_employee"
            setupNavigationBarTitle(name: detail.agency?.title ?? "No name")
            
            if let photoURLString = detail.agency?.photo?.fullUrl, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
                headerImageView.loadImage(from: photoURL)
            }
            
            bio = (detail.agency?.description?.isEmpty == false)
            ? (detail.agency?.description ?? "")
            : Self.mockBiographyText
            
            profileInfoView.update(biography: bio)
            currentAgencyContainer.removeFromSuperview()
            segmentedBar.configure(isAgency: true, isMyProfile: isMyProfile)
        } else {
            self.modelRole = "model"
            let age = detail.birthday.flatMap { calculateAge(from: $0) } ?? 0
            setupNavigationBarTitle(name: detail.fullName ?? "No name", info: "\(age) y.o • \(detail.city?.name ?? "")")
            
            if let photoURLString = detail.photo?.fullUrl, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
                headerImageView.loadImage(from: photoURL)
            }
            
            bio = (detail.model?.additionalInformation?.isEmpty == false)
            ? (detail.model?.additionalInformation ?? "")
            :  (isMyProfile ? Self.mockBiographyMyProfileText : Self.mockBiographyText)
            
            appearance = buildAppearanceList(from: detail.model?.appearance, gender: detail.gender)
            
            profileInfoView.update(biography: bio, appearance: appearance)
            if detail.model?.agency == nil {
                currentAgencyContainer.removeFromSuperview()
            } else {
                let logoURLString = detail.model?.agency?.photo?.fullUrl
                let logoURL = logoURLString != nil ? URL(string: logoURLString!) : nil
                currentAgencyView.configure(name: detail.model?.agency?.title, logoURL: logoURL)
            }
            segmentedBar.configure(isAgency: false, isMyProfile: isMyProfile)
        }
        
        if let avatarURLString = detail.avatar?.fullUrl {
            if let avatarURL = CDNURLHelper.convertToCDNURL(avatarURLString) {
                ImageLoader.shared.load(url: avatarURL) { [weak self] image in
                    if let image = image {
                        self?.profileHeaderView.changeAvatar(with: image)
                    }
                }
            }
        }
        
        let stats = detail.statistic
        // Обновляем экшен-блок без пересоздания subviews, чтобы не было «дерганья» после загрузки
        UIView.performWithoutAnimation {
            setupCounterView(likesView, count: "\(stats?.followersCount ?? 0)", name: "Like", iconName: "Instant View/Favorite")
            setupCounterView(viewsView, count: "\(stats?.viewsCount ?? 0)", name: "Viewed", iconName: "Instant View/Visibility")
            setupCounterView(savesView, count: "\(stats?.followingCount ?? 0)", name: "Save", iconName: "Instant View/Bookmark")
            self.counterActionsContainer.layoutIfNeeded()
        }
        // что такое Save в модели?
        
//        let socialIcons = ["Models/instaIcon", "Models/TikTokIcon", "Models/youtubeIcon", "Models/webIcon"]
//        let networks = detail.userSocialNetworks ?? []
//        let handlesFromApi = networks.compactMap { network -> String? in
//            let handle = network.username ?? network.url ?? ""
//            return handle.isEmpty ? nil : handle
//        }
//        let handles = handlesFromApi.isEmpty ? ["instagram", "tiktok", "youtube", "website"] : handlesFromApi
        
        let socialIcons = ["Models/instaIcon", "Models/TikTokIcon", "Models/youtubeIcon", "Models/webIcon"]
        let networks = detail.userSocialNetworks ?? []
        let handlesFromApi = networks.compactMap { network -> String? in
            let handle = network.username ?? network.url ?? ""
            return handle.isEmpty ? nil : handle
        }
        let handles = handlesFromApi
        
        populateSocialMedia(handles: handles, icons: socialIcons)
        
        stopShimmers()
        activateTitleVisibility()
        
        // Теперь устанавливаем информацию профиля после того, как шиммеры скрыты
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if detail.role == "agency_employee" {
                let viewModel = UserProfileViewModel(
                    name: detail.agency?.title ?? "No name",
                    age: nil,
                    location: detail.agency?.address?.city?.name ?? "",
                    countryFlag: Self.flag(for: detail.agency?.address?.city?.countryCode),
                    jobTitle: detail.role?.lowercased() ?? "model",
                    avatarImage: nil,
                    isPremium: true,
                    isOnline: true
                )
                self.profileHeaderView.configure(with: viewModel)
            } else {
                let age = detail.birthday.flatMap { self.calculateAge(from: $0) } ?? 0
                let viewModel = UserProfileViewModel(
                    name: detail.fullName ?? "No name",
                    age: age,
                    location: detail.city?.name ?? "",
                    countryFlag: Self.flag(for: detail.city?.countryCode),
                    jobTitle: detail.role ?? "model",
                    avatarImage: nil,
                    isPremium: true,
                    isOnline: true
                )
                self.profileHeaderView.configure(with: viewModel)
            }
        }
    }
    
    // Добавление фотографий в галерею пагинацией
    func appendGalleryPhotos(_ photos: UserPhotos, isMyProfile: Bool) {
        let newPhotos = photos.items
        let totalCount = photos.pagination.meta.totalCount
        let serverOffset = photos.pagination.meta.currentOffset
        
        if !galleryInitialized {
            self.galleryPhotos = []
            galleryInitialized = true
            // debug: pagination logs removed
        }
        
        let previousCount = self.galleryPhotos.count
        self.galleryPhotos.append(contentsOf: newPhotos)
        
        self.galleryCurrentOffset = serverOffset
        self.galleryHasMore = self.galleryPhotos.count < totalCount
        self.galleryIsLoading = false
        
        // debug: pagination logs removed
        
        if previousCount == 0 {
            let hasPhotos = !self.galleryPhotos.isEmpty
            self.galleryStatusView.isHidden = hasPhotos
            if isMyProfile {
                self.galleryStatusView.configure(isLoading: false, text: "Upload your photos", isMyProfile: true)
            } else {
                self.galleryStatusView.configure(isLoading: false, text: "No videos yet", isMyProfile: false)
            }
            self.galleryCollectionView.isHidden = !hasPhotos
            self.galleryCollectionView.reloadData()
            
            if let layout = self.containerLayout?.0 {
                self.updateAllCollectionViewHeights(layout: layout)
                if self.currentTabIndex == 0 { self.updateCollectionsContainerHeight(animated: true) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.checkAndLoadMoreGalleryPhotos()
            }
        } else {
            let newIndices = (previousCount..<(previousCount + newPhotos.count)).map { IndexPath(item: $0, section: 0) }
            self.galleryCollectionView.performBatchUpdates({
                self.galleryCollectionView.insertItems(at: newIndices)
                if let layout = self.containerLayout?.0 {
                    self.updateAllCollectionViewHeights(layout: layout)
                    if self.currentTabIndex == 0 { self.updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { [weak self] _ in
                self?.checkAndLoadMoreGalleryPhotos()
            })
        }
    }
    
    // Обновление высоты коллекции галереи
    private func updateGalleryCollectionViewHeight() {
        guard let (layout, _) = self.containerLayout else { return }
        
        let itemsPerRow: CGFloat = 3
        let spacing: CGFloat = 1
        let totalWidth = layout.size.width
        let itemWidth = (totalWidth - 2 * spacing) / itemsPerRow
        
        let totalItems = galleryPhotos.count
        let rows = ceil(CGFloat(totalItems) / itemsPerRow)
        let galleryHeight = rows * itemWidth + (rows - 1) * spacing
        
        galleryCollectionView.constraints.filter({ $0.firstAttribute == .height }).forEach({ $0.isActive = false })
        galleryCollectionView.heightAnchor.constraint(equalToConstant: galleryHeight).isActive = true
        
        galleryCollectionView.layoutIfNeeded()
    }
    
    // Сброс пагинации галереи
    func resetGalleryPagination() {
        galleryPhotos = []
        galleryCurrentOffset = 0
        galleryIsLoading = false
        galleryHasMore = true
        galleryInitialized = false
        // debug: removed
    }
    
    // Флаг загрузки галереи
    func setGalleryLoading(_ loading: Bool) {
        galleryIsLoading = loading
        // debug: removed
    }
    
    // Проверка, есть ли еще фотографии на бэке для загрузки в галереи
    func checkAndLoadMoreGalleryPhotos() {
        guard galleryHasMore && !galleryIsLoading else { return }
        
        galleryCollectionView.layoutIfNeeded()
        
        let contentHeight = galleryCollectionView.contentSize.height
        let frameHeight = galleryCollectionView.frame.size.height
        
        if contentHeight <= frameHeight {
            loadNextGalleryPage()
        }
    }
    
    // Вызов нового запроса на загрузку фотографий
    func loadNextGalleryPage() {
        guard !galleryIsLoading && galleryHasMore, let userId = model.userId else { return }
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.loadGalleryPage(userId: userId, offset: galleryCurrentOffset)
        }
    }
    
    // MARK: - Video Gallery Methods
    
    // Загрузка видео галереи
    func loadVideoGallery() {
        guard let userId = model.userId else { return }

        // Первый запрос всегда offset=0. Ставим флаг загрузки и фиксируем offset,
        // чтобы быстрый скролл не инициировал второй параллельный запрос.
        videoGalleryIsLoading = true
        videoGalleryRequestedOffsets.insert(0)
        videoGalleryLastRequestedOffset = 0
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.loadVideoGalleryPage(userId: userId, offset: 0)
        }
    }
    
    // Добавление элементов видео галереи из API
    func appendVideoGalleryItems(_ items: [UserVideoItem], pagination: Meta, isMyProfile: Bool) {
        let previousCount = videoGalleryItems.count

        let validVideoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "webm"]
        let validPreviewExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "heic"]

        let photoItems: [UserPhoto] = items.compactMap { item in
            // Ищем именно видео-файл, а не "первый попавшийся".
            let videoFile = item.files.first(where: { file in
                guard let ext = file.fileExtension?.lowercased() else { return false }
                return validVideoExtensions.contains(ext)
            })

            guard let videoFile else { return nil }

            // Превью может быть отдельным файлом в item.files
            let previewFile = item.files.first(where: { file in
                guard let ext = file.fileExtension?.lowercased() else { return false }
                return validPreviewExtensions.contains(ext)
            })

            let previewUserFile: UserFile? = previewFile.map {
                UserFile(
                    fileName: $0.fileName,
                    fullUrl: $0.fullUrl,
                    fileExtension: $0.fileExtension,
                    fileUuid: $0.fileUuid
                )
            }

            return UserPhoto(
                id: item.id,
                photo: UserFile(
                    fileName: videoFile.fileName,
                    fullUrl: videoFile.fullUrl,
                    fileExtension: videoFile.fileExtension,
                    fileUuid: videoFile.fileUuid
                ),
                likesCount: item.likesCount,
                isLikedByUser: item.isLikedByUser,
                preview: previewUserFile
            )
        }

        // 1) Дедуп входящих элементов (API иногда может вернуть пересекающиеся страницы,
        // а также мы должны быть устойчивы к повторному запросу одного offset)
        let existingIds = Set(videoGalleryItems.map { $0.id })
        let uniquePhotoItems = photoItems.filter { !existingIds.contains($0.id) }

        videoGalleryItems.append(contentsOf: uniquePhotoItems)

        // 2) Offset: у API может быть два варианта:
        // - currentOffset == offset из запроса (классический offset)
        // - currentOffset == nextOffset (курсор-подобное поведение)
        // Чтобы не гадать, ориентируемся на то, совпадает ли currentOffset с тем, что мы запрашивали.
        videoGalleryTotalCount = pagination.totalCount
        let nextOffset: Int
        if let lastRequested = videoGalleryLastRequestedOffset, pagination.currentOffset == lastRequested {
            // Классический offset: следующий = offset + количество элементов, которое вернул сервер.
            // Используем items.count (а не uniquePhotoItems.count), чтобы pagination не ломалась
            // из-за фильтрации по расширению / дедупликации.
            nextOffset = pagination.currentOffset + items.count
        } else {
            // Если сервер уже вернул nextOffset — используем его напрямую.
            nextOffset = pagination.currentOffset
        }
        videoGalleryCurrentOffset = nextOffset

        videoGalleryHasMore = videoGalleryItems.count < pagination.totalCount
        videoGalleryIsLoading = false

        // debug: pagination logs removed
                
        if previousCount == 0 {
            let hasVideos = !self.videoGalleryItems.isEmpty
            self.videoGalleryStatusView.isHidden = hasVideos
            if isMyProfile {
                self.videoGalleryStatusView.configure(isLoading: false, text: "Upload your videos", isMyProfile: true)
            } else {
                self.videoGalleryStatusView.configure(isLoading: false, text: "No videos yet", isMyProfile: false)
            }
            self.videoGalleryCollectionView.isHidden = !hasVideos
            self.videoGalleryCollectionView.reloadData()
            
            if let layout = self.containerLayout?.0 {
                self.updateAllCollectionViewHeights(layout: layout)
                if self.currentTabIndex == 1 { self.updateCollectionsContainerHeight(animated: true) }
            }
            // Важно: не инициируем автоматическую цепочку подгрузки страниц здесь.
            // Иначе при большом контенте можно быстро выкачать все страницы,
            // что приводит к большому количеству ячеек/AVPlayer и фризам.
        } else if !uniquePhotoItems.isEmpty {
            let newIndices = (previousCount..<(previousCount + uniquePhotoItems.count)).map { IndexPath(item: $0, section: 0) }
            self.videoGalleryCollectionView.performBatchUpdates({
                self.videoGalleryCollectionView.insertItems(at: newIndices)
                if let layout = self.containerLayout?.0 {
                    self.updateAllCollectionViewHeights(layout: layout)
                    if self.currentTabIndex == 1 { self.updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { _ in
                // Пагинацию триггерим только через основной scrollViewDidScroll threshold.
            })
        } else {
            // Пагинацию триггерим только через основной scrollViewDidScroll threshold.
        }
    }
    
    // Обновление высоты видео галереи
    func updateVideoGalleryCollectionViewHeight() {
        guard let (layout, _) = self.containerLayout else { return }
        
        let itemsPerRow: CGFloat = 3
        let spacing: CGFloat = 1
        let totalWidth = layout.size.width
        let itemWidth = (totalWidth - 2 * spacing) / itemsPerRow
        
        let totalItems = videoGalleryItems.count
        let rows = ceil(CGFloat(totalItems) / itemsPerRow)
        let galleryHeight = rows * itemWidth + (rows - 1) * spacing
        
        videoGalleryCollectionView.constraints.filter({ $0.firstAttribute == .height }).forEach({ $0.isActive = false })
        videoGalleryCollectionView.heightAnchor.constraint(equalToConstant: galleryHeight).isActive = true
        
        videoGalleryCollectionView.layoutIfNeeded()
    }
    
    // NOTE: checkAndLoadMoreVideoGallery() intentionally removed.
    
    // Загрузка следующей страницы видео
    func loadNextVideoGalleryPage() {
        guard !videoGalleryIsLoading && videoGalleryHasMore, let userId = model.userId else { return }

        // Гейт от повторного запроса той же страницы.
        // Это защищает от ситуаций, когда несколько scroll событий подряд вызывают пагинацию.
        let offset = videoGalleryCurrentOffset
        guard !videoGalleryRequestedOffsets.contains(offset) else { return }
        videoGalleryRequestedOffsets.insert(offset)
        videoGalleryLastRequestedOffset = offset

        videoGalleryIsLoading = true
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.loadVideoGalleryPage(userId: userId, offset: offset)
        }
    }

    /// Вызвать при ошибке запроса, чтобы разрешить повторную попытку загрузки этой страницы.
    func videoGalleryRequestDidFail(offset: Int) {
        videoGalleryIsLoading = false
        videoGalleryRequestedOffsets.remove(offset)
    }
    
    // Сброс пагинации видео галереи
    func resetVideoGalleryPagination() {
        videoGalleryItems = []
        videoGalleryTotalCount = 0
        videoGalleryCurrentOffset = 0
        videoGalleryIsLoading = false
        videoGalleryHasMore = true
        videoGalleryRequestedOffsets.removeAll()
        videoGalleryLastRequestedOffset = nil
        // debug: pagination logs removed
    }
    
    // Флаг загрузки галереи видео
    func setVideoGalleryLoading(_ loading: Bool) {
        videoGalleryIsLoading = loading
        // debug: removed
    }
    
    
    // MARK: - Channels Gallery Methods
    
    // Загрузка галереи каналов
    func loadChannelGallery() {
        // guard let userId = model.userId else { return }
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.loadTelegramChannels()
        }
    }
    
    // Обновление галереи каналов
    func updateChannelsList(_ items: [ProfileChannelItem]) {
        self.channelGalleryItems = items
        let hasItems = !items.isEmpty
        self.channelGalleryStatusView.isHidden = hasItems
        self.channelGalleryCollectionView.isHidden = !hasItems
        self.channelGalleryCollectionView.reloadData()
        
        if let layout = self.containerLayout?.0 {
            self.updateAllCollectionViewHeights(layout: layout)
            // Индекс каналов зависит от роли
            let channelIndex = (modelRole == "model") ? 2 : 3
            if self.currentTabIndex == channelIndex { self.updateCollectionsContainerHeight(animated: true) }
        }
    }
    
    // Загрузка высоты галереи каналов
    private func updateChannelsCollectionViewHeight() {
        let channelCellHeight: CGFloat = 76.0
        let channelsHeight = CGFloat(channelGalleryItems.count) * channelCellHeight
        
        channelGalleryCollectionView.constraints.filter({ $0.firstAttribute == .height }).forEach({ $0.isActive = false })
        channelGalleryCollectionView.heightAnchor.constraint(equalToConstant: max(channelsHeight, 1.0)).isActive = true
        channelGalleryCollectionView.layoutIfNeeded()
        
        // debug: removed
    }
    
    
    // MARK: - Models Gallery Methods
    
    // Загрузка галереи моделей
    func loadModelGallery() {
        // guard let userId = model.userId else { return }
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.loadModels()
        }
    }
    
    // Обновление галереи моделей
    func updateModelsList(_ items:[ModelItem]) {
        self.modelGalleryItems = items
        let hasItems = !items.isEmpty
        self.modelGalleryStatusView.isHidden = hasItems
        self.modelGalleryCollectionView.isHidden = !hasItems
        self.modelGalleryCollectionView.reloadData()
        
        if let layout = self.containerLayout?.0 {
            self.updateAllCollectionViewHeights(layout: layout)
            if self.currentTabIndex == 2 { self.updateCollectionsContainerHeight(animated: true) }
        }
    }
    
    // Загрузка высоты галереи моделей
    private func updateModelsCollectionViewHeight() {
        let modelCellHeight: CGFloat = 76.0
        let modelsHeight = CGFloat(modelGalleryItems.count) * modelCellHeight
        
        modelGalleryCollectionView.constraints.filter({ $0.firstAttribute == .height }).forEach({ $0.isActive = false })
        modelGalleryCollectionView.heightAnchor.constraint(equalToConstant: max(modelsHeight, 1.0)).isActive = true
        modelGalleryCollectionView.layoutIfNeeded()
        
        // debug: removed
    }
    
    
    // MARK: - Events Gallery Methods
    
    // Загрузка галереи событий
    func loadEventGallery() {
        // guard let userId = model.userId else { return }
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.loadEvents()
        }
    }
    
    // Обновление галереи событий
    func updateEventsList(_ items: [EventItem]) {
        self.eventGalleryItems = items
        let hasItems = !items.isEmpty
        self.eventGalleryStatusView.isHidden = hasItems
        self.eventGalleryCollectionView.isHidden = !hasItems
        self.eventGalleryCollectionView.reloadData()
        
        if let layout = self.containerLayout?.0 {
            self.updateAllCollectionViewHeights(layout: layout)
            if self.currentTabIndex == 4 { self.updateCollectionsContainerHeight(animated: true) }
        }
    }
    
    // Загрузка высоты галереи событий
    private func updateEventsCollectionViewHeight() {
        let eventCellHeight: CGFloat = 76.0
        let eventsHeight = CGFloat(modelGalleryItems.count) * eventCellHeight
        
        eventGalleryCollectionView.constraints.filter({ $0.firstAttribute == .height }).forEach({ $0.isActive = false })
        eventGalleryCollectionView.heightAnchor.constraint(equalToConstant: max(eventsHeight, 1.0)).isActive = true
        eventGalleryCollectionView.layoutIfNeeded()
        
        // debug: removed
    }
    
    
    // MARK: - Dynamic Height Calculation
    
    private func updateAllCollectionViewHeights(layout: ContainerViewLayout) {
        let itemsPerRow: CGFloat = 3
        let spacing: CGFloat = 1
        let totalWidth = layout.size.width
        let itemWidth = (totalWidth - 2 * spacing) / itemsPerRow
        
        // Photo
        let pRows = ceil(CGFloat(galleryPhotos.count) / itemsPerRow)
        let pHeight = pRows * itemWidth + max(0, pRows - 1) * spacing
        galleryHeightConstraint.constant = max(pHeight, 1.0)
        
        // Video
        let vRows = ceil(CGFloat(videoGalleryItems.count) / itemsPerRow)
        let vHeight = vRows * itemWidth + max(0, vRows - 1) * spacing
        videoHeightConstraint.constant = max(vHeight, 1.0)
        
        // Channels
        let cHeight = CGFloat(channelGalleryItems.count) * 76.0
        channelHeightConstraint.constant = max(cHeight, 1.0)
        
        // Models
        let mHeight = CGFloat(modelGalleryItems.count) * 76.0
        modelHeightConstraint.constant = max(mHeight, 1.0)
        
        // Events
        let eHeight = CGFloat(eventGalleryItems.count) * 76.0
        eventHeightConstraint.constant = max(eHeight, 1.0)
    }
    
    private func updateCollectionsContainerHeight(animated: Bool = true) {
        func heightFor(isEmpty: Bool, constraint: NSLayoutConstraint) -> CGFloat {
            if isEmpty { return 160 }
            return constraint.constant
        }
        
        let newHeight: CGFloat
        
        if model.isMyProfile {
            switch currentTabIndex {
            case 0: newHeight = heightFor(isEmpty: galleryPhotos.isEmpty, constraint: galleryHeightConstraint)
            case 1: newHeight = heightFor(isEmpty: videoGalleryItems.isEmpty, constraint: videoHeightConstraint)
            default: newHeight = 160
            }
        } else if (modelRole == "model" || modelRole == "new_face") && !model.isMyProfile {
            switch currentTabIndex {
            case 0: newHeight = heightFor(isEmpty: galleryPhotos.isEmpty, constraint: galleryHeightConstraint)
            case 1: newHeight = heightFor(isEmpty: videoGalleryItems.isEmpty, constraint: videoHeightConstraint)
            case 2: newHeight = heightFor(isEmpty: channelGalleryItems.isEmpty, constraint: channelHeightConstraint)
            default: newHeight = 160
            }
        } else {
            switch currentTabIndex {
            case 0: newHeight = heightFor(isEmpty: galleryPhotos.isEmpty, constraint: galleryHeightConstraint)
            case 1: newHeight = heightFor(isEmpty: videoGalleryItems.isEmpty, constraint: videoHeightConstraint)
            case 2: newHeight = heightFor(isEmpty: modelGalleryItems.isEmpty, constraint: modelHeightConstraint)
            case 3: newHeight = heightFor(isEmpty: channelGalleryItems.isEmpty, constraint: channelHeightConstraint)
            case 4: newHeight = heightFor(isEmpty: eventGalleryItems.isEmpty, constraint: eventHeightConstraint)
            default: newHeight = 160
            }
        }
        
        collectionsContainerHeightConstraint.constant = newHeight
        
        // Мы отключили анимацию, если пользователь активно скроллит (чтобы не было рывков)
        if animated && !scrollView.isDragging && !scrollView.isDecelerating {
            UIView.animate(withDuration: 0.3) {
                self.contentViewStack.layoutIfNeeded()
                self.view.layoutIfNeeded()
            }
        } else {
            self.view.layoutIfNeeded()
        }
    }
    
    
    // MARK: - @objc
    
    @objc private func dmButtonTapped() {
        
    }
    
    @objc private func handleTouchDown(_ sender: UIControl) {
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 0.6
        })
    }
    
    @objc private func handleTouchUp(_ sender: UIControl) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            sender.transform = .identity
            sender.alpha = 1.0
        })
    }
    
    @objc private func likesViewDidTap() {
        onLikesTapped?()
    }
    
    @objc private func viewsViewDidTap() {
        onViewsTapped?()
    }
    
    @objc private func savesViewDidTap() {
        onSavesTapped?()
    }
}


// MARK: - UICollectionViewDataSource

extension PublicProfileScreenNode: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == galleryCollectionView {
            return galleryPhotos.count
        } else if collectionView == videoGalleryCollectionView {
            return videoGalleryItems.count
        } else if collectionView == similarProfilesCollectionView {
            return similarProfiles.count
        } else if collectionView == channelGalleryCollectionView {
            return channelGalleryItems.count
        } else if collectionView == modelGalleryCollectionView {
            return modelGalleryItems.count
        } else if collectionView == eventGalleryCollectionView {
            return eventGalleryItems.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == similarProfilesCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SimilarProfileCell.reuseIdentifier, for: indexPath) as? SimilarProfileCell else {
                return UICollectionViewCell()
            }
            let profile = similarProfiles[indexPath.item]
            cell.configure(with: profile)
            return cell
        } else if collectionView == galleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCell", for: indexPath) as? GalleryCell else {
                return UICollectionViewCell()
            }
            let photoItem = galleryPhotos[indexPath.item]
            
            if let previewUrlString = photoItem.preview?.fullUrl, let url = CDNURLHelper.convertToCDNURL(previewUrlString) {
                cell.configure(with: url)
            } else {
                if let fullUrlString = photoItem.photo.fullUrl, let url = CDNURLHelper.convertToCDNURL(fullUrlString) {
                    cell.configure(with: url)
                }
            }
            
            return cell
        } else if collectionView == videoGalleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoGalleryCell.reuseIdentifier, for: indexPath) as? VideoGalleryCell else {
                return UICollectionViewCell()
            }
            let videoItem = videoGalleryItems[indexPath.item]
            
            if let videoUrlString = videoItem.photo.fullUrl {
                let cdnVideoUrl = CDNURLHelper.convertToCDN(videoUrlString) ?? ""
                let previewUrl = videoItem.preview?.fullUrl.flatMap { CDNURLHelper.convertToCDN($0) }
                cell.configure(with: cdnVideoUrl, previewUrl: previewUrl, title: nil)
            }
            
            return cell
        } else if collectionView == channelGalleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChannelListCell.reuseIdentifier, for: indexPath) as? ChannelListCell else {
                return UICollectionViewCell()
            }
            let item = channelGalleryItems[indexPath.item]
            cell.configure(with: item, context: self.context)
            return cell
        } else if collectionView == modelGalleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ModelListCell.reuseIdentifier, for: indexPath) as? ModelListCell else {
                return UICollectionViewCell()
            }
            let item = modelGalleryItems[indexPath.item]
            cell.configure(with: item, context: self.context)
            return cell
        } else if collectionView == eventGalleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EventListCell.reuseIdentifier, for: indexPath) as? EventListCell else {
                return UICollectionViewCell()
            }
            let item = eventGalleryItems[indexPath.item]
            cell.configure(with: item, context: self.context)
            return cell
        }
        return UICollectionViewCell()
    }
}


// MARK: - UICollectionViewDelegate

extension PublicProfileScreenNode: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == similarProfilesCollectionView {
            _ = similarProfiles[indexPath.item]
            // debug: removed
            // TODO: Открыть профиль выбранного пользователя
            // handleSimilarProfileTap(profile)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if collectionView == videoGalleryCollectionView,
           let videoCell = cell as? VideoGalleryCell {
            // Тяжёлый fallback (first-frame) запускаем только для реально видимых ячеек.
            videoCell.willDisplay()
            videoCell.play()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if collectionView == videoGalleryCollectionView,
           let videoCell = cell as? VideoGalleryCell {
            videoCell.stopAndReleasePlayer()
        }
    }
}


// MARK: - UICollectionViewDelegateFlowLayout

extension PublicProfileScreenNode: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == similarProfilesCollectionView {
            return CGSize(width: 166, height: 200)
        } else if collectionView == galleryCollectionView || collectionView == videoGalleryCollectionView {
            guard let (layout, _) = self.containerLayout else { return .zero }
            let totalSpacing: CGFloat = 2
            let width = (layout.size.width - totalSpacing) / 3.0
            return CGSize(width: width, height: width)
        } else if collectionView == channelGalleryCollectionView
                    || collectionView == modelGalleryCollectionView
                    || collectionView == eventGalleryCollectionView {
            guard let (layout, _) = self.containerLayout else { return .zero }
            return CGSize(width: layout.size.width, height: 74)
        }
        return CGSize()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        if collectionView == similarProfilesCollectionView {
            return 6
        } else if collectionView == galleryCollectionView
                    || collectionView == videoGalleryCollectionView
                    || collectionView == channelGalleryCollectionView
                    || collectionView == modelGalleryCollectionView
                    || collectionView == eventGalleryCollectionView {
            return 1.0
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        if collectionView == similarProfilesCollectionView {
            return 6
        } else if collectionView == galleryCollectionView
                    || collectionView == videoGalleryCollectionView
                    || collectionView == channelGalleryCollectionView
                    || collectionView == modelGalleryCollectionView
                    || collectionView == eventGalleryCollectionView {
            return 1.0
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if collectionView == similarProfilesCollectionView {
            return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        } else if collectionView == galleryCollectionView
                    || collectionView == videoGalleryCollectionView
                    || collectionView == channelGalleryCollectionView
                    || collectionView == modelGalleryCollectionView
                    || collectionView == eventGalleryCollectionView {
            return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}


// MARK: - UIScrollViewDelegate

extension PublicProfileScreenNode: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        let offsetY = scrollView.contentOffset.y
        
        // ПРАВИЛЬНЫЙ РАСЧЕТ ПАГИНАЦИИ (относительно основного скролла)
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.bounds.height
        
        // Триггер: за 500 пикселей до конца экрана
        let threshold = contentHeight - frameHeight - 500
        
        if offsetY > threshold {
            triggerLoadMoreForActiveTab()
        }
        
        updateSegmentedBarPosition()
        updateNavigationBarTitleVisibility()
        
        // Защита от скролла ниже контента
        let maxScrollY = scrollView.contentSize.height - scrollView.bounds.height
        let bottomLimit = max(0, maxScrollY)
        
        if scrollView.contentOffset.y > bottomLimit {
            scrollView.contentOffset.y = bottomLimit
        }
    }
    
    // Менеджер загрузки для текущей вкладки
    private func triggerLoadMoreForActiveTab() {
        if model.isMyProfile {
            switch currentTabIndex {
            case 0:
                if galleryHasMore && !galleryIsLoading { loadNextGalleryPage() }
            case 1:
                if videoGalleryHasMore && !videoGalleryIsLoading { loadNextVideoGalleryPage() }
            default: break
            }
        } else if (modelRole == "model" || modelRole == "new_face") && !model.isMyProfile {
            switch currentTabIndex {
            case 0:
                if galleryHasMore && !galleryIsLoading { loadNextGalleryPage() }
            case 1:
                if videoGalleryHasMore && !videoGalleryIsLoading { loadNextVideoGalleryPage() }
            default: break
            }
        } else {
            switch currentTabIndex {
            case 0:
                if galleryHasMore && !galleryIsLoading { loadNextGalleryPage() }
            case 1:
                if videoGalleryHasMore && !videoGalleryIsLoading { loadNextVideoGalleryPage() }
                // Модели, каналы, эвенты - добавить пагинацию по аналогии
            default: break
            }
        }
    }
}


// MARK: - ProfileInfoViewDelegate

extension PublicProfileScreenNode: ProfileInfoViewDelegate {
    func profileInfoViewDidUpdateContentHeight() {
        DispatchQueue.main.async {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }
}


// MARK: - ProfileSegmentedBarDelegate

extension PublicProfileScreenNode: ProfileSegmentedBarDelegate {
    
    private func getTabContainer(for index: Int) -> UIView {
        if model.isMyProfile {
            switch index {
            case 0: return photoTabContainer
            case 1: return videoTabContainer
            default: return photoTabContainer
            }
        } else if (modelRole == "model" || modelRole == "new_face") && !model.isMyProfile {
            switch index {
            case 0: return photoTabContainer
            case 1: return videoTabContainer
            case 2: return channelTabContainer
            default: return photoTabContainer
            }
        } else {
            switch index {
            case 0: return photoTabContainer
            case 1: return videoTabContainer
            case 2: return modelTabContainer
            case 3: return channelTabContainer
            case 4: return eventTabContainer
            default: return photoTabContainer
            }
        }
    }
    
    func segmentedBar(_ segmentedBar: ProfileSegmentedBar, didSelectIndex index: Int) {
        guard index != currentTabIndex else { return }
        // debug: removed
        
        let isSlidingLeft = index > currentTabIndex
        let screenWidth = self.view.bounds.width
        let offset = isSlidingLeft ? screenWidth : -screenWidth
        
        let oldContainer = getTabContainer(for: currentTabIndex)
        let newContainer = getTabContainer(for: index)
        
        newContainer.transform = CGAffineTransform(translationX: offset, y: 0)
        newContainer.isHidden = false
        
        loadDataForTab(index: index)
        
        currentTabIndex = index
        updateCollectionsContainerHeight(animated: false)
        
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseInOut, animations: {
            oldContainer.transform = CGAffineTransform(translationX: -offset, y: 0)
            newContainer.transform = .identity
            
            self.contentViewStack.layoutIfNeeded()
            self.view.layoutIfNeeded()
        }, completion: { _ in
            oldContainer.isHidden = true
            oldContainer.transform = .identity
        })
    }
    
    private func loadDataForTab(index: Int) {
        if model.isMyProfile {
            if index == 1 && !videoGalleryInitialized { videoGalleryInitialized = true; loadVideoGallery() }
        } else if (modelRole == "model" || modelRole == "new_face") && !model.isMyProfile {
            if index == 1 && !videoGalleryInitialized { videoGalleryInitialized = true; loadVideoGallery() }
            else if index == 2 && !channelGalleryInitialized { channelGalleryInitialized = true; loadChannelGallery() }
        } else {
            if index == 1 && !videoGalleryInitialized { videoGalleryInitialized = true; loadVideoGallery() }
            else if index == 2 && !modelGalleryInitialized { modelGalleryInitialized = true; loadModelGallery() }
            else if index == 3 && !channelGalleryInitialized { channelGalleryInitialized = true; loadChannelGallery() }
            else if index == 4 && !eventGalleryInitialized { eventGalleryInitialized = true; loadEventGallery() }
        }
    }
}


// MARK: - CurrentAgencyViewDelegate

extension PublicProfileScreenNode: CurrentAgencyViewDelegate {
    func didTapSeeHistory() {
        let historyController = WorkExperienceController(context: self.context, model: self.model)
        self.controller?.push(historyController)
    }
}
