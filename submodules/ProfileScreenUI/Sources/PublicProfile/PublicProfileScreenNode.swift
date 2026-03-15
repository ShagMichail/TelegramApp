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
    
    private let model: ProfileModel
    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private var navigationBarTitleView: ProfileNavigationBarTitleView?
    private var navigationBarTitleHeightConstraint: NSLayoutConstraint!
    
    private var headerHeightConstraint: NSLayoutConstraint!
    private var socialHeightConstraint: NSLayoutConstraint!
    private let iconPlaceholder = "Contact List/HeartActionIcon"
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
        return button
    }()
    
    private let likesView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let viewsView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let savesView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Callbacks for interactions sheet
    var onLikesTapped: (() -> Void)?
    var onViewsTapped: (() -> Void)?
    var onSavesTapped: (() -> Void)?
    
    
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
    
    
    // MARK: - Gallery Section
    
    private var galleryPhotos: [UserPhoto] = []
    private var galleryCurrentOffset: Int = 0
    private var galleryIsLoading: Bool = false
    private var galleryHasMore: Bool = true
    private var galleryInitialized: Bool = false
    private var galleryImageNames: [String] = []
    
    // Простое состояние для видео-галереи без пагинации как в dummy
    private var videoItems: [UserVideoItem] = []
    
    private func playVisibleVideos() {
        guard currentTabIndex == 1 else { return }
        for cell in galleryCollectionView.visibleCells {
            (cell as? VideoGalleryCell)?.play()
        }
    }
    
    private func stopVisibleVideos() {
        for cell in galleryCollectionView.visibleCells {
            (cell as? VideoGalleryCell)?.stop()
        }
    }
    
    private lazy var galleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "GalleryCell")
        collectionView.register(VideoGalleryCell.self, forCellWithReuseIdentifier: VideoGalleryCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let galleryStatusContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let galleryStatusView: GalleryStatusView = {
        let view = GalleryStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Tabs & Video/Collections state (simplified)
    
    private var currentTabIndex: Int = 0
    
    
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
        setupGallery()
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
            infoStack.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            infoStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
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
        contentViewStack.addArrangedSubview(socialMediaContainer)
        socialMediaContainer.addSubview(socialMediaStack)
        socialMediaContainer.addSubview(socialShimmerView)
        
        NSLayoutConstraint.activate([
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
    
    private func setupGallery() {
        contentViewStack.addArrangedSubview(galleryStatusContainer)
        galleryStatusContainer.addSubview(galleryStatusView)
        
        NSLayoutConstraint.activate([
            galleryStatusContainer.heightAnchor.constraint(equalToConstant: 160),
            
            galleryStatusView.topAnchor.constraint(equalTo: galleryStatusContainer.topAnchor),
            galleryStatusView.bottomAnchor.constraint(equalTo: galleryStatusContainer.bottomAnchor),
            galleryStatusView.leadingAnchor.constraint(equalTo: galleryStatusContainer.leadingAnchor, constant: 16),
            galleryStatusView.trailingAnchor.constraint(equalTo: galleryStatusContainer.trailingAnchor, constant: -16)
        ])
        
        contentViewStack.addArrangedSubview(galleryCollectionView)
        
        galleryCollectionView.isHidden = true
        galleryStatusContainer.isHidden = false
        galleryStatusView.configure(isLoading: true, text: "Uploading Photos...")
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
        
        contentViewStack.setCustomSpacing(-12, after: galleryCollectionView)
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
        
        navigationBarTitleView?.alpha = 0
        // если сделать тут, то из-за стека будет пролагивание вниз
        //        profileHeaderView.isHidden = false
        profileHeaderView.alpha = 0
        
        counterActionsStack.isHidden = false
        counterActionsStack.alpha = 0
        
        profileInfoView.isHidden = false
        profileInfoView.alpha = 0
        
        socialMediaStack.isHidden = false
        socialMediaStack.alpha = 0
        
        currentAgencyView.isHidden = false
        currentAgencyView.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseInOut, animations: {
            self.profileHeaderShimmerView.alpha = 0
            self.actionsShimmerView.alpha = 0
            self.profileInfoShimmerView.alpha = 0
            self.socialShimmerView.alpha = 0
            self.currentAgencyShimmerView.alpha = 0
            
            self.profileHeaderView.alpha = 1
            self.profileHeaderView.isHidden = false
            self.counterActionsStack.alpha = 1
            self.profileInfoView.alpha = 1
            self.socialMediaStack.alpha = 1
            self.currentAgencyView.alpha = 1
            
        }) { (completed) in
            if completed {
                self.profileHeaderShimmerView.isHidden = true
                self.actionsShimmerView.isHidden = true
                self.profileInfoShimmerView.isHidden = true
                self.socialShimmerView.isHidden = true
                self.currentAgencyShimmerView.isHidden = true
            }
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
        dmButton.subviews.forEach { $0.removeFromSuperview() }
        
        var iconImageName = "Chat/Context Menu/MessageBubble"
        var labelText = "Send DM"
        if model.isMyProfile {
            iconImageName = "Avatar/AddAvatarIconLarge"
            labelText = "Upload your photos"
        }
        
        let iconImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.image = UIImage(bundleImageName: iconImageName)?.withRenderingMode(.alwaysTemplate)
            imageView.tintColor = .white
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            return imageView
        }()
        
        let label: UILabel = {
            let label = UILabel()
            label.text = labelText
            label.textColor = .white
            label.font = Font.helveticaNeue(13)
            label.translatesAutoresizingMaskIntoConstraints = false
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
    private func setupCounterView(_ container: UIView, count: String, name: String, iconName: String) {
        container.subviews.forEach { $0.removeFromSuperview() }
        container.gestureRecognizers?.forEach { container.removeGestureRecognizer($0) }
        container.isUserInteractionEnabled = true
        
        let icon: UIImageView = {
            let imageView = UIImageView()
            imageView.image = UIImage(bundleImageName: iconName)?.withRenderingMode(.alwaysTemplate)
            imageView.tintColor = .white
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true
            return imageView
        }()
        
        let countLabel: UILabel = {
            let label = UILabel()
            label.text = count
            label.font = UIFont.boldSystemFont(ofSize: 14)
            label.textColor = .white
            return label
        }()
        
        let nameLabel: UILabel = {
            let label = UILabel()
            label.text = name
            label.font = UIFont.systemFont(ofSize: 10)
            label.textColor = .white
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
            return stack
        }()
        
        container.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            mainStack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 0),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: 0),
        ])
        
        // Tap handling for interactions
        let selector: Selector
        if container === likesView {
            selector = #selector(likesTapped)
        } else if container === viewsView {
            selector = #selector(viewsTapped)
        } else if container === savesView {
            selector = #selector(savesTapped)
        } else {
            return
        }
        let tap = UITapGestureRecognizer(target: self, action: selector)
        container.addGestureRecognizer(tap)
    }
    
    // Создание кнопок социальных сетей
    private func createSocialMediaButton(handle: String, iconName: String) -> UIView {
        let button = UIButton(type: .system)
        button.backgroundColor = .black.withAlphaComponent(0.12)
        button.layer.cornerRadius = 6
        
        let icon = UIImageView()
        icon.image = UIImage(bundleImageName: iconName)?.withRenderingMode(.alwaysTemplate)
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
        icon.image = UIImage(bundleImageName: iconName)?.withRenderingMode(.alwaysTemplate)
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
        
        print("👥 [SIMILAR] Загружено \(profiles.count) профилей. Всего: \(self.similarProfiles.count) из \(totalCount)")
        
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
        guard let appearance = appearance else { return [] }
        
        var items: [AppearanceAttribute] = []
        
        if let gender = gender {
            items.append(.init(title: "Gender", value: "\(gender.title)"))
        }
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
        let titleView = ProfileNavigationBarTitleView()
        
        titleView.configure(name: name, info: info)
        
        self.navigationBarTitleView = titleView
        
        if let controller = self.controller {
            controller.navigationItem.titleView = titleView
        }
    }
    
    // Обновление титула NavigationBar
    private func updateNavigationBarTitleVisibility() {
        guard let titleView = navigationBarTitleView,
              let (_, navigationBarHeight) = self.containerLayout else { return }
        
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
        
        if let flowLayout = galleryCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let itemsPerRow: CGFloat = 3
            let spacing: CGFloat = 1
            let totalWidth = layout.size.width
            let itemWidth = (totalWidth - 2 * spacing) / itemsPerRow
            
            let totalItems = galleryPhotos.count
            let rows = ceil(CGFloat(totalItems) / itemsPerRow)
            let galleryHeight = rows * itemWidth + (rows - 1) * spacing
            
            galleryCollectionView.constraints.filter({ $0.firstAttribute == .height }).forEach({ $0.isActive = false })
            galleryCollectionView.heightAnchor.constraint(equalToConstant: galleryHeight).isActive = true
            
            flowLayout.itemSize = CGSize(width: itemWidth, height: itemWidth)
            galleryCollectionView.collectionViewLayout.invalidateLayout()
        }
        
        updateNavigationBarTitleVisibility()
        
        self.layoutIfNeeded()
    }
    
    // Настройка показа галереи после загруки фотографий
    func updateGalleryState() {
        let hasPhotos = !galleryPhotos.isEmpty
        
        UIView.animate(withDuration: 0.3) {
            if hasPhotos {
                self.galleryStatusContainer.isHidden = true
                self.galleryCollectionView.isHidden = false
            } else {
                self.galleryStatusContainer.isHidden = true
                self.galleryCollectionView.isHidden = true
                self.segmentedBar.isHidden = true
                self.segmentedBarPlaceholder.isHidden = true
            }
            self.view.layoutIfNeeded()
        }
    }
    
    // Обновление профиля, после загрузки baseURL/user/userId
    func updateWithUserDetail(_ detail: UserDetail) {
        setupDmButtonContent()
        var bio: String
        var appearance: [AppearanceAttribute]
        
        if detail.role == "agency_employee" {
            setupNavigationBarTitle(name: detail.agency?.title ?? "No name")
            
            profileHeaderView.configure(with: UserProfileViewModel(
                name: detail.agency?.title ?? "No name",
                age: nil,
                location: detail.agency?.address?.city?.name ?? "",
                countryFlag: Self.flag(for: detail.agency?.address?.city?.countryCode),
                jobTitle: detail.roleLabel?.lowercased() ?? detail.role?.lowercased() ?? "model",
                avatarImage: nil,
                isPremium: true,
                isOnline: true
            ))
            
            if let photoURLString = detail.agency?.photo?.fullUrl, let photoURL = URL(string: photoURLString) {
                headerImageView.loadImage(from: photoURL)
            }
            
            bio = (detail.agency?.description?.isEmpty == false)
            ? (detail.agency?.description ?? "")
            : Self.mockBiographyText
            
            profileInfoView.update(biography: bio)
            currentAgencyContainer.removeFromSuperview()
            segmentedBar.configure(isAgency: true)
        } else {
            let age = detail.birthday.flatMap { calculateAge(from: $0) } ?? 0
            setupNavigationBarTitle(name: detail.fullName ?? "No name", info: "\(age) y.o • \(detail.city?.name ?? "")")
            profileHeaderView.configure(with: UserProfileViewModel(
                name: detail.fullName ?? "No name",
                age: age,
                location: detail.city?.name ?? "",
                countryFlag: Self.flag(for: detail.city?.countryCode),
                jobTitle: detail.roleLabel ?? detail.role ?? "model",
                avatarImage: nil,
                isPremium: true,
                isOnline: true
            ))
            
            if let photoURLString = detail.photo?.fullUrl, let photoURL = URL(string: photoURLString) {
                headerImageView.loadImage(from: photoURL)
            }
            
            bio = (detail.model?.additionalInformation?.isEmpty == false)
            ? (detail.model?.additionalInformation ?? "")
            : Self.mockBiographyText
            
            appearance = buildAppearanceList(from: detail.model?.appearance, gender: detail.gender)
            
            profileInfoView.update(biography: bio, appearance: appearance)
            if detail.model?.agency == nil {
                currentAgencyContainer.removeFromSuperview()
            } else {
                let logoURLString = detail.model?.agency?.photo?.fullUrl
                let logoURL = logoURLString != nil ? URL(string: logoURLString!) : nil
                currentAgencyView.configure(name: detail.model?.agency?.title, logoURL: logoURL)
            }
            segmentedBar.configure(isAgency: false)
        }
        
        if let avatarURLString = detail.avatar?.fullUrl, let avatarURL = URL(string: avatarURLString) {
            ImageLoader.shared.load(url: avatarURL) { [weak self] image in
                if let image = image {
                    self?.profileHeaderView.changeAvatar(with: image)
                }
            }
        }
        
        let stats = detail.statistic
        setupCounterView(likesView, count: "\(stats?.followersCount ?? 0)", name: "Like", iconName: "Chat/Input/Text/AccessoryIconReaction")
        setupCounterView(viewsView, count: "\(stats?.viewsCount ?? 0)", name: "Viewed", iconName: "Stories/EmbeddedViewIcon")
        setupCounterView(savesView, count: "\(stats?.followingCount ?? 0)", name: "Save", iconName: "Instant View/Bookmark")
        // что такое Save в модели?
        //        let socialIcons = ["Models/instaIcon", "Models/TikTokIcon", "Models/youtubeIcon", "Models/webIcon"]
        //        let networks = detail.userSocialNetworks ?? []
        //        let handlesFromApi = networks.compactMap { network -> String? in
        //            let handle = network.username ?? network.url ?? ""
        //            return handle.isEmpty ? nil : handle
        //    }
        //        let handles = handlesFromApi.isEmpty ? ["instagram", "tiktok", "youtube", "website"] : handlesFromApi
        
        let socialIcons = ["instaIcon", "TikTokIcon", "youtubeIcon", "webIcon"]
        let networks = detail.userSocialNetworks ?? []
        let handlesFromApi = networks.compactMap { network -> String? in
            let handle = network.username ?? network.url ?? ""
            return handle.isEmpty ? nil : handle
        }
        let handles = handlesFromApi.isEmpty ? ["instagram", "tiktok", "youtube", "website"] : handlesFromApi
        
        populateSocialMedia(handles: handles, icons: socialIcons)
        
        stopShimmers()
    }
    
    // Добавление фотографий в галерею пагинацией
    func appendGalleryPhotos(_ photos: UserPhotos) {
        let newPhotos = photos.items
        let totalCount = photos.pagination.meta.totalCount
        let serverOffset = photos.pagination.meta.currentOffset
        let serverLimit = photos.pagination.meta.limit
        
        if !galleryInitialized {
            self.galleryPhotos = []
            galleryInitialized = true
            print("🧹 [PAGINATION] Cleared galleryPhotos array (first load)")
        }
        
        let previousCount = self.galleryPhotos.count
        self.galleryPhotos.append(contentsOf: newPhotos)
        
        self.galleryCurrentOffset = serverOffset
        self.galleryHasMore = self.galleryPhotos.count < totalCount
        self.galleryIsLoading = false
        
        print("🖼️ [PAGINATION] Загружено \(newPhotos.count) фото")
        print("  - Server: offset=\(serverOffset), limit=\(serverLimit), total=\(totalCount)")
        print("  - Before: \(previousCount), After: \(self.galleryPhotos.count), Next offset: \(self.galleryCurrentOffset)")
        print("  - HasMore: \(self.galleryHasMore)")
        
        if previousCount == 0 {
            updateGalleryState()
            galleryCollectionView.reloadData()
            updateGalleryCollectionViewHeight()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.checkAndLoadMoreGalleryPhotos()
            }
        } else {
            let newIndices = (previousCount..<(previousCount + newPhotos.count)).map { IndexPath(item: $0, section: 0) }
            
            galleryCollectionView.performBatchUpdates({
                self.galleryCollectionView.insertItems(at: newIndices)
                self.updateGalleryCollectionViewHeight()
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
        videoItems = []
        galleryCurrentOffset = 0
        galleryIsLoading = false
        galleryHasMore = true
        galleryInitialized = false
        print("🔄 [PAGINATION] Reset gallery pagination state")
    }
    
    // Флаг загрузки галереи
    func setGalleryLoading(_ loading: Bool) {
        galleryIsLoading = loading
        if loading {
            print("⏳ [PAGINATION] Set galleryIsLoading = true")
        }
    }
    
    // Простое управление состоянием видео-галереи (без пагинации)
    func appendVideoGalleryItems(_ items: [UserVideoItem]) {
        self.videoItems = items
        if currentTabIndex == 1 {
            galleryCollectionView.reloadData()
            playVisibleVideos()
        }
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
    
    
// MARK: - @objc
    
    @objc private func dmButtonTapped() {
        
    }
    
    @objc private func likesTapped() {
        onLikesTapped?()
    }
    
    @objc private func viewsTapped() {
        onViewsTapped?()
    }
    
    @objc private func savesTapped() {
        onSavesTapped?()
    }
}


// MARK: - UICollectionViewDataSource

extension PublicProfileScreenNode: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == galleryCollectionView {
            // 0 — фото, 1 — видео, остальные сегменты пока не используют коллекцию
            if currentTabIndex == 1 {
                return videoItems.count
            } else {
                return galleryPhotos.count
            }
        } else if collectionView == similarProfilesCollectionView {
            return similarProfiles.count
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
            if currentTabIndex == 1 {
                // Видео-галерея
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoGalleryCell.reuseIdentifier, for: indexPath) as? VideoGalleryCell else {
                    return UICollectionViewCell()
                }
                let item = videoItems[indexPath.item]
                let primaryFile = item.files.first
                let videoUrl = primaryFile?.fullUrl ?? ""
                let previewUrl = primaryFile?.fullUrl
                cell.configure(with: videoUrl, previewUrl: previewUrl, title: item.title)
                return cell
            } else {
                // Фото-галерея
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCell", for: indexPath) as? GalleryCell else {
                    return UICollectionViewCell()
                }
                let photoItem = galleryPhotos[indexPath.item]
                
                if let previewUrlString = photoItem.preview?.fullUrl, let url = URL(string: previewUrlString) {
                    cell.configure(with: url)
                } else if let fullUrlString = photoItem.photo.fullUrl, let url = URL(string: fullUrlString) {
                    cell.configure(with: url)
                }
                
                return cell
            }
        }
        return UICollectionViewCell()
    }
}


