//
//  MongoPhotoGridDataSource.swift
//  MediaOrganizer
//
//  Created on 9/15/25.
//

import Foundation
import SwiftUI
import SwiftBSON
import MongoSwift

class MongoPhotoGridDataSource: PhotoGridDataSource {
    @Published var items: [PhotoGridItem] = []
    @Published var isLoading: Bool = false

    private let mongoHolder: MongoClientHolder
    private let filter: BSONDocument
    private let limit: Int
    let apiEndpointUrl: String

    private var mediaItems: [String: MediaItem] = [:]

    init(mongoHolder: MongoClientHolder, filter: BSONDocument, limit: Int, apiEndpointUrl: String) {
        self.mongoHolder = mongoHolder
        self.filter = filter
        self.limit = limit
        self.apiEndpointUrl = apiEndpointUrl
    }

    @MainActor
    func loadItems(offset: Int = 0, length: Int = 0) async throws {
        isLoading = true
        defer { isLoading = false }

        if mongoHolder.client == nil {
            await mongoHolder.connect()
        }

        guard let client = mongoHolder.client else {
            throw PhotoGridError.networkError(NSError(domain: "MongoConnection", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not connect to MongoDB"]))
        }

        let filesCollection = client.db("media_organizer").collection("files")
        var options = FindOptions(sort: ["time": -1])

        let effectiveLimit = length > 0 ? length : limit
        if effectiveLimit > 0 {
            options = FindOptions(limit: effectiveLimit, skip: offset, sort: ["time": -1, "_id": -1])
        } else if offset > 0 {
            options = FindOptions(skip: offset, sort: ["time": -1, "_id": -1])
        }

        var newItems: [PhotoGridItem] = []
        var newMediaItems: [String: MediaItem] = [:]

        for try await doc in try await filesCollection.find(filter, options: options) {
            if let item: MediaItem = try? BSONDecoder().decode(MediaItem.self, from: doc) {
                let gridItem = PhotoGridItem(
                    id: item._id.hex,
                    imageURL: URL(string: apiEndpointUrl + "?request=thumbnail&oid=" + item._id.hex) ?? URL(fileURLWithPath: "/")
                )
                newItems.append(gridItem)
                newMediaItems[item._id.hex] = item
            }
        }

        if offset == 0 {
            self.items = newItems
            self.mediaItems = newMediaItems
        } else {
            self.items.append(contentsOf: newItems)
            self.mediaItems.merge(newMediaItems) { _, new in new }
        }
    }

    func getMediaItem(for id: String) -> MediaItem? {
        return mediaItems[id]
    }
}
