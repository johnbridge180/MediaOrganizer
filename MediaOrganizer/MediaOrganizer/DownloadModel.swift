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
    
    let downloadTask: URLSessionDownloadTask
    
    let item: MediaItem
    var cache_row: PreviewCache? = nil
    
    var progress: Double = 0.0
    @Published var completed: Bool = false
    var disk_location: URL? = nil
    
    var bytesWritten: Int64 = 0
    var totalBytes: Int64 = 0
    
    var name: String = ""
    
    init(_ item: MediaItem, name: String, task: URLSessionDownloadTask, sizeEstimate: Int64 = 0) {
        self.item=item
        self.name=name
        self.downloadTask=task
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
    
    func setProgress(_ progress: Double, bytesWritten: Int64, totalBytes: Int64) {
        DispatchQueue.main.async {
            self.bytesWritten=bytesWritten
            self.totalBytes=totalBytes
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
