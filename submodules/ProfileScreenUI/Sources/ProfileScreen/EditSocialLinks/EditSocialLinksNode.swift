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

final class EditSocialLinksNode: ASDisplayNode, UITextFieldDelegate {
    
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
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
    
    private let scrollNode: ASScrollNode
    
    private let instagramTextField: DivoTextField
    private let tiktokTextField: DivoTextField
    private let telegramTextField: DivoTextField
    private let youtubeTextField: DivoTextField
    private let websiteTextField: DivoTextField
    
    private let applyButton: ASControlNode
    private let applyButtonSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.hidesWhenStopped = true
        return spinner
    }()
    private let addPhoto: () -> Void
    var showAlert: ((String) -> Void)?
    var saveSocialLinks: ((LinksData) -> Void)?

    private var linksData: LinksData
    
    init(context: AccountContext, presentationData: PresentationData, linksData: LinksData, addPhoto: @escaping () -> Void) {
        self.context = context
        self.addPhoto = addPhoto
        self.linksData = linksData
        
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.scrollNode = ASScrollNode()
        
        let tiktok = linksData.tiktokUrl
        let youtube = linksData.youtubeUrl 
        let telegram = linksData.telegramUrl 
        let instagram = linksData.instagramUrl 
        let website = linksData.websiteUrl

        self.instagramTextField = DivoTextField(title: instagram, prefix: "instagram.com/")
        self.tiktokTextField = DivoTextField(title: tiktok, prefix: "tiktok.com/")
        self.youtubeTextField = DivoTextField(title: youtube, prefix: "youtube.com/")
        self.telegramTextField = DivoTextField(title: telegram, prefix: "t.me/")
        
        self.websiteTextField = DivoTextField(title: website, prefix: "")
        self.websiteTextField.textField.attributedPlaceholder = NSAttributedString(
            string: "Enter your website",
            font: Font.bold(16),
            textColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
        )
        
        self.applyButton = ButtonWithIconNode(title: "Save", icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.applyButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        super.init()
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        
        self.addSubnode(self.scrollNode)
        
        self.scrollNode.addSubnode(self.instagramTextField)
        self.scrollNode.addSubnode(self.tiktokTextField)
        self.scrollNode.addSubnode(self.youtubeTextField)
        self.scrollNode.addSubnode(self.telegramTextField)
        self.scrollNode.addSubnode(self.websiteTextField)
        
        self.scrollNode.addSubnode(self.applyButton)
        self.applyButton.view.addSubview(self.applyButtonSpinner)
    }

    deinit {
        self.supportPeerDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
    }

    override func didLoad() {
        super.didLoad()
        self.applyButton.addTarget(self, action: #selector(self.applyButtonTapped), forControlEvents: .touchUpInside)
    }

    @objc private func applyButtonTapped() {
        let instagramHandle = self.instagramTextField.textField.text ?? ""
            let tiktokHandle = self.tiktokTextField.textField.text ?? ""
            let youtubeHandle = self.youtubeTextField.textField.text ?? ""
            let telegramHandle = self.telegramTextField.textField.text ?? ""
            let websiteHandle = self.websiteTextField.textField.text ?? ""

        let linksData = LinksData(
                tiktokUrl: constructFullURL(from: tiktokHandle, with: "tiktok.com/"),
                youtubeUrl: constructFullURL(from: youtubeHandle, with: "youtube.com/"),
                telegramUrl: constructFullURL(from: telegramHandle, with: "t.me/"),
                instagramUrl: constructFullURL(from: instagramHandle, with: "instagram.com/"),
                websiteUrl: constructFullURL(from: websiteHandle, with: "")
            )

        self.toggleSpinner(active: true)
        self.saveSocialLinks?(linksData)
    }

    func toggleSpinner(active: Bool) {
        if active {
            self.applyButtonSpinner.startAnimating()
            self.applyButton.alpha = 0.7
        } else {
            self.applyButtonSpinner.stopAnimating()
            self.applyButton.alpha = 1.0
        }
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        
        let topInset = navigationBarHeight
        self.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset))
        
        let sidePadding: CGFloat = 16.0
        let sectionSpacing: CGFloat = 24.0
        let itemHeight: CGFloat = 48.0
        
        var currentY: CGFloat = 30.0
        
        self.instagramTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        self.tiktokTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        self.youtubeTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing

        self.telegramTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing

        self.websiteTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        self.applyButton.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: 50.0))
        
        self.applyButtonSpinner.center = CGPoint(x: self.applyButton.bounds.midX, y: self.applyButton.bounds.midY)

        currentY += 70.0
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: currentY)
        self.readyValue = true
    }

    private func constructFullURL(from handle: String, with prefix: String) -> String {
        let trimmedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedHandle.isEmpty else {
            return ""
        }
        
        if trimmedHandle.hasPrefix("https://") || trimmedHandle.hasPrefix("http://") {
            return trimmedHandle
        }
        
        return "https://\(trimmedHandle)"
    }

    private func getTextFiel(title: String, isMultiline: Bool = false) -> TextFieldNode {
        let field = TextFieldNode()
        field.textField.font = Font.regular(16.0)
        field.textField.textColor = .white.withAlphaComponent(0.6)
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
}
