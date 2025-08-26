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
    static let lowresTriggerWidth = 100.0

    let mongoHolder: MongoClientHolder
    let moc: NSManagedObjectContext
    weak var appDelegate: AppDelegate?

    let updateTypeQueue: DispatchQueue
    let makeCGImageQueue: DispatchQueue

    @Published var isFetching: Bool = false
    @Published var itemOrder: [BSONObjectID] = []
    @Published var items: [BSONObjectID: MediaItemHolder] = [:]

    private var itemVModels: [BSONObjectID: ThumbnailViewModel] = [:]

    private var lastScrollFrameUpdate: Date
    private var lastSeenZStackOrigin: CGFloat = 0.0
    private var lastResizeUpdate: Date

    init(mongoHolder: MongoClientHolder, moc: NSManagedObjectContext, appDelegate: AppDelegate) {
        self.mongoHolder=mongoHolder
        self.moc=moc
        self.appDelegate=appDelegate
        self.updateTypeQueue = DispatchQueue(label: "com.jbridge.updateTypeQueue", qos: .background)
        self.makeCGImageQueue = DispatchQueue(label: "com.jbridge.makeCGImageQueue", qos: .background)
        self.lastScrollFrameUpdate=Date()
        self.lastResizeUpdate=Date()
    }

    @MainActor
    func fetchRows(limit: Int=0, filter: BSONDocument) async throws {
        print("filter: \(filter)")
        isFetching=true
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
                if self.itemVModels[item._id] == nil || self.items[item._id] == nil {
                    let cacheRow = (!cacheRows.isEmpty ? (cacheRows[0] as? PreviewCache) : nil)
                    let itemVModel = ThumbnailViewModel(item, cacheRow: cacheRow, makeCGImageQueue: makeCGImageQueue)
                    self.itemVModels[item._id]=itemVModel
                    if let appDelegate = appDelegate {
                        self.items[item._id]=MediaItemHolder(item: item, cacheRow: cacheRow, view: ThumbnailView(appDelegate: appDelegate, thumbVModel: itemVModel))
                    }
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
        isFetching=false
    }

    func setStatus(for objects: [BSONObjectID], status: Int) {
        for object in objects {
            self.itemVModels[object]?.setDisplayType(status)
        }
    }

    func onScrollFrameUpdate(_ frame: CGRect, width: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat) {
        let lastScrollFrameUpdate=Date()
        let lastResizeUpdate=self.lastResizeUpdate
        self.lastScrollFrameUpdate=lastScrollFrameUpdate
        // might want to use NSOperationQueue later (slightly less wasteful of CPU resources maybe?)
        self.updateTypeQueue.asyncAfter(deadline: .now()+0.2) {
            if self.lastScrollFrameUpdate==lastScrollFrameUpdate && self.lastResizeUpdate==lastResizeUpdate {
                self.setRangeValues(isScrollUpdate: true, zstackOriginY: frame.origin.y, width: width, height: height, numColumns: numColumns, colWidth: colWidth)
            }
        }
    }

    func updateRangeValuesForResize(width: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat) {
        let lastResizeUpdate=Date()
        self.lastResizeUpdate=lastResizeUpdate
        self.updateTypeQueue.asyncAfter(deadline: .now()+0.5) {
            if self.lastResizeUpdate==lastResizeUpdate {
                self.setRangeValues(zstackOriginY: self.lastSeenZStackOrigin, width: width, height: height, numColumns: numColumns, colWidth: colWidth)
            }
        }
    }

    func setRangeValues(isScrollUpdate: Bool = false, zstackOriginY: CGFloat, width: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat) {
        if isScrollUpdate && abs(self.lastSeenZStackOrigin-zstackOriginY)<colWidth {
            return
        }
        self.lastSeenZStackOrigin=zstackOriginY
        if !self.isFetching, !self.itemOrder.isEmpty {
            let assumedIndexRange = self.getAssumedDisplayedIndexRange(zstackOriginY: zstackOriginY, height: height, numColumns: numColumns, colWidth: colWidth)
            if colWidth>MediaItemsViewModel.lowresTriggerWidth {
                let modifier = numColumns
                let bigthumbLowerBound = assumedIndexRange.lowerBound-modifier
                var bigthumbIndexRange = ((bigthumbLowerBound>0) ? bigthumbLowerBound : 0)...assumedIndexRange.upperBound+modifier
                bigthumbIndexRange=bigthumbIndexRange.clamped(to: 0...(itemOrder.count-1))
                self.setStatus(for: Array(itemOrder[bigthumbIndexRange]), status: 2)
                var tinyThumbOrder: [BSONObjectID] = []
                for i in 0..<itemOrder.count where !bigthumbIndexRange.contains(i) {
                    tinyThumbOrder.append(itemOrder[i])
                }
                self.setStatus(for: tinyThumbOrder, status: 1)
            } else {
                self.setStatus(for: Array(itemOrder[0...self.itemOrder.count-1]), status: 1)
            }
        }
    }
    func getAssumedDisplayedIndexRange(zstackOriginY: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat) -> ClosedRange<Int> {
        let maxNumRows: Int = colWidth==0 ? 0 : Int(ceil(height/colWidth))
        let assumedAmtDisplayed: Int = maxNumRows*numColumns
        // zstackOriginY will be negative after scrolling. Currently assuming that zstack starts with origin.y of 0, though it could potentially start elsewhere
        let numRowsAboveVisibleArea: Int = Int(zstackOriginY>0 || colWidth==0 ? 0 : abs(zstackOriginY)/colWidth)
        let startIndex: Int = numRowsAboveVisibleArea*numColumns
        return startIndex...(startIndex+assumedAmtDisplayed)
    }
}
