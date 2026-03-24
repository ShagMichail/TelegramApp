import Foundation
import UIKit

struct StoryModel {
    let name: String
    let avatarName: String
    let isLive: Bool
    let isAdd: Bool?
}

struct CardModel {
    let name: String
    let mainImageName: String
    let avatarImageName: String
    let previewImagesName: [String]
    var userReaction: ReactionType?

    let userId: Int?
    let role: String?
    let mainImageURL: URL?
    let avatarImageURL: URL?
    let previewImageURLs: [URL]
    let likesCount: Int
    let isFavorite: Bool
    var isFollowed: Bool

    init(
        name: String,
        mainImageName: String = "",
        avatarImageName: String = "",
        previewImagesName: [String] = [],
        userReaction: ReactionType? = nil,
        userId: Int? = nil,
        role: String? = nil,
        mainImageURL: URL? = nil,
        avatarImageURL: URL? = nil,
        previewImageURLs: [URL] = [],
        likesCount: Int = 0,
        isFavorite: Bool = false,
        isFollowed: Bool = false
    ) {
        self.name = name
        self.mainImageName = mainImageName
        self.avatarImageName = avatarImageName
        self.previewImagesName = previewImagesName
        self.userReaction = userReaction
        self.userId = userId
        self.role = role
        self.mainImageURL = mainImageURL
        self.avatarImageURL = avatarImageURL
        self.previewImageURLs = previewImageURLs
        self.likesCount = likesCount
        self.isFavorite = isFavorite
        self.isFollowed = isFollowed
    }
}

enum ReactionType {
    case like
    case heart
    case dislike
    case fire
}

extension ReactionType: RawRepresentable {
    typealias RawValue = Int

    var rawValue: Int {
        switch self {
        case .like: return 1
        case .heart: return 2
        case .dislike: return 3
        case .fire: return 4
        }
    }

    init?(rawValue: Int) {
        switch rawValue {
        case 1: self = .like
        case 2: self = .heart
        case 3: self = .dislike
        case 4: self = .fire
        default: return nil
        }
    }
}
