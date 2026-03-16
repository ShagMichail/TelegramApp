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

private func getTextFiel(title: String) -> TextFieldNode {
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
    field.cornerRadius = 11.0
    field.clipsToBounds = true
    field.padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    
    return field
}

final class ChooseRoleControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let typeOfRole: TypeOfRole
    private let addPhoto: () -> Void
    
    private let titleNode: ASTextNode
    private let currentOptionNode: ASTextNode
    
    private let sectionTitleNode: ASTextNode 
    private let nameAgency: TextFieldNode
    private let chooseCountryField: TextFieldNode
    private var countryId: String = ""
    private let chooseGenderField: TextFieldNode
    private let chooseAgencyField: TextFieldNode
    private let websiteField: TextFieldNode
    
    private let ageSliderNode: AgeSliderNode
    
    private var activeTextField: UITextField?
    
    private let currentPhotoNode: ASImageNode
    private let addPhotoButton: HighlightableButtonNode
    private let backNode: ButtonWithIconNode
    private let saveNode: ButtonWithIconNode
    private let bottomSpacerNode = ASDisplayNode()

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
    var openTermsOfService: (() -> Void)?
    var back: (() -> Void)?

    var inProgress: Bool = false
    
    init(theme: PresentationTheme, strings: PresentationStrings, typeOfRole: String, addPhoto: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.addPhoto = addPhoto
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.typeOfRole = TypeOfRole(rawValue: typeOfRole) ?? .model
        
        var titleText = ""
        var nameAgencyText = ""
        
        switch self.typeOfRole {
        case .talent:
            titleText = "Apply as\na new talent"
            nameAgencyText = "Full Name"

        case .model:
            titleText = "Apply as a\nProfessional Model"
            nameAgencyText = "Full Name"

        case .agencies:
            titleText = "Apply as a\nAgencies & Brands"
            nameAgencyText = "Name Agency"
        }

        let divoTitleFont = UIFont(name: "HelveticaNeueLTCom-BdCn", size: 34.0) ?? Font.bold(34.0)
        let divoTitleStyle = NSMutableParagraphStyle()
        divoTitleStyle.alignment = .center
        self.titleNode.attributedText = NSAttributedString(string: titleText.uppercased(), attributes: [
            .font: divoTitleFont,
            .foregroundColor: UIColor.white,
            .kern: 0.5,
            .paragraphStyle: divoTitleStyle
        ])
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
        
        self.nameAgency = getTextFiel(title: nameAgencyText)
        self.websiteField = getTextFiel(title: "Enter name your website")
        self.chooseCountryField = getTextFiel(title: "Choose a country")
        self.chooseGenderField = getTextFiel(title: "Select a Gender")
        self.chooseAgencyField = getTextFiel(title: "Choose agency name")
        
        self.ageSliderNode = AgeSliderNode()
        
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
        self.addPhotoButton.setBackgroundImage(generateFilledCircleImage(diameter: 110.0, color: self.theme.list.itemAccentColor.withAlphaComponent(0.1), strokeColor: nil, strokeWidth: nil, backgroundColor: nil), for: .normal)
        
        let backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        let borderColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        self.addPhotoButton.setBackgroundImage(generateFilledCircleImage(diameter: 110.0, color: backgroundColor, strokeColor: borderColor, strokeWidth: 1.0, backgroundColor: nil), for: .normal)
        
        self.addPhotoButton.addSubnode(self.currentPhotoNode)
        self.addPhotoButton.allowsGroupOpacity = true

        let backIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"),
                                           color: .white)
        
        let imageSize: CGSize = CGSize(width: 24, height: 24)
        self.backNode = ButtonWithIconNode(title: "Back", icon: backIcon, theme: theme, spacing: 10, imageSize: imageSize)
        self.backNode.backgroundColor = UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.14)
        
        self.saveNode = ButtonWithIconNode(title: "Save", icon: nil, theme: theme, spacing: 10, imageSize: imageSize)
        self.saveNode.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.nameAgency.textField.delegate = self
        self.websiteField.textField.delegate = self
        self.chooseCountryField.textField.delegate = self
        self.chooseGenderField.textField.delegate = self
        self.chooseAgencyField.textField.delegate = self
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tapGesture)
        
        self.addSubnode(self.sectionTitleNode)
        self.addSubnode(self.websiteField)
        self.addSubnode(self.chooseCountryField)
        
        if self.typeOfRole != .agencies {
            self.addSubnode(self.ageSliderNode)
        }
        self.addSubnode(self.chooseGenderField)
        self.addSubnode(self.chooseAgencyField)
        self.addSubnode(self.nameAgency)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.currentOptionNode)
        self.addSubnode(self.addPhotoButton)
        
        self.addSubnode(self.backNode)
        self.addSubnode(self.saveNode)
        self.addSubnode(self.bottomSpacerNode)
        
        self.addPhotoButton.addTarget(self, action: #selector(self.addPhotoPressed), forControlEvents: .touchUpInside)
        self.backNode.addTarget(self, action: #selector(self.backButtonPressed), forControlEvents: .touchUpInside)
        
        self.saveNode.addTarget(self, action: #selector(self.saveButtonPressed), forControlEvents: .touchUpInside)
    }
    
    func updateData(firstName: String, lastName: String, hasTermsOfService: Bool) {
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }

    func updateCountry(countryId: String, countryName: String) {
        chooseCountryField.textField.text = countryName
        self.countryId = countryId
//        if let (layout, navigationHeight) = self.layoutArguments {
//            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
//        }
        
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let previousInputHeight = self.layoutArguments?.0.inputHeight ?? 0.0
        let newInputHeight = layout.inputHeight ?? 0.0
        
        self.layoutArguments = (layout, navigationBarHeight)
        
        var layout = layout
        if CACurrentMediaTime() - self.appearanceTimestamp < 2.0, newInputHeight < previousInputHeight {
            layout = layout.withUpdatedInputHeight(previousInputHeight)
        }
        
        let maximumWidth: CGFloat = min(430.0, layout.size.width)
        
        var insets = layout.insets(options: [.statusBar])
        if let inputHeight = layout.inputHeight {
            insets.bottom = max(inputHeight, layout.standardInputHeight)
        }
        
        let sideInset: CGFloat = 24.0
        let fieldHeight: CGFloat = 40.0
        let avatarSize: CGSize = CGSize(width: 100.0, height: 100.0)
        let fieldWidth = maximumWidth - sideInset * 2.0
        let centerX = floor(layout.size.width / 2.0)

        let titleSize = self.titleNode.measure(CGSize(width: fieldWidth, height: .greatestFiniteMagnitude))
        let noticeSize = self.currentOptionNode.measure(CGSize(width: fieldWidth, height: .greatestFiniteMagnitude))
        let sectionTitleSize = self.sectionTitleNode.measure(CGSize(width: fieldWidth, height: .greatestFiniteMagnitude))

        var y: CGFloat = max(navigationBarHeight, insets.top) + 60.0

        // Title
        self.titleNode.frame = CGRect(x: floor(centerX - titleSize.width / 2.0), y: y, width: titleSize.width, height: titleSize.height)
        y += titleSize.height + 16.0

        // Subtitle
        self.currentOptionNode.frame = CGRect(x: floor(centerX - noticeSize.width / 2.0), y: y, width: noticeSize.width, height: noticeSize.height)
        y += noticeSize.height + 20.0

        // Photo button
        self.addPhotoButton.frame = CGRect(x: floor(centerX - avatarSize.width / 2.0), y: y, width: avatarSize.width, height: avatarSize.height)
        self.currentPhotoNode.frame = CGRect(origin: .zero, size: avatarSize)
        y += avatarSize.height + 20.0

        // Section title
        self.sectionTitleNode.frame = CGRect(x: sideInset, y: y, width: fieldWidth, height: sectionTitleSize.height)
        y += sectionTitleSize.height + 12.0

        // Fields per role
        if typeOfRole == .agencies {
            self.nameAgency.frame = CGRect(x: sideInset, y: y, width: fieldWidth, height: fieldHeight)
            y += fieldHeight + 10.0
            self.chooseCountryField.frame = CGRect(x: sideInset, y: y, width: fieldWidth, height: fieldHeight)
            y += fieldHeight + 16.0
            self.websiteField.frame = CGRect(x: sideInset, y: y, width: fieldWidth, height: fieldHeight)
        }

        if typeOfRole == .talent {
            self.nameAgency.frame = CGRect(x: sideInset, y: y, width: fieldWidth, height: fieldHeight)
            y += fieldHeight + 10.0
            self.chooseGenderField.frame = CGRect(x: sideInset, y: y, width: fieldWidth, height: fieldHeight)
            y += fieldHeight + 10.0
            self.chooseCountryField.frame = CGRect(x: sideInset, y: y, width: fieldWidth, height: fieldHeight)
            y += fieldHeight + 20.0
            let ageSliderHeight: CGFloat = 60.0
            self.ageSliderNode.frame = CGRect(x: 0, y: y, width: maximumWidth, height: ageSliderHeight)
        }

        if typeOfRole == .model {
            self.nameAgency.frame = CGRect(x: sideInset, y: y, width: fieldWidth, height: fieldHeight)
            y += fieldHeight + 10.0
            self.chooseGenderField.frame = CGRect(x: sideInset, y: y, width: fieldWidth, height: fieldHeight)
            y += fieldHeight + 10.0
            self.chooseCountryField.frame = CGRect(x: sideInset, y: y, width: fieldWidth, height: fieldHeight)
            y += fieldHeight + 10.0
            self.chooseAgencyField.frame = CGRect(x: sideInset, y: y, width: fieldWidth, height: fieldHeight)
            y += fieldHeight + 20.0
            let ageSliderHeight: CGFloat = 60.0
            self.ageSliderNode.frame = CGRect(x: 0, y: y, width: maximumWidth, height: ageSliderHeight)
        }

        // Buttons
        let buttonHeight: CGFloat = 50.0
        let buttonWidth = (fieldWidth - 10.0) / 2.0
        let buttonY = layout.size.height - insets.bottom - buttonHeight - 24.0

        self.backNode.frame = CGRect(x: sideInset, y: buttonY, width: buttonWidth, height: buttonHeight)
        self.saveNode.frame = CGRect(x: sideInset + buttonWidth + 10.0, y: buttonY, width: buttonWidth, height: buttonHeight)
    }
    
    func activateInput() {
        
    }
    
    func animateError() {
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
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
            agencyName: chooseAgencyField.textField.text,
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
        if textField == chooseCountryField.textField {
            selectCountryCode?()
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
