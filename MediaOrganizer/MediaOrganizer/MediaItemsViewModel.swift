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
    @Published var items:[MediaItemHolder] = []
    
    private var item_vModels:[ThumbViewModel] = []
    
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
        isFetching=true
        if(mongo_holder.client==nil) {
            await mongo_holder.connect()
        }
        let files_collection = mongo_holder.client!.db("media_organizer").collection("files")
        var options = FindOptions(sort: ["time":-1])
        if limit>0 {
            options = FindOptions(limit: limit, sort: ["time":-1])
        }
        var new_items: [MediaItemHolder] = []
        for try await doc in try await files_collection.find(filter, options: options) {
            if let item: MediaItem = try? BSONDecoder().decode(MediaItem.self, from: doc) {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PreviewCache")
                fetchRequest.fetchLimit=1
                fetchRequest.predicate = NSPredicate(format: "oid_hex == %@", item._id.hex)
                let cache_rows = try moc.fetch(fetchRequest)
                self.item_vModels.append(ThumbViewModel(item, cache_row: (cache_rows.count>0 ? (cache_rows[0] as? PreviewCache) : nil), makeCGImageQueue: makeCGImageQueue))
                let current_index = item_vModels.count-1
                
                new_items.append(MediaItemHolder(item: item, cache_row: (cache_rows.count>0 ? (cache_rows[0] as? PreviewCache) : nil), view: MediaThumbView(appDelegate: appDelegate, thumbVModel: self.item_vModels[current_index])))
            }
        }
        items.append(contentsOf: new_items)
        isFetching=false
    }
    
    func setStatus(for indexes: [Int], status: Int) {
        for i in indexes {
            if(i<item_vModels.count) {
                if(item_vModels[i].getDisplayType() != status) {
                    self.item_vModels[i].setDisplayType(status)
                }
            }
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
        if !self.isFetching, self.items.count>0 {
            let assumedIndexRange = self.getAssumedDisplayedIndexRange(zstack_origin_y: zstack_origin_y, height: height, numColumns: numColumns, colWidth: colWidth)
            let tinythumbIndexRange = self.items.startIndex...self.items.endIndex
            if colWidth>MediaItemsViewModel.lowresTriggerWidth {
                let modifier = numColumns
                let bigthumbLowerBound = assumedIndexRange.lowerBound-modifier
                let bigthumbIndexRange = ((bigthumbLowerBound>0) ? bigthumbLowerBound : 0)...assumedIndexRange.upperBound+modifier
                self.setStatus(for: Array(bigthumbIndexRange), status: 2)
                let tinythumbIndexes = tinythumbIndexRange.filter { i in
                    return !bigthumbIndexRange.contains(i)
                }
                self.setStatus(for: tinythumbIndexes, status: 1)
            } else {
                self.setStatus(for: Array(tinythumbIndexRange), status: 1)
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
