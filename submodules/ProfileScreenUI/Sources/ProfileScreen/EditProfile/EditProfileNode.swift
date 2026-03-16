import Display
import UIKit
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ChatListSearchItemHeader
import AppBundle
import ItemListUI

final class EditProfileNode: ASDisplayNode {
    
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private let model: UserDetail?
    var showAlert: ((String) -> Void)?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var navigationBarTitleHeightConstraint: NSLayoutConstraint!
    
    private var presentationData: PresentationData
    private let presentationDataPromise: Promise<PresentationData>
    
    private let _ready = Promise<Bool>()
    private var readyValue = false {
        didSet {
            if self.readyValue, self.readyValue != oldValue {
                self._ready.set(.single(self.readyValue))
            }
        }
    }
    var ready: Signal<Bool, NoError> {
        return self._ready.get()
    }
    
    var saveProfile: ((ProfileRawData) -> Void)?
    var onAvatarTap: (() -> Void)?
    
    
    // MARK: - ScrollView
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    
    // MARK: - Main StackView
    
    private let mainStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    
    // MARK: - Tab
    
    private let tabsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let biographyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("BIOGRAPHY", for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(12)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let appearanceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("APPEARANCE", for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(12)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 2
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private var indicatorCenterXConstraint: NSLayoutConstraint!
    private var indicatorWidthConstraint: NSLayoutConstraint!
    
    private var selectedIndex: Int = 0
    
    
    // MARK: - Swipe Pager

    private lazy var horizontalPager: UIScrollView = {
        let sv = UIScrollView()
        sv.isPagingEnabled = true
        sv.showsHorizontalScrollIndicator = false
        sv.delegate = self
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.clipsToBounds = false
        sv.isScrollEnabled = false
        return sv
    }()
    
    private var pagerHeightConstraint: NSLayoutConstraint!
    
    private let bioStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let appearanceStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    
    // MARK: - Biography UI
    
    private let avatarImageContainerView: UIView = {
        let iv = UIView()
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 50
        iv.layer.borderWidth = 1
        iv.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 47
        iv.backgroundColor = .systemGray
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let chancePhotoView: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(hexString: "#BF7A54")
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(bundleImageName: "Profile/AddPhotoIcon")
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        let padding: CGFloat = 4
        button.imageEdgeInsets = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    private let avatarSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    private let nameEventTextField: TextFieldNode
    private let lastNameEventTextField: TextFieldNode
    private let aboutEventTextField: DivoTextView
    
    
    // MARK: - Appearance UI
    
    private let genderDropdown: DropdownNode
    private var ageSlider: AgeSliderNode<Int>
    private let heightSlider: AgeSliderNode<Double>
    private let waistSlider: AgeSliderNode<Double>
    private let hipsSlider: AgeSliderNode<Double>
    private let shoeSizeSlider: AgeSliderNode<Double>
    private let hairLengthSlider: AgeSliderNode<Double>
    private let hairColorDropdown: DropdownNode
    
    
    // MARK: - Footer UI
    
    private let applyButton: ASControlNode
    
    var currentPhoto: UIImage? = nil {
        didSet {
            avatarImageView.image = currentPhoto
        }
    }
    
    
    // MARK: - Init
    
    init(context: AccountContext, presentationData: PresentationData, model: UserDetail?) {
        self.context = context
        self.model = model
        
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)
                
        self.nameEventTextField = getTextFiel(title: model?.fullName ?? "Name")
        if let fullName = model?.fullName {
            self.nameEventTextField.textField.text = fullName
        }
        self.lastNameEventTextField = getTextFiel(title: model?.fullName ?? "Last Name")
        if let fullName = model?.fullName {
            self.lastNameEventTextField.textField.text = fullName
        }
        self.aboutEventTextField = DivoTextView(title: "Biography", initialText: model?.model?.additionalInformation ?? "Fill in the information about you")
        
        self.genderDropdown = DropdownNode(placeholder: "Select a Gender", options:["Female", "Male"])
        self.ageSlider = AgeSliderNode(title: "Age (y.o)", type: "y.o", defaultValue: 17, minimumValue: 14, maximumValue: 45)
        self.heightSlider = AgeSliderNode(title: "Height (cm)", type: "cm", defaultValue: model?.model?.appearance?.height ?? 1.68, minimumValue: 1.68, maximumValue: 2.50)
        self.waistSlider = AgeSliderNode(title: "Waist (cm)", type: "cm", defaultValue: model?.model?.appearance?.waist ?? 60, minimumValue: 48, maximumValue: 90)
        self.hipsSlider = AgeSliderNode(title: "Hips (cm)", type: "cm", defaultValue: model?.model?.appearance?.hips ?? 91, minimumValue: 80, maximumValue: 110)
        self.shoeSizeSlider = AgeSliderNode(title: "Shoe size (EU)", type: "", defaultValue: model?.model?.appearance?.shoesSize ?? 37, minimumValue: 36, maximumValue: 42)
        self.hairLengthSlider = AgeSliderNode(title: "Hair length (cm)", type: "", defaultValue: 46, minimumValue: 0, maximumValue: 200)
        self.hairColorDropdown = DropdownNode(placeholder: "Choose your hair color", options:["Blonde", "Brunette", "Brown", "Black", "Red", "Other"])
        
        self.applyButton = ButtonWithIconNode(title: "Save", icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.applyButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        super.init()
        
        self.ageSlider = AgeSliderNode(title: "Age (y.o)", type: "y.o", defaultValue: calculateAge(from: model?.birthday ?? ""), minimumValue: 14, maximumValue: 45)
        
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        if let avatarURLString = model?.avatar?.fullUrl {
            if let avatarURL = CDNURLHelper.convertToCDNURL(avatarURLString) {
                ImageLoader.shared.load(url: avatarURL) { [weak self] image in
                    if let image = image {
                        self?.avatarImageView.image = image
                    }
                }
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        setupUI()
        
        let avatarTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.avatarTapped))
        self.avatarImageView.addGestureRecognizer(avatarTapGesture)
        
        self.biographyButton.addTarget(self, action: #selector(biographyTapped), for: .touchUpInside)
        self.appearanceButton.addTarget(self, action: #selector(appearanceTapped), for: .touchUpInside)
        self.applyButton.addTarget(self, action: #selector(self.saveButtonPressed), forControlEvents: .touchUpInside)
        self.chancePhotoView.addTarget(self, action: #selector(self.avatarTapped), for: .touchUpInside)
        
        updateTabsTextColor()
        
        DispatchQueue.main.async {
            self.updatePagerHeight(animated: false)
            self.updateIndicatorPosition(progress: 0, animated: false)
            self.readyValue = true
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        navigationBarTitleHeightConstraint.isActive = false
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: navigationBarHeight)
        navigationBarTitleHeightConstraint.isActive = true
        
        DispatchQueue.main.async {
            self.updatePagerHeight(animated: false)
            self.updateIndicatorPosition(progress: CGFloat(self.selectedIndex), animated: false)
        }
//        self.layoutIfNeeded()
    }
    
    
    // MARK: - Setup UI (Auto Layout)
    
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
    
    private func setupUI() {
        self.view.addSubview(scrollView)
        scrollView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            // надо тут подмать, как обновлять отступ у scrollView
            scrollView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 96),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            mainStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            mainStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            mainStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor)
        navigationBarTitleHeightConstraint.isActive = true
        
        setupTabs()
        setupPager()
        
        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        applyButton.view.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(applyButton.view)
        
        NSLayoutConstraint.activate([
            applyButton.view.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            applyButton.view.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
            applyButton.view.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor, constant: 16),
            applyButton.view.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -16),
            applyButton.view.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        mainStackView.addArrangedSubview(buttonContainer)
    }
    
    private func setupTabs() {
        mainStackView.addArrangedSubview(tabsContainer)
        tabsContainer.heightAnchor.constraint(equalToConstant: 26).isActive = true
        
        tabsContainer.addSubview(biographyButton)
        tabsContainer.addSubview(appearanceButton)
        tabsContainer.addSubview(indicatorView)
        
        NSLayoutConstraint.activate([
            biographyButton.leadingAnchor.constraint(equalTo: tabsContainer.leadingAnchor),
            biographyButton.topAnchor.constraint(equalTo: tabsContainer.topAnchor),
            biographyButton.bottomAnchor.constraint(equalTo: tabsContainer.bottomAnchor),
            biographyButton.widthAnchor.constraint(equalTo: tabsContainer.widthAnchor, multiplier: 0.5),
            
            appearanceButton.trailingAnchor.constraint(equalTo: tabsContainer.trailingAnchor),
            appearanceButton.topAnchor.constraint(equalTo: tabsContainer.topAnchor),
            appearanceButton.bottomAnchor.constraint(equalTo: tabsContainer.bottomAnchor),
            appearanceButton.widthAnchor.constraint(equalTo: tabsContainer.widthAnchor, multiplier: 0.5),
            
            indicatorView.bottomAnchor.constraint(equalTo: tabsContainer.bottomAnchor),
            indicatorView.heightAnchor.constraint(equalToConstant: 2)
        ])
        
        indicatorCenterXConstraint = indicatorView.centerXAnchor.constraint(equalTo: biographyButton.centerXAnchor)
        indicatorWidthConstraint = indicatorView.widthAnchor.constraint(equalToConstant: 60)
        
        indicatorCenterXConstraint.isActive = true
        indicatorWidthConstraint.isActive = true
    }
    
    private func setupPager() {
        mainStackView.addArrangedSubview(horizontalPager)
        
        pagerHeightConstraint = horizontalPager.heightAnchor.constraint(equalToConstant: 300) // Временная стартовая высота
        pagerHeightConstraint.isActive = true
        
        let contentWidthView = UIView()
        contentWidthView.translatesAutoresizingMaskIntoConstraints = false
        horizontalPager.addSubview(contentWidthView)
        
        contentWidthView.addSubview(bioStackView)
        contentWidthView.addSubview(appearanceStackView)
        
        NSLayoutConstraint.activate([
            contentWidthView.topAnchor.constraint(equalTo: horizontalPager.topAnchor),
            contentWidthView.bottomAnchor.constraint(equalTo: horizontalPager.bottomAnchor),
            contentWidthView.leadingAnchor.constraint(equalTo: horizontalPager.leadingAnchor),
            contentWidthView.trailingAnchor.constraint(equalTo: horizontalPager.trailingAnchor),
            contentWidthView.heightAnchor.constraint(equalTo: horizontalPager.heightAnchor),
            
            bioStackView.leadingAnchor.constraint(equalTo: contentWidthView.leadingAnchor, constant: 16),
            bioStackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            bioStackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor, constant: -32),
            
            appearanceStackView.leadingAnchor.constraint(equalTo: bioStackView.trailingAnchor, constant: 32),
            appearanceStackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            appearanceStackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor, constant: -32),
            appearanceStackView.trailingAnchor.constraint(equalTo: contentWidthView.trailingAnchor, constant: -16)
        ])
        
        setupBioContent()
        setupAppearanceContent()
    }
    
    private func setupBioContent() {
        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarImageContainerView)
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(chancePhotoView)
        avatarContainer.addSubview(avatarSpinner)
        
        NSLayoutConstraint.activate([
            avatarContainer.heightAnchor.constraint(equalToConstant: 120),
            
            avatarImageContainerView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageContainerView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageContainerView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageContainerView.heightAnchor.constraint(equalToConstant: 100),
            
            avatarImageView.centerXAnchor.constraint(equalTo: avatarImageContainerView.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarImageContainerView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 94),
            avatarImageView.heightAnchor.constraint(equalToConstant: 94),
            
            chancePhotoView.trailingAnchor.constraint(equalTo: avatarImageContainerView.trailingAnchor, constant: 4),
            chancePhotoView.bottomAnchor.constraint(equalTo: avatarImageContainerView.bottomAnchor),
            chancePhotoView.widthAnchor.constraint(equalToConstant: 32),
            chancePhotoView.heightAnchor.constraint(equalToConstant: 32),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor)
        ])
        
        bioStackView.addArrangedSubview(avatarContainer)
        avatarContainer.widthAnchor.constraint(equalTo: bioStackView.widthAnchor).isActive = true
        
        nameEventTextField.view.translatesAutoresizingMaskIntoConstraints = false
        lastNameEventTextField.view.translatesAutoresizingMaskIntoConstraints = false
        aboutEventTextField.view.translatesAutoresizingMaskIntoConstraints = false
        
        bioStackView.addArrangedSubview(nameEventTextField.view)
        bioStackView.addArrangedSubview(lastNameEventTextField.view)
        bioStackView.addArrangedSubview(aboutEventTextField.view)
        
        NSLayoutConstraint.activate([
            nameEventTextField.view.widthAnchor.constraint(equalTo: bioStackView.widthAnchor),
            nameEventTextField.view.heightAnchor.constraint(equalToConstant: 48),
            
            lastNameEventTextField.view.widthAnchor.constraint(equalTo: bioStackView.widthAnchor),
            lastNameEventTextField.view.heightAnchor.constraint(equalToConstant: 48),
            
            aboutEventTextField.view.widthAnchor.constraint(equalTo: bioStackView.widthAnchor),
            aboutEventTextField.view.heightAnchor.constraint(equalToConstant: 140)
        ])
    }
    
    private func setupAppearanceContent() {
        let nodes: [ASDisplayNode] = [genderDropdown, ageSlider, heightSlider, waistSlider, hipsSlider, shoeSizeSlider, hairLengthSlider, hairColorDropdown]
        
        for node in nodes {
            node.view.translatesAutoresizingMaskIntoConstraints = false
            appearanceStackView.addArrangedSubview(node.view)
            
            node.view.widthAnchor.constraint(equalTo: appearanceStackView.widthAnchor).isActive = true
            
            if node is DropdownNode {
                node.view.heightAnchor.constraint(equalToConstant: 48).isActive = true
            } else {
                node.view.heightAnchor.constraint(equalToConstant: 80).isActive = true
            }
        }
        
        appearanceStackView.setCustomSpacing(24, after: genderDropdown.view)
    }
    
    
    // MARK: - Actions

    @objc private func avatarTapped() {
        print("Change photo")
        onAvatarTap?()
    }
    
    @objc private func biographyTapped() {
        setSelectedIndex(0, animated: true)
    }
    
    @objc private func appearanceTapped() {
        setSelectedIndex(1, animated: true)
    }
    
    @objc private func updateAccountPeerName() {
        print("Save button tapped")
    }
    
    @objc private func saveButtonPressed() {
        print("Save button pressed in Node. Collecting data...")
        
        let profileData = collectProfileData()
        
        // ВЫЗЫВАЕМ CALLBACK, передавая данные контроллеру
        saveProfile?(profileData)
    }
    
    private func collectProfileData() -> ProfileRawData {
        // Собираем данные с полей
        let fullName = nameEventTextField.textField.text
        // let biography = aboutEventTextField.text
        let gender = genderDropdown.selectedValue ?? "Female"
        
        // Вычисляем возраст из ageSlider
        let age = Int(ageSlider.slider.value.rounded())
        let birthday = calculateBirthdayString(from: age)
        
        // Собираем Appearance данные
        let height = heightSlider.slider.value
        let weight = waistSlider.slider.value  // Используем waist как weight для примера
        let waist = waistSlider.slider.value
        let hips = hipsSlider.slider.value
        let shoesSize = shoeSizeSlider.slider.value
        let hairLength = hairLengthSlider.slider.value
        
        // let hairColor = hairColorDropdown.selectedValue ?? "Black"
        let eyeColor = 0
        let skinColor = 0
        
        let appearance = Appearance(
            measuringSystem: "metric",
            height: Double(height),
            weight: Double(weight),
            breastSize: nil,
            waist: Double(waist),
            hips: Double(hips),
            shoesSize: Double(shoesSize),
            hairColor: 0,
            hairLength: Double(hairLength),
            eyeColor: eyeColor,
            skinColor: skinColor
        )
        
        let modelData = Model(
            agencyId: nil,
            profileUrl: nil,
            education: nil,
            workExperience: nil,
            languages: nil,
            hasInternationalPassport: false,
            hasTattoo: false,
            hasPiercing: false,
            hasActingEducation: false,
            appearance: appearance
        )
        
        return ProfileRawData(
            fullName: fullName,
            phone: nil,
            timezone: TimeZone.current.identifier,
            gender: gender.lowercased(),
            birthday: birthday,
            geoCityId: 0,
            measuringSystem: "metric",
            subrole: nil,
            pushNotifications: true,
            isRegistrationFinished: true,
            photo: nil,
            avatar: nil,
            model: modelData,
            customer: nil
        )
    }
    
    private func calculateBirthdayString(from age: Int) -> String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let birthYear = currentYear - age
        return "\(birthYear)-01-01"
    }

