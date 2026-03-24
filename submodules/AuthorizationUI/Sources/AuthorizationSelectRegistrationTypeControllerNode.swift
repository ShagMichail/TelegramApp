import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import Markdown
import SolidRoundedButtonNode
import AuthorizationUtils
import TelegramCore

private enum TypeOfRole: String {
    case talent = "TALENT"
    case model = "MODEL"
    case agencies = "AGENCIES"
    case fan = "FAN"
}

private func roundCorners(diameter: CGFloat) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setBlendMode(.copy)
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    context.setFillColor(UIColor.clear.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
    UIGraphicsEndImageContext()
    return image
}

private func getTextField(title: String) -> TextFieldNode {
    let field = TextFieldNode()
    field.textField.font = Font.regular(16.0)
    field.textField.textColor = .white.withAlphaComponent(0.6)
    field.textField.textAlignment = .natural
    field.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.font, textColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.4))
    field.textField.autocapitalizationType = .none
    field.textField.autocorrectionType = .no
    //    field.textField.keyboardType = .URL
    field.borderWidth = 1.0
    field.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4).cgColor
    field.cornerRadius = 10.0
    field.clipsToBounds = true
    field.padding = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)

    return field
}

private func getChevronTextField(title: String) -> TextFieldNodeWithChevron {
    let field = TextFieldNodeWithChevron()
    field.textField.textField.font = Font.regular(16.0)
    field.textField.textField.textColor = .white.withAlphaComponent(0.6)
    field.textField.textField.textAlignment = .natural
    field.textField.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.textField.font, textColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.4))
    field.textField.textField.autocapitalizationType = .none
    field.textField.textField.autocorrectionType = .no
    field.borderWidth = 1.0
    field.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4).cgColor
    field.cornerRadius = 10.0
    field.clipsToBounds = true
    field.padding = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)

    return field
}

class TextFieldNodeWithChevron: ASDisplayNode {
    let textField: TextFieldNode
    private let chevronNode: ASImageNode

    override init() {
        self.textField = TextFieldNode()
        self.chevronNode = ASImageNode()
        self.chevronNode.image = generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextDownArrow"), color: UIColor.white.withAlphaComponent(0.4))
        self.chevronNode.contentMode = .scaleAspectFit
        self.chevronNode.isUserInteractionEnabled = false

        super.init()

        self.addSubnode(self.textField)
        self.addSubnode(self.chevronNode)
    }

    var padding: UIEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) {
        didSet {
            self.textField.padding = self.padding
        }
    }

    override func layout() {
        super.layout()

        self.textField.frame = self.bounds

        let chevronSize = CGSize(width: 20, height: 20)
        let padding: CGFloat = 16.0
        self.chevronNode.frame = CGRect(
            x: self.bounds.width - padding - chevronSize.width,
            y: (self.bounds.height - chevronSize.height) / 2,
            width: chevronSize.width,
            height: chevronSize.height
        )
    }
}

