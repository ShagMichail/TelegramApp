import UIKit

// MARK: - API Models for Create Event

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
    // Объект data можно не описывать целиком, если нужен только статус создания
}

// Простая ошибка для валидации UI
struct ValidationError: LocalizedError {
    let message: String
    var errorDescription: String? { return message }
}