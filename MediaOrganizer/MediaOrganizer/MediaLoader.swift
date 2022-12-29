//
//  PhotoLoader.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/24/22.
//

import Foundation
import MongoSwift
import CoreData

class MediaItemsViewModel: ObservableObject {
    var mongo_holder:MongoClientHolder? = nil
    var moc: NSManagedObjectContext? = nil
    
    @Published var isFetching:Bool = false
    @Published var items:[MediaItemHolder] = []
    
    @MainActor
    func fetchRows(start: Int) async throws {
        isFetching=true
        if(mongo_holder?.client==nil) {
            await mongo_holder?.connect()
        }
        let files_collection = mongo_holder!.client!.db("media_organizer").collection("files")
        let options = FindOptions(limit: 500, sort: ["_id":-1])
        
        for try await doc in try await files_collection.find([:], options: options) {
            if let item: MediaItem = try? BSONDecoder().decode(MediaItem.self, from: doc) {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PreviewCache")
                fetchRequest.fetchLimit=1
                fetchRequest.predicate = NSPredicate(format: "oid_hex == %@", item._id.hex)
                let cache_rows = try moc?.fetch(fetchRequest)
                if((cache_rows?.count ?? 0)>0) {
                    items.append(MediaItemHolder(item: item, cache_row: cache_rows?[0] as? PreviewCache))
                } else {
                    items.append(MediaItemHolder(item: item, cache_row: nil))
                }
            }
        }
        isFetching=false
    }
    
    func linkMongoClientHolder(_ mongo_holder: MongoClientHolder) {
        self.mongo_holder = mongo_holder
    }
    
    func linkMOC(_ moc: NSManagedObjectContext) {
        self.moc=moc
    }
}
