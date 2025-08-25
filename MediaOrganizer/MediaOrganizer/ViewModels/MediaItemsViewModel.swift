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
    
    let mongo_holder:MongoClientHolder
    let moc: NSManagedObjectContext
    let appDelegate: AppDelegate
    
    let updateTypeQueue: DispatchQueue
    let makeCGImageQueue: DispatchQueue
    
    @Published var isFetching:Bool = false
    @Published var item_order:[BSONObjectID] = []
    @Published var items:[BSONObjectID:MediaItemHolder] = [:]
    
    private var item_vModels:[BSONObjectID:ThumbViewModel] = [:]
    
    private var lastScrollFrameUpdate: Date
    private var lastSeenZStackOrigin: CGFloat = 0.0
    private var lastResizeUpdate: Date
    
    init(mongo_holder: MongoClientHolder, moc: NSManagedObjectContext, appDelegate: AppDelegate) {
        self.mongo_holder=mongo_holder
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
        if(mongo_holder.client==nil) {
            await mongo_holder.connect()
        }
        let files_collection = mongo_holder.client!.db("media_organizer").collection("files")
        var options = FindOptions(sort: ["time":-1])
        if limit>0 {
            options = FindOptions(limit: limit, sort: ["time":-1,"_id":-1])
        }
        var new_item_order: [BSONObjectID] = []
        for try await doc in try await files_collection.find(filter, options: options) {
            if let item: MediaItem = try? BSONDecoder().decode(MediaItem.self, from: doc) {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PreviewCache")
                fetchRequest.fetchLimit=1
                fetchRequest.predicate = NSPredicate(format: "oid_hex == %@", item._id.hex)
                let cache_rows = try moc.fetch(fetchRequest)
                if self.item_vModels[item._id] == nil || self.items[item._id] == nil {
                    let cache_row = (cache_rows.count>0 ? (cache_rows[0] as? PreviewCache) : nil)
                    let item_vModel = ThumbViewModel(item, cache_row: cache_row, makeCGImageQueue: makeCGImageQueue)
                    self.item_vModels[item._id]=item_vModel
                    self.items[item._id]=MediaItemHolder(item: item, cache_row: cache_row, view: MediaThumbView(appDelegate: appDelegate, thumbVModel: item_vModel))
                }
                new_item_order.append(item._id)
            }
        }
        var i=0
        var j=0
        while i<item_order.count, j<new_item_order.count, let cur_item = self.items[item_order[i]]?.item, let new_item=self.items[new_item_order[j]]?.item {
            if cur_item.time>new_item.time {
                item_order.remove(at: i)
            } else if cur_item.time==new_item.time {
                if cur_item._id==new_item._id {
                    i+=1;j+=1
                } else if let cur_item_hexval = UInt64(cur_item._id.hex, radix: 16), let new_item_hexval = UInt64(new_item._id.hex, radix: 16), cur_item_hexval>new_item_hexval {
                    item_order.remove(at: i)
                } else {
                    //cur_item._id<new_item._id
                    item_order.insert(new_item._id, at: i)
                    i+=1;j+=1
                }
            } else {
                //cur_item.time<new_item.time
                item_order.insert(new_item._id, at: i)
                i+=1;j+=1
            }
        }
        if i<item_order.count {
            item_order.removeSubrange(i...item_order.count-1)
        } else if j<new_item_order.count {
            item_order.append(contentsOf: new_item_order[j...new_item_order.count-1])
        }
        isFetching=false
    }
    
    func setStatus(for objects: [BSONObjectID], status: Int) {
        for object in objects {
            self.item_vModels[object]?.setDisplayType(status)
        }
    }
    
    func onScrollFrameUpdate(_ frame: CGRect, width: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat) {
        let lastScrollFrameUpdate=Date()
        let lastResizeUpdate=self.lastResizeUpdate
        self.lastScrollFrameUpdate=lastScrollFrameUpdate
        //might want to use NSOperationQueue later (slightly less wasteful of CPU resources maybe?)
        self.updateTypeQueue.asyncAfter(deadline: .now()+0.2) {
            if self.lastScrollFrameUpdate==lastScrollFrameUpdate && self.lastResizeUpdate==lastResizeUpdate {
                self.setRangeValues(isScrollUpdate: true, zstack_origin_y: frame.origin.y, width: width, height: height, numColumns: numColumns, colWidth: colWidth)
            }
        }
    }
    
    func updateRangeValuesForResize(width: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat) {
        let lastResizeUpdate=Date()
        self.lastResizeUpdate=lastResizeUpdate
        self.updateTypeQueue.asyncAfter(deadline: .now()+0.5) {
            if self.lastResizeUpdate==lastResizeUpdate {
                self.setRangeValues(zstack_origin_y: self.lastSeenZStackOrigin, width: width, height: height, numColumns: numColumns, colWidth: colWidth)
            }
        }
    }
    
    func setRangeValues(isScrollUpdate: Bool = false, zstack_origin_y: CGFloat, width: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat) {
        if(isScrollUpdate && abs(self.lastSeenZStackOrigin-zstack_origin_y)<colWidth) {
            return
        }
        self.lastSeenZStackOrigin=zstack_origin_y
        if !self.isFetching, self.item_order.count>0 {
            let assumedIndexRange = self.getAssumedDisplayedIndexRange(zstack_origin_y: zstack_origin_y, height: height, numColumns: numColumns, colWidth: colWidth)
            if colWidth>MediaItemsViewModel.lowresTriggerWidth {
                let modifier = numColumns
                let bigthumbLowerBound = assumedIndexRange.lowerBound-modifier
                var bigthumbIndexRange = ((bigthumbLowerBound>0) ? bigthumbLowerBound : 0)...assumedIndexRange.upperBound+modifier
                bigthumbIndexRange=bigthumbIndexRange.clamped(to: 0...(item_order.count-1))
                self.setStatus(for: Array(item_order[bigthumbIndexRange]), status: 2)
                var tinyThumbOrder: [BSONObjectID] = []
                for i in 0..<item_order.count {
                    if !bigthumbIndexRange.contains(i) {
                        tinyThumbOrder.append(item_order[i])
                    }
                }
                self.setStatus(for: tinyThumbOrder, status: 1)
            } else {
                self.setStatus(for: Array(item_order[0...self.item_order.count-1]), status: 1)
            }
        }
    }
    func getAssumedDisplayedIndexRange(zstack_origin_y: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat) -> ClosedRange<Int> {
        let max_numRows: Int = colWidth==0 ? 0 : Int(ceil(height/colWidth))
        let assumed_amtDisplayed: Int = max_numRows*numColumns
        //zstack_origin_y will be negative after scrolling. Currently assuming that zstack starts with origin.y of 0, though it could potentially start elsewhere
        let numRowsAboveVisibleArea: Int = Int(zstack_origin_y>0 || colWidth==0 ? 0 : abs(zstack_origin_y)/colWidth)
        let start_index: Int = numRowsAboveVisibleArea*numColumns
        return start_index...(start_index+assumed_amtDisplayed)
    }
}
