import Foundation

// MARK: - Event List

public struct EventListRequest: Encodable {
    public let offset: Int
    public let limit: Int

    public init(offset: Int, limit: Int) {
        self.offset = offset
        self.limit = limit
    }
}

public struct EventListResponse: Decodable {
    public let message: String?
    public let data: EventListData
}

public struct EventListData: Decodable {
    public let items: [EventListItem]
    public let pagination: EventPagination?
}

public struct EventPagination: Decodable {
    public let offset: Int?
    public let limit: Int?
    public let total: Int?
    public let currentOffset: Int?
    public let totalCount: Int?
}

public struct EventListItem: Decodable {
    public let id: Int
    public let title: String
    public let description: String?
    public let date: String?
    public let dateTo: String?
    public let type: EventTypeItem?
    public let address: EventAddress?
    public let user: EventUser?
    public let files: [EventFile]?
    public let likesCount: Int?
    public let isLikedByUser: Bool?
    public let appliesCount: Int?
    public let paymentType: Int?
    public let cost: String?
}

public struct EventTypeItem: Decodable {
    public let id: Int
    public let title: String
}

public struct EventAddress: Decodable {
    public let street: String?
    public let house: String?
    public let apartment: String?
    public let formatted: String?
    public let latitude: Double?
    public let longitude: Double?
    public let city: EventCity?
}

public struct EventCity: Decodable {
    public let id: Int?
    public let title: String?
}

public struct EventUser: Decodable {
    public let id: Int
    public let fullName: String?
    public let role: String?
    public let avatar: EventFileInfo?
}

public struct EventFileInfo: Decodable {
    public let fullUrl: String?
    public let uuid: String?
}

public struct EventFile: Decodable {
    public let order: Int?
    public let fileName: String?
    public let fullUrl: String?
    public let fileExtension: String?
    public let fileUuid: String?

    enum CodingKeys: String, CodingKey {
        case order, fullUrl, fileUuid, fileName
        case fileExtension = "extension"
    }
}


public struct EventListProfileResponse: Decodable {
    public let message: String?
    public let data: EventListProfileData
    public let error: String?
}

public struct EventListProfileData: Decodable {
    public let items: [EventListProfileItem]
    public let pagination: Pagination?
}

public struct EventListProfileItem: Decodable {
    public let id: Int
    public let title: String
    public let description: String?
    public let type: String?
    public let likesCount: Int?
    public let appliesCount: Int?
    public let isLikedByUser: Bool?
    public let creator: Creator?
    public let files: [EventFile]?
}

public struct Creator: Decodable {
    public let id: Int
    public let fullName: String?
    public let role: String?
    public let photo: UserFile?
    public let avatar: UserFile?
}

// MARK: - Event Detail

public struct EventDetailResponse: Decodable {
    public let message: String?
    public let data: EventListItem
}

public struct EventDetailProfileResponse: Codable {
    public let message: String?
    public let data: EventDetailData?
    public let errors: [String]?
}

public struct EventDetailData: Codable {
    public let id: Int
    public let title: String?
    public let description: String?
    public let date: String?
    public let dateTo: String?
    public let address: EventDetailAddress?
    public let files: [EventDetailFile]?
}

public struct EventDetailAddress: Codable {
    public let formatted: String?
    public let city: EventDetailCity?
}

public struct EventDetailCity: Codable {
    public let countryCode: String?
    public let countryName: String?
    public let name: String?
}

public struct EventDetailFile: Codable {
    public let order: Int?
    public let fullUrl: String?
}

// MARK: - Event Types

public struct EventTypesRequest: Encodable {
    public let offset: Int
    public let limit: Int

    public init(offset: Int, limit: Int) {
        self.offset = offset
        self.limit = limit
    }
}

public struct EventTypesResponse: Decodable {
    public let message: String?
    public let data: EventTypesData
}

public struct EventTypesData: Decodable {
    public let items: [EventTypeItem]
}

// MARK: - Create Event

public struct CreateEventRequest: Codable {
    public let title: String
    public let description: String
    public let typeId: Int
    public let date: String
    public let dateTo: String
    public let address: EventAddressRequest
    public let measuringSystem: String
    public let files:[EventFileRequest]

    public let paymentType: Int?
    public let paymentFrequency: Int?
    public let cost: String?

    public let role: [String]?
    public let gender: [String]?
    public let age: EventRangeRequest?
    public let height: EventRangeRequest?
    public let weight: EventRangeRequest?
    public let breastSize: EventRangeRequest?
    public let waist: EventRangeRequest?
    public let hips: EventRangeRequest?
    public let shoesSize: EventRangeRequest?
    public let hairColor: [Int]?
    public let hairLength: [Int]?
    public let eyeColor: [Int]?
    public let skinColor: [Int]?

