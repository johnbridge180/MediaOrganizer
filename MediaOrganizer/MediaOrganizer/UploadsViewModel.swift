//
//  UploadsViewModel.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/29/22.
//

import Foundation
import MongoSwift

struct Upload: Codable, Hashable, Identifiable {
    var id: String {
        return _id.hex
    }
    
    var _id: BSONObjectID
    var time: Date
}

class UploadsViewModel: ObservableObject {
    var mongo_holder: MongoClientHolder
    
    @Published var isFetching: Bool = false
    @Published var uploads: [Upload] = []
    
    init(mongo_holder: MongoClientHolder) {
        self.mongo_holder=mongo_holder
    }
    
    @MainActor
    func fetchRows(start: Int) async throws {
        isFetching=true
        if(mongo_holder.client==nil) {
            await mongo_holder.connect()
        }
        let uploads_collection = mongo_holder.client!.db("media_organizer").collection("upload_groups")
        let options = FindOptions(sort: ["time":-1])
        for try await doc in try await uploads_collection.find([:], options: options) {
            if let upload: Upload = try? BSONDecoder().decode(Upload.self, from: doc) {
                uploads.append(upload)
            }
        }
        isFetching=false
    }
    
}
