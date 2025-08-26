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
    var mongoHolder: MongoClientHolder

    @Published var isFetching: Bool = false
    @Published var uploads: [Upload] = []

    var uploadCounts: [BSONObjectID: Int] = [:]

    init(mongoHolder: MongoClientHolder) {
        self.mongoHolder=mongoHolder
    }

    @MainActor
    func fetchRows(start: Int) async throws {
        isFetching=true
        if mongoHolder.client==nil {
            await mongoHolder.connect()
        }
        let uploadsCollection = mongoHolder.client!.db("media_organizer").collection("upload_groups")
        let options = FindOptions(sort: ["time": -1])
        for try await doc in try await uploadsCollection.find([:], options: options) {
            if let upload: Upload = try? BSONDecoder().decode(Upload.self, from: doc) {
                uploads.append(upload)
                let uploadCount = try await mongoHolder.client!.db("media_organizer").collection("files").countDocuments(["upload_id": BSON.objectID(upload._id)])
                uploadCounts[upload._id] = uploadCount
            }
        }
        isFetching=false
    }

}
