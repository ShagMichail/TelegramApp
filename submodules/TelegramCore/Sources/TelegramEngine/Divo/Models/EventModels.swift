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
    public let fullUrl: String?
    public let fileExtension: String?
    public let fileUuid: String?

    enum CodingKeys: String, CodingKey {
        case order, fullUrl, fileUuid
        case fileExtension = "extension"
    }
}

// MARK: - Event Detail

public struct EventDetailResponse: Decodable {
    public let message: String?
    public let data: EventListItem
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

public struct CreateEventRequest: Encodable {
    public let title: String
    public let description: String
    public let typeId: Int
    public let date: String
    public let dateTo: String?
    public let address: CreateEventAddress?
    public let files: [CreateEventFile]?
    public let paymentType: Int?
    public let paymentFrequency: Int?
    public let cost: String?
    public let role: [String]?
    public let gender: [String]?
    public let age: RangeFilter?
    public let height: RangeFilter?
    public let weight: RangeFilter?

    public init(
        title: String,
        description: String,
        typeId: Int,
        date: String,
        dateTo: String? = nil,
        address: CreateEventAddress? = nil,
        files: [CreateEventFile]? = nil,
        paymentType: Int? = nil,
        paymentFrequency: Int? = nil,
        cost: String? = nil,
        role: [String]? = nil,
        gender: [String]? = nil,
        age: RangeFilter? = nil,
        height: RangeFilter? = nil,
        weight: RangeFilter? = nil
    ) {
        self.title = title
        self.description = description
        self.typeId = typeId
        self.date = date
        self.dateTo = dateTo
        self.address = address
        self.files = files
        self.paymentType = paymentType
        self.paymentFrequency = paymentFrequency
        self.cost = cost
        self.role = role
        self.gender = gender
        self.age = age
        self.height = height
        self.weight = weight
    }
}

public struct CreateEventAddress: Encodable {
    public let street: String?
    public let house: String?
    public let apartment: String?
    public let formatted: String?
    public let latitude: Double?
    public let longitude: Double?
    public let cityId: Int?

    public init(street: String? = nil, house: String? = nil, apartment: String? = nil, formatted: String? = nil, latitude: Double? = nil, longitude: Double? = nil, cityId: Int? = nil) {
        self.street = street
        self.house = house
        self.apartment = apartment
        self.formatted = formatted
        self.latitude = latitude
        self.longitude = longitude
        self.cityId = cityId
    }
}

public struct CreateEventFile: Encodable {
    public let order: Int
    public let fileUuid: String

    public init(order: Int, fileUuid: String) {
        self.order = order
        self.fileUuid = fileUuid
    }
}

public struct RangeFilter: Codable {
    public let from: Int
    public let to: Int

    public init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }
}

public struct CreateEventResponse: Decodable {
    public let message: String?
    public let data: EventListItem?
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
