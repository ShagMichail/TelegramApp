import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import MessageUI
import TelegramPresentationData
import AccountContext
import ShareController
import AlertUI
import PresentationDataUtils
import SearchUI
import LegacyMediaPickerUI
import CountrySelectionUI
import ChatScheduleTimeController
import Postbox
import PhotosUI

public class CreateEventController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext

    private var createEventNode: CreateEventNode {
        return self.displayNode as! CreateEventNode
    }

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    public init(context: AccountContext) {
        self.context = context

        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let copperColor = UIColor(hexString: "#BF7A54") ?? .black

        let darkNavigationTheme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: copperColor,
            disabledButtonColor: copperColor.withAlphaComponent(0.4),
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .black,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)

        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))

        super.init(navigationBarPresentationData: navigationBarData)

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style

        let titleLabel = UILabel()
        let titleFont = UIFont(name: "HelveticaNeueLTCom-BdCn", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold)
        let titleAttr = NSAttributedString(string: "CREATE EVENT", attributes: [
            .font: titleFont,
            .foregroundColor: UIColor.black,
            .kern: 0.5
        ])
        
        titleLabel.attributedText = titleAttr
        titleLabel.textAlignment = .center
        titleLabel.frame = CGRect(x: 0, y: 0, width: 200, height: 44)
        self.navigationItem.titleView = titleLabel

        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)

        let createFont = UIFont(name: "HelveticaNeueLTCom-BdCn", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .bold)
        let createButton = UIBarButtonItem(
            title: "Create",
            style: .plain,
            target: self,
            action: #selector(createPressed)
        )
        createButton.setTitleTextAttributes([
            .foregroundColor: copperColor,
            .font: createFont
        ], for: .normal)
        createButton.setTitleTextAttributes([
            .foregroundColor: copperColor.withAlphaComponent(0.5),
            .font: createFont
        ], for: .highlighted)
        self.navigationItem.rightBarButtonItem = createButton

        self.presentationDataDisposable = (context.sharedContext.presentationData
                                           |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings

                strongSelf.presentationData = presentationData

                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        }).strict()
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.presentationDataDisposable?.dispose()
    }

    override public func loadDisplayNode() {
        let currentAvatarMixin = Atomic<NSObject?>(value: nil)
        let theme = self.presentationData.theme

        self.displayNode = CreateEventNode(context: self.context, addPhoto: { [weak self] in
            presentLegacyAvatarPicker(holder: currentAvatarMixin, signup: true, theme: theme, present: { c, a in
                self?.view.endEditing(true)
                self?.present(c, in: .window(.root), with: a)
            }, openCurrent: nil, completion: { image in
                self?.createEventNode.currentPhoto = image
            }, videoCompletion: { image, asset, adjustments in
                self?.createEventNode.currentPhoto = image
            })
        })

        self.createEventNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme, displayCodes: false)
                controller.completeWithCountryCode = { _, countryId, name in

                    if let strongSelf = self {
                        strongSelf.createEventNode.updateCountry(countryId: countryId, countryName: name)
                    }
                }
                controller.dismissed = {

                }
                strongSelf.push(controller)
            }
        }

        self.createEventNode.scheduleTimeController = { [weak self] mode in
            self?.scheduleTimeController(mode: mode)
        }
        self.createEventNode.showAlert = { [weak self] text in
            self?.showAlert(text: text)
        }
        self.createEventNode.onAddParametersTapped = { [weak self] selectedParams in
            self?.showParametersSheet(currentSelection: selectedParams)
        }
        self.createEventNode.onAddGalleryPhotoTapped = { [weak self] in
            if #available(iOS 14.0, *) {
                self?.openMultiPhotoPicker()
            }
        }

        self.loadAppearanceDictionary()
        self.loadGenderDictionary()

        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.createEventNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData), transition: .immediate)

        self.title = "Create event"

        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }

    private func loadAppearanceDictionary() {
        Task { @MainActor in
            do {
                let response: AppearanceDictionaryResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/appearances",
                    method: "GET"
                )
                
                self.createEventNode.configureAppearanceDictionaries(response.data)
            } catch {
                print("❌ Error loading appearance dictionary: \(error)")
                self.showAlert(text: "Failed to load appearance options.")
            }
        }
    }
    
    private func loadGenderDictionary() {
        Task { @MainActor in
            do {
                let response: GenderResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/gender",
                    method: "GET"
                )
                
                self.createEventNode.configureGenderDictionaries(response)
            } catch {
                print("❌ Error loading appearance dictionary: \(error)")
                self.showAlert(text: "Failed to load appearance options.")
            }
        }
    }

    private func showAlert(text: String) {

        let alertController = textAlertController(
            context: context, title: nil,
            text: text, actions: [
                TextAlertAction(type: .genericAction, title: "Ok", action: {
                    print("ok")
                })
            ])
        present(alertController, in: .window(.root))
    }

    private func scheduleTimeController(mode: TimeControllerMode) {
        let peerId = PeerId(0)
        let controller = TimeController(
            context: context,
            updatedPresentationData: nil,
            peerId: peerId,
            mode: mode,
            style: .default,
            currentTime: nil,
            minimalTime: nil,
            completion: { [weak self] time in
                self?.createEventNode.updateTime(time, mode)
            })
        present(controller, in: .window(.root))
    }
    
    private func showParametersSheet(currentSelection: Set<EventParameter>) {
        let sheet = EventParametersSheetController(selectedParameters: currentSelection) { [weak self] newSelection in
            self?.createEventNode.updateSelectedParameters(newSelection)
        }
        self.present(sheet, animated: true)
    }

    @objc private func createPressed() {
        self.createEventNode.applyButtonTapped()
    }
}

@available(iOS 14.0, *)
extension CreateEventController: PHPickerViewControllerDelegate {
    
    private func openMultiPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 10
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        self.present(picker, animated: true)
    }
    
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        for result in results {
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                    guard let self = self, let uiImage = object as? UIImage else { return }
                    
                    let normalized = uiImage.fixedOrientation()
                    
                    DispatchQueue.main.async {
                        let item = self.createEventNode.startPhotoUpload(image: normalized)
                        
                        self.uploadEventPhoto(image: normalized, item: item)
                    }
                }
            }
        }
    }

    private func uploadEventPhoto(image: UIImage, item: EventGalleryItem) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            self.createEventNode.cancelPhotoUpload(item: item)
            return
        }

        Task {
            do {
                let uploadResponse: FileUploadResponse = try await DivoAPIClient.shared.upload(
                    path: "/file/upload-file",
                    fileData: imageData,
                    fileName: "event_photo.jpg",
                    mimeType: "image/jpeg"
                )

                guard let fileUuid = uploadResponse.data?.uuid else {
                    throw DivoAPIError.unknown
                }

                await MainActor.run {
                    self.createEventNode.finishPhotoUpload(item: item, fileUuid: fileUuid)
                }

            } catch {
                await MainActor.run {
                    self.createEventNode.cancelPhotoUpload(item: item)
                    self.showAlert(text: "Failed to upload photo: \(error.localizedDescription)")
                }
            }
        }
    }
}