    func toggleSpinner(active: Bool) {
        if active {
            avatarSpinner.startAnimating()
            avatarImageView.alpha = 0.5
        } else {
            avatarSpinner.stopAnimating()
            avatarImageView.alpha = 1.0
        }
    }
}


// UITextFieldDelegate
extension EditProfileNode: UITextFieldDelegate {
    private func setSelectedIndex(_ index: Int, animated: Bool) {
        guard selectedIndex != index else { return }
        selectedIndex = index
        updateTabsTextColor()
        
        let offsetX = CGFloat(index) * horizontalPager.bounds.width
        horizontalPager.setContentOffset(CGPoint(x: offsetX, y: 0), animated: animated)
        
        updatePagerHeight(animated: animated)
    }
    
    private func updateTabsTextColor() {
        let selectedColor: UIColor = .white
        let unselectedColor: UIColor = .white.withAlphaComponent(0.6)
        
        biographyButton.setTitleColor(selectedIndex == 0 ? selectedColor : unselectedColor, for: .normal)
        appearanceButton.setTitleColor(selectedIndex == 1 ? selectedColor : unselectedColor, for: .normal)
    }
    
    private func updatePagerHeight(animated: Bool) {
        bioStackView.layoutIfNeeded()
        appearanceStackView.layoutIfNeeded()
        
        let bioHeight = bioStackView.frame.height
        let appHeight = appearanceStackView.frame.height
        
        let targetHeight = max(100, selectedIndex == 0 ? bioHeight : appHeight)
        
        pagerHeightConstraint.constant = targetHeight
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        } else {
            self.view.layoutIfNeeded()
        }
    }
    
    private func updateIndicatorPosition(progress: CGFloat, animated: Bool = false) {
        guard let bioTitle = biographyButton.titleLabel?.text, let appTitle = appearanceButton.titleLabel?.text else { return }
        
        let font = Font.helveticaNeue(12)
        let bioWidth = (bioTitle as NSString).size(withAttributes: [.font: font]).width
        let appWidth = (appTitle as NSString).size(withAttributes: [.font: font]).width
        
        let currentWidth = bioWidth + (appWidth - bioWidth) * progress
        indicatorWidthConstraint.constant = currentWidth
        
        let halfWidth = tabsContainer.bounds.width / 2.0
        let center0 = halfWidth / 2.0
        let center1 = halfWidth + (halfWidth / 2.0)
        
        indicatorCenterXConstraint.constant = (center1 - center0) * progress
        
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.tabsContainer.layoutIfNeeded()
            }
        } else {
            self.tabsContainer.layoutIfNeeded()
        }
    }
}

// UIScrollViewDelegate
extension EditProfileNode: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == horizontalPager, scrollView.bounds.width > 0 else { return }
        
        let progress = scrollView.contentOffset.x / scrollView.bounds.width
        updateIndicatorPosition(progress: progress)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == horizontalPager else { return }
        
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        if selectedIndex != page {
            selectedIndex = page
            updateTabsTextColor()
            updatePagerHeight(animated: true)
        }
    }
}


// MARK: - Helpers

private func getTextFiel(title: String, isMultiline: Bool = false) -> TextFieldNode {
    let field = TextFieldNode()
    field.textField.font = Font.regular(16.0)
    field.textField.textColor = .white
    field.textField.textAlignment = .natural
    field.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.font, textColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.4))
    field.textField.autocapitalizationType = .none
    field.textField.autocorrectionType = .no
    field.borderWidth = 1.0
    field.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4).cgColor
    field.cornerRadius = 11.0
    field.clipsToBounds = true
    if isMultiline {
        field.padding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    } else {
        field.padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
    return field
}