final class ChooseRoleControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let typeOfRole: TypeOfRole
    private let addPhoto: () -> Void
    
    private let scrollNode: ASScrollNode
    private let contentNode: ASDisplayNode
    
    private let titleNode: ASTextNode
    private let currentOptionNode: ASTextNode
    
    private let typeNode: ASTextNode
    private let agenciesCheckboxNode: CheckboxTitleNode
    private let brandsCheckboxNode: CheckboxTitleNode
    private enum AgencyType { case agencies, brands }
    private var selectedAgencyType: AgencyType = .agencies
    
    private let sectionTitleNode: ASTextNode
    
    private let nameAgency: TextFieldNode
    private let chooseCountryField: TextFieldNodeWithChevron
    private var countryId: String = ""
    private let chooseGenderField: TextFieldNodeWithChevron
    private let chooseAgencyField: TextFieldNodeWithChevron
    private let websiteField: TextFieldNode
    
    private let ageSliderNode: AgeSliderNode
    
    private var activeTextField: UITextField?
    
    private let currentPhotoNode: ASImageNode
    private let addPhotoButton: HighlightableButtonNode
    
    private let backNode: ButtonWithIconNode
    private let saveNode: ButtonWithIconNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    private let appearanceTimestamp = CACurrentMediaTime()
    
    var currentName: (String, String) {
        return ("", "")
    }
    
    var currentPhoto: UIImage? = nil {
        didSet {
            if let currentPhoto = self.currentPhoto {
                self.currentPhotoNode.image = generateImage(CGSize(width: 110.0, height: 110.0), contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setBlendMode(.copy)
                    context.draw(currentPhoto.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    context.setBlendMode(.destinationOut)
                    context.draw(roundCorners(diameter: size.width).cgImage!, in: CGRect(origin: CGPoint(), size: size))
                })
            } else {
                self.currentPhotoNode.image = nil
            }
        }
    }
    
    var signUpWithName: ((AuthorizationModelInfo) -> Void)?
    var selectCountryCode: (() -> Void)?
    var selectGender: (() -> Void)?
    var selectAgency: (() -> Void)?
    var openTermsOfService: (() -> Void)?
    var back: (() -> Void)?
    
    var inProgress: Bool = false
    
    init(theme: PresentationTheme, strings: PresentationStrings, typeOfRole: String, addPhoto: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.addPhoto = addPhoto
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.contentInsetAdjustmentBehavior = .always

        self.contentNode = ASDisplayNode()
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.typeOfRole = TypeOfRole(rawValue: typeOfRole) ?? .model
        
        var titleText = ""
        var nameAgencyText = ""
        
        switch self.typeOfRole {
        case .talent:
            titleText = "Apply as \n a new talent"
            nameAgencyText = "Full Name"
            
        case .model:
            titleText = "Apply as a \n Professional Model"
            nameAgencyText = "Full Name"
            
        case .agencies:
            titleText = "Apply as a \n agencies & brands"
            nameAgencyText = "Name Agency"
            
        case .fan:
            titleText = "Apply as \n a Fan"
            nameAgencyText = "Full Name"
        }
        
        self.titleNode.attributedText = Font.helveticaNeue(titleText.uppercased(), 34)
        
        self.typeNode = ASTextNode()
        self.typeNode.isUserInteractionEnabled = false
        self.typeNode.displaysAsynchronously = false
        self.typeNode.attributedText = Font.helveticaNeue("Type", 16, alignment: .left)
        
        
        self.agenciesCheckboxNode = CheckboxTitleNode(title: "Agencies")
        self.brandsCheckboxNode = CheckboxTitleNode(title: "Brands")
        
        self.currentOptionNode = ASTextNode()
        self.currentOptionNode.isUserInteractionEnabled = false
        self.currentOptionNode.displaysAsynchronously = false
        self.currentOptionNode.attributedText = NSAttributedString(
            string: "Fill out your profile details to apply as a professional model. You can update this information anytime.",
            font: Font.regular(16.0),
            textColor: .white.withAlphaComponent(0.6),
            paragraphAlignment: .center)
        
        self.sectionTitleNode = ASTextNode()
        self.sectionTitleNode.isUserInteractionEnabled = false
        self.sectionTitleNode.displaysAsynchronously = false
        self.sectionTitleNode.attributedText = Font.helveticaNeue("Your personal data".uppercased(), 20, alignment: .left)
        
        self.nameAgency = getTextField(title: nameAgencyText)
        self.websiteField = getTextField(title: "Enter name your website")
        self.chooseCountryField = getChevronTextField(title: "Choose a country")
        self.chooseGenderField = getChevronTextField(title: "Select a Gender")
        self.chooseAgencyField = getChevronTextField(title: "Choose agency name")
        
        self.ageSliderNode = AgeSliderNode(title: "Age (y.o)", type: "y.o", defaultValue: 17, minimumValue: 14, maximumValue: 45)
        
        self.currentPhotoNode = ASImageNode()
        self.currentPhotoNode.isUserInteractionEnabled = false
        self.currentPhotoNode.displaysAsynchronously = false
        self.currentPhotoNode.displayWithoutProcessing = true
        
        self.addPhotoButton = HighlightableButtonNode()
        let iconColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
        self.addPhotoButton.setImage(
            generateTintedImage(image: UIImage(bundleImageName: "Avatar/AddAvatarIconLarge"),
                                color: iconColor),
            for: .normal)
        self.addPhotoButton.setBackgroundImage(generateFilledCircleImage(diameter: 100.0, color: self.theme.list.itemAccentColor.withAlphaComponent(0.1), strokeColor: nil, strokeWidth: nil, backgroundColor: nil), for: .normal)
        
        let backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        let borderColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        self.addPhotoButton.setBackgroundImage(generateFilledCircleImage(diameter: 110.0, color: backgroundColor, strokeColor: borderColor, strokeWidth: 1.0, backgroundColor: nil), for: .normal)
        
        self.addPhotoButton.addSubnode(self.currentPhotoNode)
        self.addPhotoButton.allowsGroupOpacity = true
        
        let backIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"),
                                           color: .white)
        
        let imageSize: CGSize = CGSize(width: 16, height: 12)
        self.backNode = ButtonWithIconNode(title: "Back", icon: backIcon, theme: theme, spacing: 10, imageSize: imageSize)
        self.backNode.backgroundColor = UIColor(hexString: "#343434")
        
        self.saveNode = ButtonWithIconNode(title: "Save", icon: nil, theme: theme, spacing: 10, imageSize: imageSize)
        self.saveNode.backgroundColor = UIColor(hexString: "#BF7A54")

        super.init()

        self.agenciesCheckboxNode.addTarget(self, action: #selector(self.agenciesCheckboxTapped))
        self.brandsCheckboxNode.addTarget(self, action: #selector(self.brandsCheckboxTapped))

        updateCheckboxSelection()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.nameAgency.textField.delegate = self
        self.websiteField.textField.delegate = self
        self.chooseCountryField.textField.textField.delegate = self
        self.chooseGenderField.textField.textField.delegate = self
        self.chooseAgencyField.textField.textField.delegate = self
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tapGesture)
        
        self.contentNode.addSubnode(self.sectionTitleNode)
        
        self.contentNode.addSubnode(self.websiteField)
        self.contentNode.addSubnode(self.chooseCountryField)
        
        if self.typeOfRole != .agencies {
            self.contentNode.addSubnode(self.ageSliderNode)
        }
        self.contentNode.addSubnode(self.chooseGenderField)
        self.contentNode.addSubnode(self.chooseAgencyField)
        self.contentNode.addSubnode(self.nameAgency)
        self.contentNode.addSubnode(self.titleNode)
        self.contentNode.addSubnode(self.typeNode)
        self.contentNode.addSubnode(self.agenciesCheckboxNode)
        self.contentNode.addSubnode(self.brandsCheckboxNode)
        self.contentNode.addSubnode(self.currentOptionNode)
        self.contentNode.addSubnode(self.addPhotoButton)
    
        self.scrollNode.addSubnode(contentNode)
        self.addSubnode(scrollNode)
        
        self.addSubnode(self.backNode)
        self.addSubnode(self.saveNode)
        
        self.addPhotoButton.addTarget(self, action: #selector(self.addPhotoPressed), forControlEvents: .touchUpInside)
        self.backNode.addTarget(self, action: #selector(self.backButtonPressed), forControlEvents: .touchUpInside)
        
        self.saveNode.addTarget(self, action: #selector(self.saveButtonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func agenciesCheckboxTapped() {
        // Если уже выбрано, ничего не делаем
        guard selectedAgencyType != .agencies else { return }
        
        selectedAgencyType = .agencies
        updateCheckboxSelection()
    }
    
    @objc private func brandsCheckboxTapped() {
        guard selectedAgencyType != .brands else { return }
        
        selectedAgencyType = .brands
        updateCheckboxSelection()
    }
    
    /// Вспомогательная функция для обновления UI чекбоксов
    private func updateCheckboxSelection() {
        agenciesCheckboxNode.isSelected = (selectedAgencyType == .agencies)
        brandsCheckboxNode.isSelected = (selectedAgencyType == .brands)
    }
    
    func updateData(firstName: String, lastName: String, hasTermsOfService: Bool) {
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func updateCountry(countryId: String, countryName: String) {
        chooseCountryField.textField.textField.text = countryName
        self.countryId = countryId
//        if let (layout, navigationHeight) = self.layoutArguments {
//            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
//        }
        
    }
    
    func containerLayoutUpdated(
        _ layout: ContainerViewLayout,
        navigationBarHeight: CGFloat,
        transition: ContainedViewLayoutTransition
    ) {
        self.layoutArguments = (layout, navigationBarHeight)
        
        let maximumWidth: CGFloat = min(430.0, layout.size.width)
        let sideInset: CGFloat = 16.0
        let fieldHeight: CGFloat = 40.0
        
        var insets = layout.insets(options: [.statusBar])
        let bottomButtonsHeight: CGFloat = 50.0 + 50.0 // кнопка + отступ
        insets.bottom += bottomButtonsHeight
        
        // Scroll занимает весь экран
        transition.updateFrame(
            node: self.scrollNode,
            frame: CGRect(origin: .zero, size: layout.size)
        )
        
        // MARK: - Measure
        
        let titleSize = self.titleNode.measure(CGSize(width: maximumWidth - 40, height: .greatestFiniteMagnitude))
        let noticeSize = self.currentOptionNode.measure(CGSize(width: maximumWidth - 28, height: .greatestFiniteMagnitude))
        let sectionTitleSize = self.sectionTitleNode.measure(CGSize(width: maximumWidth, height: .greatestFiniteMagnitude))
        let typeTitleSize = self.typeNode.measure(CGSize(width: maximumWidth, height: .greatestFiniteMagnitude))
        
        let avatarSize = CGSize(width: 100, height: 100)
        
        var contentHeight: CGFloat = 30 //  insets.top
        
        func centerX(_ width: CGFloat) -> CGFloat {
            return floorToScreenPixels((layout.size.width - width) / 2.0)
        }
        
        // MARK: - Layout manually (вместо AuthorizationLayoutItems)
        
        // Title
        transition.updateFrame(
            node: self.titleNode,
            frame: CGRect(x: centerX(titleSize.width), y: contentHeight, width: titleSize.width, height: titleSize.height)
        )
        contentHeight += titleSize.height + 16
        
        // Description
        transition.updateFrame(
            node: self.currentOptionNode,
            frame: CGRect(x: centerX(noticeSize.width), y: contentHeight, width: noticeSize.width, height: noticeSize.height)
        )
        contentHeight += noticeSize.height + 24
        
        // Avatar
        transition.updateFrame(
            node: self.addPhotoButton,
            frame: CGRect(x: centerX(avatarSize.width), y: contentHeight, width: avatarSize.width, height: avatarSize.height)
        )
        self.currentPhotoNode.frame = CGRect(origin: .zero, size: avatarSize)
        contentHeight += avatarSize.height + 24
        
        // Section title
        transition.updateFrame(
            node: self.sectionTitleNode,
            frame: CGRect(x: sideInset, y: contentHeight, width: maximumWidth - sideInset * 2, height: sectionTitleSize.height)
        )
        contentHeight += sectionTitleSize.height + 16
        
        // MARK: - Fields
        
        func layoutField(_ node: ASDisplayNode) {
            transition.updateFrame(
                node: node,
                frame: CGRect(
                    x: sideInset,
                    y: contentHeight,
                    width: maximumWidth - sideInset * 2,
                    height: fieldHeight
                )
            )
            contentHeight += fieldHeight + 12
        }
        
        if typeOfRole == .agencies {
            layoutField(nameAgency)
            layoutField(chooseCountryField)
            layoutField(websiteField)
            
            // Type title
            transition.updateFrame(
                node: self.typeNode,
                frame: CGRect(x: sideInset, y: contentHeight + 12, width: maximumWidth, height: typeTitleSize.height)
            )
            contentHeight += typeTitleSize.height + 16
            
            layoutField(agenciesCheckboxNode)
            layoutField(brandsCheckboxNode)
            
            chooseGenderField.isHidden = true
            ageSliderNode.isHidden = true
            chooseAgencyField.isHidden = true
        }
        
        if typeOfRole == .talent {
            layoutField(nameAgency)
            layoutField(chooseGenderField)
            layoutField(chooseCountryField)
            
            transition.updateFrame(
                node: ageSliderNode,
                frame: CGRect(x: 0, y: contentHeight, width: maximumWidth, height: 60)
            )
            contentHeight += 60 + 12
            
            websiteField.isHidden = true
            typeNode.isHidden = true
            agenciesCheckboxNode.isHidden = true
            brandsCheckboxNode.isHidden = true
            chooseAgencyField.isHidden = true
        }
        
        if typeOfRole == .model {
            layoutField(nameAgency)
            layoutField(chooseGenderField)
            layoutField(chooseCountryField)
            layoutField(chooseAgencyField)
            
            transition.updateFrame(
                node: ageSliderNode,
                frame: CGRect(x: 0, y: contentHeight, width: maximumWidth, height: 60)
            )
            contentHeight += 60 + 12
            
            websiteField.isHidden = true
            typeNode.isHidden = true
            agenciesCheckboxNode.isHidden = true
            brandsCheckboxNode.isHidden = true
        }
        
        if typeOfRole == .fan {
            layoutField(nameAgency)
            layoutField(chooseCountryField)
            
            ageSliderNode.isHidden = true
            websiteField.isHidden = true
            typeNode.isHidden = true
            agenciesCheckboxNode.isHidden = true
            brandsCheckboxNode.isHidden = true
            chooseGenderField.isHidden = true
            chooseAgencyField.isHidden = true
        }
        
        // MARK: - Content size
        
        contentHeight += 40
        
        transition.updateFrame(
            node: self.contentNode,
            frame: CGRect(x: 0, y: 0, width: layout.size.width, height: contentHeight)
        )
        
        self.scrollNode.view.contentSize = CGSize(
            width: layout.size.width,
            height: contentHeight
        )
        
        // MARK: - Fixed buttons
        
        let buttonWidth = (maximumWidth - 32.0 - 24.0) / 2.0
        let buttonHeight: CGFloat = 50.0
        let bottomInset: CGFloat = 50.0
        
        let backFrame = CGRect(
            x: floorToScreenPixels((layout.size.width - maximumWidth + 32.0) / 2.0),
            y: layout.size.height - buttonHeight - bottomInset,
            width: buttonWidth,
            height: buttonHeight
        )
        
        let saveFrame = CGRect(
            x: backFrame.maxX + 24,
            y: backFrame.minY,
            width: buttonWidth,
            height: buttonHeight
        )
        
        transition.updateFrame(node: self.backNode, frame: backFrame)
        transition.updateFrame(node: self.saveNode, frame: saveFrame)
    }
    
    func activateInput() {
        
    }
    
    func animateError() {
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        //        if textField === self.firstNameField.textField {
        //            self.lastNameField.textField.becomeFirstResponder()
        //        } else {
        //            let name = self.currentName
        //            self.signUpWithName?(name.0, name.1)
        //        }
        return false
    }
    
    @objc private func addPhotoPressed() {
        self.addPhoto()
    }
    
    @objc private func backButtonPressed() {
        back?()
    }
    
    @objc private func saveButtonPressed() {
        print("Save button pressed!")
        let typeId: Int32 = typeOfRole == .talent ? 1 : typeOfRole == .model ? 2 : 3
        let modelInfo = AuthorizationModelInfo(
            typeId: typeId,
            gender: 2,//chooseGenderField
            age: Int32(ageSliderNode.slider.value.rounded()),
            name: nameAgency.textField.text,
            agencyName: chooseAgencyField.textField.textField.text,
            countryCode: countryId,
            url: websiteField.textField.text)
        signUpWithName?(modelInfo)
    }
    
    @objc private func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.activeTextField = textField
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.activeTextField = nil
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == chooseCountryField.textField.textField {
            selectCountryCode?()
            return false
        } else if textField == chooseGenderField.textField.textField {
            selectGender?()
            return false
        } else if textField == chooseAgencyField.textField.textField {
            selectAgency?()
            return false
        } else {
            return true
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let activeTextField = self.activeTextField else {
            return
        }
        
        let textFieldFrameInView = self.view.convert(activeTextField.bounds, from: activeTextField)
        let bottomOfTextField = textFieldFrameInView.maxY
        let keyboardTopY = self.view.frame.size.height - keyboardFrame.height
        
        let offset: CGFloat
        if bottomOfTextField > keyboardTopY {
            offset = bottomOfTextField - keyboardTopY + 20
        } else {
            offset = 0
        }
        
        if offset > 0 {
            UIView.animate(withDuration: animationDuration, animations: {
                self.view.transform = CGAffineTransform(translationX: 0, y: -offset)
            })
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: animationDuration, animations: {
            self.view.transform = .identity
        })
    }
}
