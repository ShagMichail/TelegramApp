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
                self?.uploadAvatarPhoto(image)
            }, videoCompletion: { image, asset, adjustments in
                self?.createEventNode.currentPhoto = image
                self?.uploadAvatarPhoto(image)
            })
        })

        self.createEventNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme, displayCodes: false, glass: true)
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
        self.createEventNode.onCreateEventTapped = { [weak self] in
            self?.createPressed()
        }
        self.createEventNode.onAddGalleryPhotoTapped = { [weak self] in
            if #available(iOS 14.0, *) {
                self?.openMultiPhotoPicker()
            }
        }
        self.createEventNode.loadEventTypesList = { [weak self] offset, limit in
            self?.loadEventTypesList(offset: offset, limit: limit)
        }

        self.loadAppearanceDictionary()
        self.loadGenderDictionary()

        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.loadEventTypesList(offset: 0, limit: 5)
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

    private func loadEventTypesList(offset: Int, limit: Int) {
        Task { @MainActor in
            do {
                let request = AgencyListRequest(offset: offset, limit: limit, title: nil)
                let response: AgencyListResponse = try await DivoAPIClient.shared.request(
                    path: "/event/types",
                    method: "POST",
                    body: request
                )

                self.createEventNode.loadEventTypesComplete(
                    response.data.items,
                    totalCount: response.data.pagination.meta.totalCount,
                    offset: offset
                )

            } catch {
                print("❌ Error loading event types list: \(error)")
                self.createEventNode.loadEventTypesComplete([], totalCount: 0, offset: offset)
            }
        }
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
    
    
    private func uploadAvatarPhoto(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        Task {
            do {
                let uploadResponse: FileUploadResponse = try await DivoAPIClient.shared.upload(
                    path: "/file/upload-file",
                    fileData: imageData,
                    fileName: "event_cover.jpg",
                    mimeType: "image/jpeg"
                )
                
                guard let fileUuid = uploadResponse.data?.uuid else {
                    throw DivoAPIError.unknown
                }
                
                await MainActor.run {
                    self.createEventNode.avatarFileUuid = fileUuid
                    print("✅ Cover photo uploaded successfully: \(fileUuid)")
                }
                
            } catch {
                await MainActor.run {
                    self.createEventNode.currentPhoto = nil
                    self.showAlert(text: "Failed to upload cover photo: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showAlert(text: String, completion: (() -> Void)? = nil) {
        Queue.mainQueue().async {
            let alertController = textAlertController(
                context: self.context,
                title: nil,
                text: text,
                actions:[
                    TextAlertAction(type: .defaultAction, title: "OK", action: {
                        completion?()
                    })
                ]
            )
            self.present(alertController, in: .window(.root))
        }
    }
    
    @objc private func createPressed() {
        self.view.endEditing(true)
        
        do {
            let requestPayload = try self.createEventNode.collectEventData()
            
            self.navigationItem.rightBarButtonItem?.isEnabled = false
            
            Task { @MainActor in
                do {
                    let response: CreateEventResponse = try await DivoAPIClient.shared.request(
                        path: "/event/create",
                        method: "POST",
                        body: requestPayload
                    )
                    
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    
                    if response.errors == nil || response.errors?.isEmpty == true {
                        self.showAlert(text: "Event successfully created!") { [weak self] in
                            guard let self = self else { return }
                            if let nav = self.navigationController as? NavigationController {
                                _ = nav.popViewController(animated: true)
                            } else {
                                self.dismiss()
                            }
                        }
                    } else {
                        let errorMsg = response.errors?.joined(separator: "\n") ?? "Unknown error"
                        self.showAlert(text: errorMsg)
                    }
                    
                } catch {
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    print("❌ Error creating event: \(error)")
                    self.showAlert(text: "Failed to create event: \(error.localizedDescription)")
                }
            }
            
        } catch {
            self.showAlert(text: error.localizedDescription)
        }
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