// MARK: - UICollectionViewDelegate

extension PublicProfileScreenNode: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == similarProfilesCollectionView {
            let profile = similarProfiles[indexPath.item]
            print("👤 Selected similar profile: \(profile.name)")
            // TODO: Открыть профиль выбранного пользователя
            // handleSimilarProfileTap(profile)
        }
    }
}


// MARK: - UICollectionViewDelegateFlowLayout

extension PublicProfileScreenNode: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == similarProfilesCollectionView {
            return CGSize(width: 166, height: 200)
        } else if collectionView == galleryCollectionView {
            guard let (layout, _) = self.containerLayout else { return .zero }
            let totalSpacing: CGFloat = 2
            let width = (layout.size.width - totalSpacing) / 3.0
            return CGSize(width: width, height: width)
        }
        return CGSize()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        if collectionView == similarProfilesCollectionView {
            return 6
        } else if collectionView == galleryCollectionView {
            return 1.0
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        if collectionView == similarProfilesCollectionView {
            return 6
        } else if collectionView == galleryCollectionView {
            return 1.0
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if collectionView == similarProfilesCollectionView {
            return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        } else if collectionView == galleryCollectionView {
            return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}


// MARK: - UIScrollViewDelegate

extension PublicProfileScreenNode: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        galleryCollectionView.layoutIfNeeded()
        
        let offsetY = scrollView.contentOffset.y
        let contentHeight = galleryCollectionView.contentSize.height
        let frameHeight = galleryCollectionView.frame.size.height
        
        let threshold = contentHeight - frameHeight - 100
        
        if offsetY > threshold && galleryHasMore && !galleryIsLoading {
            print("📜 [SCROLL] Triggering load more at offset=\(offsetY), threshold=\(threshold)")
            loadNextGalleryPage()
        }
        if currentTabIndex == 1 {
            playVisibleVideos()
        }
        updateSegmentedBarPosition()
        updateNavigationBarTitleVisibility()
        
        let maxScrollY = scrollView.contentSize.height - scrollView.bounds.height
        
        let bottomLimit = max(0, maxScrollY)
        
        if scrollView.contentOffset.y > bottomLimit {
            scrollView.contentOffset.y = bottomLimit
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
    func segmentedBar(_ segmentedBar: ProfileSegmentedBar, didSelectIndex index: Int) {
        guard index != currentTabIndex else { return }
        if currentTabIndex == 1 {
            stopVisibleVideos()
        }
        currentTabIndex = index
        // Простое переключение между фото (0) и видео (1).
        DispatchQueue.main.async {
            self.setNeedsLayout()
            self.layoutIfNeeded()
            self.galleryCollectionView.reloadData()
            if self.currentTabIndex == 1 {
                self.playVisibleVideos()
            }
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
