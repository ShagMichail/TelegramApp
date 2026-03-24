import Foundation
import TelegramCore

public struct ProfileModel {
    var name: String
    var lastName: String?
    let age: Int
    let location: String
    let mainImageName: String
    let avatarImageName: String
    let isVerified: Bool
    
    let likesCount: String
    let viewsCount: String
    let savesCount: String
    
    var biography: String
    
    let socialMediaIcons: [String] = ["instaIcon", "TikTokIcon", "youtubeIcon", "webIcon"]
    let socialMediaHandles: [String]
    
    let galleryImageNames: [String]
    let galleryImageURLs: [URL]
    
    let photos: [TelegramPeerPhoto]
    let isMyProfile: Bool

    let userId: Int?
    let role: String?
    let mainImageURL: URL?
    let avatarImageURL: URL?
    
    public init(
        name: String,
        lastName: String? = nil,
        age: Int,
        location: String,
        mainImageName: String,
        avatarImageName: String,
        isVerified: Bool,
        likesCount: String,
        viewsCount: String,
        savesCount: String,
        biography: String,
        socialMediaHandles: [String],
        galleryImageNames: [String],
        galleryImageURLs: [URL] = [],
        photos: [TelegramPeerPhoto] = [],
        isMyProfile: Bool = false,
        userId: Int? = nil,
        role: String? = nil,
        mainImageURL: URL? = nil,
        avatarImageURL: URL? = nil
    ) {
        self.name = name
        self.lastName = lastName
        self.age = age
        self.location = location
        self.mainImageName = mainImageName
        self.avatarImageName = avatarImageName
        self.isVerified = isVerified
        self.likesCount = likesCount
        self.viewsCount = viewsCount
        self.savesCount = savesCount
        self.biography = biography
        self.socialMediaHandles = socialMediaHandles
        self.galleryImageNames = galleryImageNames
        self.galleryImageURLs = galleryImageURLs
        self.photos = photos
        self.isMyProfile = isMyProfile
        self.userId = userId
        self.role = role
        self.mainImageURL = mainImageURL
        self.avatarImageURL = avatarImageURL
    }
}
