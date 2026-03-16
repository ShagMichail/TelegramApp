import Foundation

public struct UserDetailResponse: Decodable {
    public let message: String?
    public let data: UserDetail
    public let errors: [String]?
}

public struct UserDetail: Decodable {
    public let id: Int
    public let fullName: String?
    public let gender: UserGender?
    public let birthday: String?
    public let city: UserCity?
    public let email: String?
    public let phone: String?
    public let photo: UserFile?
    public let avatar: UserFile?
    public let role: String?
    public let subrole: String?
    public let roleLabel: String?
    public let measuringSystem: String?
    public let pushNotifications: Bool?
    public let isRegistrationFinished: Bool?
    public let model: UserModelInfo?
    public let customer: UserCustomerInfo?
    public let agency: UserAgencyInfo?
    public let agencyEmployee: UserAgencyEmployeeInfo?
    public let statistic: UserStatistic?
    public let isFavorite: Bool?
    public let isFollowed: Bool?
    public let userRatingStatus: String?
    public let userSocialNetworks: [UserSocialNetwork]?
}

public struct UserGender: Decodable {
    public let id: String
    public let title: String
}

public struct UserCity: Decodable {
    public let id: Int
    public let countryCode: String?
    public let countryName: String?
    public let areaName: String?
    public let name: String?
}

public struct UserFile: Decodable {
    public let fileName: String?
    public let fullUrl: String?
    public let fileExtension: String?
    public let fileUuid: String?

    enum CodingKeys: String, CodingKey {
        case fileName, fullUrl
        case fileExtension = "extension"
        case fileUuid
    }
}

public struct UserModelInfo: Decodable {
    public let agency: UserAgencyInfo?
    public let education: String?
    public let workExperience: String?
    public let languages: String?
    public let profileUrl: String?
    public let additionalInformation: String?
    public let hasInternationalPassport: Bool?
    public let hasTattoo: Bool?
    public let hasPiercing: Bool?
    public let hasActingEducation: Bool?
    public let appearance: UserAppearance?
}

public struct UserAgencyRef: Decodable {
    public let id: Int?
    public let name: String?
}

public struct UserAppearance: Decodable {
    public let measuringSystem: String?
    public let height: Double?
    public let weight: Double?
    public let breastSize: String?
    public let waist: Double?
    public let hips: Double?
    public let shoesSize: Double?
    public let hairColor: UserColorOption?
    public let hairLength: UserColorOption?
    public let eyeColor: UserColorOption?
    public let skinColor: UserColorOption?
}

public struct UserColorOption: Decodable {
    public let id: Int?
    public let title: String?
}

public struct UserCustomerInfo: Decodable {
    public let companyName: String?
}

public struct UserAgencyInfo: Decodable {
    public let id: Int?
    public let title: String?
    public let site: String?
    public let email: String?
    public let description: String?
    public let employeeTitle: String?
    public let address: AgencyAddress?
    public let photo: UserFile?
    public let background: UserFile?
}

public struct AgencyAddress: Decodable {
    public let street: String?
    public let house: String?
    public let apartment: String?
    public let formatted: String?
    public let latitude: Double?
    public let longitude: Double?
    public let city: UserCity?
}
public struct UserAgencyEmployeeInfo: Decodable {
    public let agencyId: Int?
    public let position: String?
}

public struct UserStatistic: Decodable {
    public let followersCount: Int?
    public let followingCount: Int?
    public let viewsCount: Int?
    public let sentToAgenciesCount: Int?
    public let modelsCount: Int?
}

public struct UserSocialNetwork: Decodable {
    public let id: Int?
    public let type: String?
    public let url: String?
    public let username: String?
}

public extension Double {
    var clean: String {
        return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
    }
}
