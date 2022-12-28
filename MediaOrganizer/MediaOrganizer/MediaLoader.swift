//
//  PhotoLoader.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/24/22.
//

import Foundation
import MongoSwift

class MediaItemsViewModel: ObservableObject {
    var mongo_holder:MongoClientHolder? = nil
    
    @Published var isFetching:Bool = false
    @Published var items:[MediaItem] = []
    
    @MainActor
    func fetchRows(start: Int) async throws {
        isFetching=true
        if(mongo_holder?.client==nil) {
            await mongo_holder?.connect()
        }
        let files_collection = mongo_holder!.client!.db("media_organizer").collection("files")
        let options = FindOptions(limit: 500, sort: ["_id":-1])
        
        for try await doc in try await files_collection.find([:], options: options) {
            items.append(try BSONDecoder().decode(MediaItem.self, from: doc))
        }
        isFetching=false
    }
    
    func linkMongoClientHolder(_ mongo_holder: MongoClientHolder) {
        self.mongo_holder = mongo_holder
    }
}