    public init(
        title: String,
        description: String,
        typeId: Int,
        date: String,
        dateTo: String,
        address: EventAddressRequest,
        measuringSystem: String,
        files: [EventFileRequest],
        paymentType: Int?,
        paymentFrequency: Int?,
        cost: String?,
        role: [String]?,
        gender: [String]?,
        age: EventRangeRequest?,
        height: EventRangeRequest?,
        weight: EventRangeRequest?,
        breastSize: EventRangeRequest?,
        waist: EventRangeRequest?,
        hips: EventRangeRequest?,
        shoesSize: EventRangeRequest?,
        hairColor: [Int]?,
        hairLength: [Int]?,
        eyeColor: [Int]?,
        skinColor: [Int]?
    ) {
        self.title = title
        self.description = description
        self.typeId = typeId
        self.date = date
        self.dateTo = dateTo
        self.address = address
        self.measuringSystem = measuringSystem
        self.files = files
        self.paymentType = paymentType
        self.paymentFrequency = paymentFrequency
        self.cost = cost
        self.role = role
        self.gender = gender
        self.age = age
        self.height = height
        self.weight = weight
        self.breastSize = breastSize
        self.waist = waist
        self.hips = hips
        self.shoesSize = shoesSize
        self.hairColor = hairColor
        self.hairLength = hairLength
        self.eyeColor = eyeColor
        self.skinColor = skinColor
    }
}

public struct EventAddressRequest: Codable {
    public let street: String?
    public let house: String?
    public let apartment: String?
    public let formatted: String?
    public let latitude: Double?
    public let longitude: Double?
    public let cityId: Int

    public init(
        street: String?, 
        house: String?, 
        apartment: String?,
        formatted: String?, 
        latitude: Double?, 
        longitude: Double?, 
        cityId: Int
    ) {
        self.street = street
        self.house = house
        self.apartment = apartment
        self.formatted = formatted
        self.latitude = latitude
        self.longitude = longitude
        self.cityId = cityId
    }
}

public struct EventFileRequest: Codable {
    public let order: Int
    public let fileUuid: String

    public init(
        order: Int, 
        fileUuid: String
    ) {
        self.order = order
        self.fileUuid = fileUuid
    }
}

public struct EventRangeRequest: Codable {
    public let from: Float
    public let to: Float

    public init(
        from: Float, 
        to: Float
    ) {
        self.from = from
        self.to = to
    }
}

public struct CreateEventResponse: Codable {
    public let message: String?
    public let errors: [String]?

    public init(
        message: String?, 
        errors: [String]?
    ) {
        self.message = message
        self.errors = errors
    }
}

// MARK: - Apply

public struct ApplyEventRequest: Encodable {
    public let eventId: Int

    public init(eventId: Int) {
        self.eventId = eventId
    }
}

public struct ApplyEventResponse: Decodable {
    public let message: String?
}


public struct EventFullDetailResponse: Decodable {
    public let message: String?
    public let data: EventFullDetailData?
    public let errors:[String]?
}

public struct EventFullDetailData: Decodable {
    public let id: Int
    public let title: String?
    public let description: String?
    public let type: EventFullIdTitle?
    public let isApplied: Bool?
    public let appliesCount: Int?
    public let viewsCount: Int?
    public let userReachCount: Int?
    public let date: String?
    public let dateTo: String?
    public let paymentType: EventFullIdTitle?
    public let paymentFrequency: EventFullIdTitle?
    public let cost: String?
    public let address: EventFullAddress?
    public let files: [EventFullDetailFile]?
    public let modelAttributes: EventFullModelAttributes?
    public let creator: EventFullCreator?
}

// MARK: - Address & City
public struct EventFullAddress: Decodable {
    public let street: String?
    public let house: String?
    public let apartment: String?
    public let formatted: String?
    public let latitude: Double?
    public let longitude: Double?
    public let city: EventFullDetailCity? // Исправлено: в JSON тут "city", а не "cityId"
}

public struct EventFullDetailCity: Decodable {
    public let id: Int?
    public let countryCode: String?
    public let countryName: String?
    public let areaName: String? 
    public let name: String?
}

// MARK: - Files
public struct EventFullDetailFile: Decodable {
    public let order: Int?
    public let fileName: String?
    public let fullUrl: String?
    public let fileUuid: String?
    public let fileExtension: String?

    enum CodingKeys: String, CodingKey {
        case order, fullUrl, fileName, fileUuid
        case fileExtension = "extension"
    }
}

// MARK: - Model Attributes
public struct EventFullModelAttributes: Decodable {
    public let role: [String]?
    public let age: EventFullRange?
    public let gender: [EventFullStringIdTitle]?
    public let height: EventFullRange?
    public let weight: EventFullRange?
    public let breastSize: EventFullRange?
    public let waist: EventFullRange?
    public let hips: EventFullRange?
    public let shoesSize: EventFullRange?
    
    public let hairColor: [EventFullIdTitle]?
    public let hairLength: [EventFullIdTitle]?
    public let eyeColor: [EventFullIdTitle]?
    public let skinColor: [EventFullIdTitle]?
    
    public let measuringSystem: String?
}

public struct EventFullRange: Decodable {
    public let from: Float?
    public let to: Float?
}

// MARK: - Creator
public struct EventFullCreator: Decodable {
    public let id: Int?
    public let fullName: String?
    // У creator'а photo и avatar имеют ту же структуру, что и файлы, только без order
    public let photo: EventFullDetailFile?
    public let avatar: EventFullDetailFile?
    public let roleLabel: String?
}

// MARK: - Helpers (Для простых объектов {id, title})
public struct EventFullIdTitle: Decodable {
    public let id: Int?
    public let title: String?
}

public struct EventFullStringIdTitle: Decodable {
    public let id: String? // Для таких вещей как "gender": [{"id": "male", "title": "Male"}]
    public let title: String?
}
