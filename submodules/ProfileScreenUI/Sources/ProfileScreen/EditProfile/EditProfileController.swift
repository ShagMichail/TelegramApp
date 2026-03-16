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
import MapResourceToAvatarSizes
import PhotosUI

public class EditProfileController: ViewController, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
    private let context: AccountContext

    private var createEventNode: EditProfileNode {
        return self.displayNode as! EditProfileNode
    }

    private var presentationData: PresentationData
    private var presentationDataDisposable: Any?
    private let userDetailData: UserDetail?
    private let updatePhoto: (UIImage?) -> Void
    
    public init(context: AccountContext, presentationData: PresentationData, userDetailData: UserDetail?, updatePhoto: @escaping (UIImage?) -> Void) {
        self.context = context
        self.userDetailData = userDetailData
        self.updatePhoto = updatePhoto
        
        self.presentationData = presentationData
        
        let darkNavigationTheme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: .white,
            disabledButtonColor: UIColor(rgb: 0x525252),
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .clear,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)
        
        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))

        super.init(navigationBarPresentationData: navigationBarData)
        
        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style
        
        self.title = "MY PROFILE"
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
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
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        (self.presentationDataDisposable as? Disposable)?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style
        let navTheme = NavigationBarTheme(
            overallDarkAppearance: true, 
            buttonColor: .white, 
            disabledButtonColor: UIColor(rgb: 0x525252), 
            primaryTextColor: .white, 
            backgroundColor: .clear, 
            opaqueBackgroundColor: .clear, 
            enableBackgroundBlur: false, 
            separatorColor: .clear, 
            badgeBackgroundColor: .clear, 
            badgeStrokeColor: .clear, 
            badgeTextColor: .clear
        )

        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: navTheme, strings: NavigationBarStrings(back: "Back", close: "Close")), transition: .immediate)
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = EditProfileNode(
            context: self.context,
            presentationData: self.presentationData,
            model: userDetailData
        )

        self.createEventNode.saveProfile = { [weak self] rawData in
            self?.handleSave(with: rawData)
        }

        self.createEventNode.showAlert = { [weak self] text in
            self?.showAlert(text: text)
        }
        
        self.createEventNode.onAvatarTap = { [weak self] in
            self?.openPhotoGallery()
        }

        self.displayNodeDidLoad()
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
    
    private var selectedAvatarImage: UIImage?
    
    private func openPhotoGallery() {
        print("📸 Opening photo gallery...")
        
        if #available(iOS 14, *) {
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            self.present(picker, animated: true)
        } else {
            // Fallback для iOS 13 - использовать UIImagePickerController
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self as UIImagePickerControllerDelegate & UINavigationControllerDelegate
            self.present(picker, animated: true)
        }
    }

    private func uploadAvatar(image: UIImage) {
        self.selectedAvatarImage = image
        self.createEventNode.toggleSpinner(active: false)
        
        print("✅ Avatar selected and ready to upload")
        // TODO: Здесь будет отправка на сервер через API
        // Пока просто показываем алерт
    }

    private func handleSave(with rawData: ProfileRawData) {
        print("▶️ Controller получил сырые данные. Начинаем сборку модели для API...")

        Task {
            do {
                await MainActor.run { self.createEventNode.toggleSpinner(active: true) }

                let request = UpdateProfileRequest(
                    fullName: rawData.fullName,
                    phone: rawData.phone,
                    timezone: rawData.timezone,
                    gender: rawData.gender,
                    birthday: rawData.birthday,
                    geoCityId: rawData.geoCityId,
                    measuringSystem: rawData.measuringSystem,
                    subrole: rawData.subrole,
                    pushNotifications: rawData.pushNotifications,
                    isRegistrationFinished: rawData.isRegistrationFinished,
                    photo: rawData.photo.flatMap { FileRequest($0) },
                    avatar: rawData.avatar.flatMap { FileRequest($0) },
                    model: rawData.model.map { model in
                        ModelRequest(
                            agencyId: model.agencyId,
                            profileUrl: model.profileUrl,
                            education: model.education,
                            workExperience: model.workExperience,
                            languages: model.languages,
                            hasInternationalPassport: model.hasInternationalPassport,
                            hasTattoo: model.hasTattoo,
                            hasPiercing: model.hasPiercing,
                            hasActingEducation: model.hasActingEducation,
                            appearance: AppearanceRequest(
                                measuringSystem: model.appearance.measuringSystem,
                                height: model.appearance.height,
                                weight: model.appearance.weight,
                                breastSize: model.appearance.breastSize,
                                waist: model.appearance.waist,
                                hips: model.appearance.hips,
                                shoesSize: model.appearance.shoesSize,
                                hairColor: model.appearance.hairColor,
                                hairLength: model.appearance.hairLength,
                                eyeColor: model.appearance.eyeColor,
                                skinColor: model.appearance.skinColor
                            )
                        )
                    },
                    customer: rawData.customer.map { customer in
                        CustomerRequest(
                            site: nil,
                            description: nil,
                            background: nil
                        )
                    }
                )

                let response: UpdateProfileResponse = try await DivoAPIClient.shared.request(
                    path: "/user/update-profile",
                    method: "POST",
                    body: request
                )

                print("✅ Профиль успешно сохранен на сервере: \(response.message ?? "OK")")

                await MainActor.run {
                    self.createEventNode.toggleSpinner(active: false)
                    self.showAlert(text: "Профиль успешно обновлен")

                    self.navigationController?.popViewController(animated: true)
                }

            } catch {
                print("❌ Ошибка при сохранении профиля: \(error)")
                await MainActor.run {
                    self.createEventNode.toggleSpinner(active: false)
                    self.showAlert(text: error.localizedDescription)
                }
            }
        }
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
}


// MARK: - PHPickerViewControllerDelegate
@available(iOS 14, *)
extension EditProfileController {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else {
            return
        }
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
            guard let self = self, let uiImage = image as? UIImage else {
                return
            }
            
            self.createEventNode.currentPhoto = uiImage
            self.createEventNode.toggleSpinner(active: true)
            self.uploadAvatar(image: uiImage)
        }
    }
}


// MARK: - UIImagePickerControllerDelegate

extension EditProfileController: UIImagePickerControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        if let editedImage = info[.editedImage] as? UIImage {
            handleSelectedImage(editedImage)
        } else if let originalImage = info[.originalImage] as? UIImage {
            handleSelectedImage(originalImage)
        }
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    private func handleSelectedImage(_ image: UIImage) {
        self.createEventNode.currentPhoto = image
        self.createEventNode.toggleSpinner(active: true)
        self.uploadAvatar(image: image)
    }
}
