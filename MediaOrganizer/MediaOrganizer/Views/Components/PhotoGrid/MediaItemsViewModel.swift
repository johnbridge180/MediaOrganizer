//
//  MediaItemsViewModel.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/24/22.
//

import Foundation
import MongoSwift
import CoreData

class MediaItemsViewModel: ObservableObject {
    let mongoHolder: MongoClientHolder
    let moc: NSManagedObjectContext
    weak var appDelegate: AppDelegate?

    @Published var isFetching: Bool = false
    @Published var itemOrder: [BSONObjectID] = []
    @Published var items: [BSONObjectID: MediaItemHolder] = [:]

    init(mongoHolder: MongoClientHolder, moc: NSManagedObjectContext, appDelegate: AppDelegate) {
        self.mongoHolder = mongoHolder
        self.moc = moc
        self.appDelegate = appDelegate
    }

    @MainActor
    func fetchRows(limit: Int=0, filter: BSONDocument) async throws {
        print("filter: \(filter)")
        isFetching = true
        if mongoHolder.client==nil {
            await mongoHolder.connect()
        }
        guard let client = mongoHolder.client else { return }
        let filesCollection = client.db("media_organizer").collection("files")
        var options = FindOptions(sort: ["time": -1])
        if limit>0 {
            options = FindOptions(limit: limit, sort: ["time": -1, "_id": -1])
        }
        var newItemOrder: [BSONObjectID] = []
        for try await doc in try await filesCollection.find(filter, options: options) {
            if let item: MediaItem = try? BSONDecoder().decode(MediaItem.self, from: doc) {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PreviewCache")
                fetchRequest.fetchLimit=1
                fetchRequest.predicate = NSPredicate(format: "oid_hex == %@", item._id.hex)
                let cacheRows = try moc.fetch(fetchRequest)
                if self.items[item._id] == nil {
                    let cacheRow = (!cacheRows.isEmpty ? (cacheRows[0] as? PreviewCache) : nil)
                    self.items[item._id] = MediaItemHolder(item: item, cacheRow: cacheRow)
                }
                newItemOrder.append(item._id)
            }
        }
        var i=0
        var j=0
        while i<itemOrder.count, j<newItemOrder.count, let curItem = self.items[itemOrder[i]]?.item, let newItem=self.items[newItemOrder[j]]?.item {
            if curItem.time>newItem.time {
                itemOrder.remove(at: i)
            } else if curItem.time==newItem.time {
                if curItem._id==newItem._id {
                    i+=1;j+=1
                } else if let curItemHexval = UInt64(curItem._id.hex, radix: 16), let newItemHexval = UInt64(newItem._id.hex, radix: 16), curItemHexval>newItemHexval {
                    itemOrder.remove(at: i)
                } else {
                    // curItem._id<newItem._id
                    itemOrder.insert(newItem._id, at: i)
                    i+=1;j+=1
                }
            } else {
                // curItem.time<newItem.time
                itemOrder.insert(newItem._id, at: i)
                i+=1;j+=1
            }
        }
        if i<itemOrder.count {
            itemOrder.removeSubrange(i...itemOrder.count-1)
        } else if j<newItemOrder.count {
            itemOrder.append(contentsOf: newItemOrder[j...newItemOrder.count-1])
        }
        cleanupUnusedItems()
        isFetching = false
    }

    private func cleanupUnusedItems() {
        let currentItemSet = Set(itemOrder)
        items = items.filter { currentItemSet.contains($0.key) }
    }
}
