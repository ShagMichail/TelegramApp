//
//  UserGalleryModels.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.03.2026.
//

public struct GalleryListRequest: Encodable {
    public let offset: Int
    public let limit: Int
    public let userId: Int

    public init(offset: Int, limit: Int, userId: Int) {
        self.offset = offset
        self.limit = limit
        self.userId = userId
    }
}

public struct UserGalleryResponse: Decodable {
    public let message: String?
    public let data: UserPhotos
    public let errors: [String]?
}

public struct UserPhotos: Decodable {
    public let items: [UserPhoto]
    public let pagination: Pagination
}

public struct UserPhoto: Decodable {
    public let id: Int
    public let photo: UserFile
    public let likesCount: Int
    public let isLikedByUser: Bool
    public let preview: UserFile?
}

public struct Pagination: Decodable {
    public let meta: Meta
}

public struct Meta: Decodable {
    public let limit: Int
    public let currentOffset: Int
    public let totalCount: Int
}
