//
//  MongoPhotoGridDataSource.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/28/25.
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
    private(set) var apiEndpointUrl: String
    
    private var mediaItemLookup: [String: MediaItem] = [:]
    
    init(mongoHolder: MongoClientHolder, filter: BSONDocument, limit: Int = 0, apiEndpointUrl: String) {
        self.mongoHolder = mongoHolder
        self.filter = filter
        self.limit = limit
        self.apiEndpointUrl = apiEndpointUrl
    }
    
    func getMediaItem(for itemId: String) -> MediaItem? {
        return mediaItemLookup[itemId]
    }
    
    @MainActor
    func loadItems() async throws {
        isLoading = true
        defer { isLoading = false }
        
        if mongoHolder.client == nil {
            await mongoHolder.connect()
        }
        
        guard let client = mongoHolder.client else { 
            throw PhotoGridError.connectionFailed
        }
        
        let filesCollection = client.db("media_organizer").collection("files")
        var options = FindOptions(sort: ["time": -1])
        if limit > 0 {
            options = FindOptions(limit: limit, sort: ["time": -1, "_id": -1])
        }
        
        var newItems: [PhotoGridItem] = []
        
        for try await doc in try await filesCollection.find(filter, options: options) {
            if let item: MediaItem = try? BSONDecoder().decode(MediaItem.self, from: doc) {
                let imageURL = createImageURL(for: item)
                let photoGridItem = PhotoGridItem(id: item._id.hex, imageURL: imageURL)
                newItems.append(photoGridItem)
                mediaItemLookup[item._id.hex] = item
            }
        }
        
        items = newItems
    }
    
    func loadMoreItems() async throws {
        // Implementation for pagination if needed in the future
    }
    
    private func createImageURL(for mediaItem: MediaItem) -> URL {
        let baseURL = apiEndpointUrl.isEmpty ? "http://localhost:8080" : apiEndpointUrl
        let urlString = "\(baseURL)/api/files/\(mediaItem._id.hex)/thumbnail"
        return URL(string: urlString) ?? URL(fileURLWithPath: "/dev/null")
    }
}

enum PhotoGridError: Error {
    case connectionFailed
    case loadingFailed(String)
}