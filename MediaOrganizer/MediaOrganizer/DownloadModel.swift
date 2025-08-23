//
//  Download.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/7/23.
//

import Foundation
import CoreData
import SwiftUI

class DownloadModel: ObservableObject {
    let item: MediaItem
    var name: String
    let time: Date
    let source: URL
    let destination: URL
    let operation: DownloadOperation

    @Published var progress: Double = 0.0
    @Published var completed: Bool = false
    
    var totalBytes: Int64 = 0
    var bytesWritten: Int64 = 0
    
    var stateLock = NSLock()
    
    init(_ item: MediaItem, name: String, time: Date, source: URL, destination: URL, operation: DownloadOperation) {
        self.item=item
        self.name=name
        self.time=time
        self.totalBytes=item.size
        self.source=source
        self.destination=destination
        self.operation=operation
    }
    
    func setProgress(_ progress: Double, bytesWritten: Int64, totalBytes: Int64) async {
        stateLock.withLock {
            if(bytesWritten>self.bytesWritten) {
                self.bytesWritten=bytesWritten
                self.totalBytes=totalBytes
                //following line should trigger objectWillChange.send(), may be able to remove the explicit call on lines 37-39
                DispatchQueue.main.async {
                    self.progress=progress
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    func setCompleted() {
        operation.setFinished()
        DispatchQueue.main.async {
            withAnimation {
                self.completed=true
            }
        }
    }
    
    func getCompletedStatus() -> Bool {
        return completed
    }
}

/*class DownloadModel: ObservableObject {
    let item: MediaItem
    let time: Date
    var cache_row: PreviewCache? = nil
    
    @Published var progress: Double = 0.0
    @Published var completed: Bool = false
    var disk_location: URL? = nil
    
    var bytesWritten: Int64 = 0
    var totalBytes: Int64 = 0
    
    var name: String = ""
    
    init(_ item: MediaItem, name: String, time: Date, /*task: URLSessionDownloadTask, */sizeEstimate: Int64 = 0) {
        self.item=item
        self.name=name
        self.time=time
        self.totalBytes=sizeEstimate
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PreviewCache")
        fetchRequest.fetchLimit=1
        fetchRequest.predicate = NSPredicate(format: "oid_hex == %@", item._id.hex)
        do {
            let cache_rows = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            self.cache_row = cache_rows.count>0 ? (cache_rows[0] as? PreviewCache) : nil
        } catch {
            //err handling
        }
    }
    
    func setProgress(_ progress: Double, bytesWritten: Int64, totalBytes: Int64) async {
        self.totalBytes=totalBytes
        self.bytesWritten=bytesWritten
        DispatchQueue.main.async {
            withAnimation {
                self.progress=progress
            }
            self.objectWillChange.send()
        }
    }
    
    func setCompleted() {
        DispatchQueue.main.async {
            withAnimation {
                self.completed=true
            }
        }
    }
    
    func getCompletedStatus() -> Bool {
        return completed
    }
}
*/
