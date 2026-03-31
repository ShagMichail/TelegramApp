import Foundation
import UIKit
import TelegramCore

struct EventData {
    let id: Int
    let title: String
    let subtitle: String
    let imageName: String
    let profileImageName: String
    let profileName: String
    let timeRemaining: String
    let type: String
    let coverPhoto: TelegramMediaImage?
    let profilePhoto: TelegramMediaImage?
    let coverPhotoURL: String?
    let profilePhotoURL: String?
    let location: String
    let eventDateFormatted: String

    init(
        id: Int = 0,
        title: String,
        subtitle: String,
        imageName: String = "",
        profileImageName: String = "",
        profileName: String,
        timeRemaining: String,
        type: String = "",
        coverPhoto: TelegramMediaImage? = nil,
        profilePhoto: TelegramMediaImage? = nil,
        coverPhotoURL: String? = nil,
        profilePhotoURL: String? = nil,
        location: String = "",
        eventDateFormatted: String = ""
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
        self.profileImageName = profileImageName
        self.profileName = profileName
        self.timeRemaining = timeRemaining
        self.type = type
        self.coverPhoto = coverPhoto
        self.profilePhoto = profilePhoto
        self.coverPhotoURL = coverPhotoURL
        self.profilePhotoURL = profilePhotoURL
        self.location = location
        self.eventDateFormatted = eventDateFormatted
    }

    static func mockEvents() -> [EventData] {
        return [
            EventData(
                id: 1,
                title: "FASHION MODEL EVENT",
                subtitle: "Fashion Show",
                profileName: "@nyfw",
                timeRemaining: "4d : 4h : 0m",
                coverPhotoURL: "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "New York",
                eventDateFormatted: "May 27 \u{00B7} 5:00 PM"
            ),
            EventData(
                id: 2,
                title: "FASHION MODEL EVENT",
                subtitle: "Runway",
                profileName: "@nyfw",
                timeRemaining: "4d : 4h : 0m",
                coverPhotoURL: "https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "New York",
                eventDateFormatted: "May 27 \u{00B7} 5:00 PM"
            ),
            EventData(
                id: 3,
                title: "FASHION MODEL EVENT",
                subtitle: "Casting",
                profileName: "@nyfw",
                timeRemaining: "4d : 4h : 0m",
                coverPhotoURL: "https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "New York",
                eventDateFormatted: "May 27 \u{00B7} 5:00 PM"
            ),
            EventData(
                id: 4,
                title: "FASHION MODEL EVENT",
                subtitle: "Photo Shoot",
                profileName: "@nyfw",
                timeRemaining: "4d : 4h : 0m",
                coverPhotoURL: "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "New York",
                eventDateFormatted: "May 27 \u{00B7} 5:00 PM"
            ),
            EventData(
                id: 5,
                title: "FASHION MODEL EVENT",
                subtitle: "Fashion Week",
                profileName: "@nyfw",
                timeRemaining: "4d : 4h : 0m",
                coverPhotoURL: "https://images.unsplash.com/photo-1445205170230-053b83016050?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "New York",
                eventDateFormatted: "May 27 \u{00B7} 5:00 PM"
            ),
            EventData(
                id: 6,
                title: "FASHION MODEL EVENT",
                subtitle: "Gala",
                profileName: "@nyfw",
                timeRemaining: "4d : 4h : 0m",
                coverPhotoURL: "https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "New York",
                eventDateFormatted: "May 27 \u{00B7} 5:00 PM"
            ),
            EventData(
                id: 7,
                title: "HAUTE COUTURE SHOW",
                subtitle: "Fashion Show",
                profileName: "@parisfashion",
                timeRemaining: "2d : 11h : 30m",
                coverPhotoURL: "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "Paris",
                eventDateFormatted: "Jun 3 \u{00B7} 7:00 PM"
            ),
            EventData(
                id: 8,
                title: "RUNWAY CASTING",
                subtitle: "Casting",
                profileName: "@milanfw",
                timeRemaining: "6d : 2h : 15m",
                coverPhotoURL: "https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "Milan",
                eventDateFormatted: "Jun 5 \u{00B7} 10:00 AM"
            ),
            EventData(
                id: 9,
                title: "EDITORIAL SHOOT",
                subtitle: "Photo Shoot",
                profileName: "@vogueitalia",
                timeRemaining: "1d : 8h : 45m",
                coverPhotoURL: "https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "London",
                eventDateFormatted: "May 29 \u{00B7} 2:00 PM"
            ),
            EventData(
                id: 10,
                title: "BRAND LOOKBOOK",
                subtitle: "Photo Shoot",
                profileName: "@zara",
                timeRemaining: "9d : 0h : 20m",
                coverPhotoURL: "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "Barcelona",
                eventDateFormatted: "Jun 8 \u{00B7} 11:00 AM"
            ),
        ]
    }
}
