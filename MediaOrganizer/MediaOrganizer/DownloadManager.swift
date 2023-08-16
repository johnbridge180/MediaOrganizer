//
//  DownloadManager.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/8/23.
//

import Foundation
import SwiftUI

class DownloadManager: NSObject, ObservableObject, URLSessionDelegate, URLSessionDownloadDelegate {
    @AppStorage("api_endpoint_url") private var api_endpoint_url: String = ""
    
    static var shared = DownloadManager()
    
    @Published var downloads: [DownloadModel] = []
    
    var downloadsDictionary: [Int:DownloadModel] = [:]
    
    @Published var active_downloads: Int = 0
    
    @Published var totalBytesExpected: Int64 = 0
    @Published var totalBytesWritten: Int64 = 0
    
    private var operationQueue: OperationQueue = OperationQueue()
    private var urlSession: URLSession!
    
    override private init() {
        super.init()
        
        let config = URLSessionConfiguration.background(withIdentifier: "com.jbridge.MediaOrganizer.backgroundDownloadSession")
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: operationQueue)
    }
    
    func download(_ item: MediaItem, preview: Bool = false) -> DownloadModel? {
        if self.active_downloads == 0, let last = downloads.last, last.completed, last.time.timeIntervalSince1970+5.0 < Date().timeIntervalSince1970 {
            self.totalBytesWritten=0
            self.totalBytesExpected=0
        }
        do {
            let downloadsURL = try
            FileManager.default.url(for: .downloadsDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false)
            let fileName = preview ? (item.name as NSString).deletingPathExtension+".jpg" : item.name
            let savedURL = downloadsURL.appendingPathComponent(fileName)
            let request = preview ? "preview" : "download"
            if let url = URL(string: api_endpoint_url+"?request=\(request)&oid="+item._id.hex) {
                DispatchQueue.main.async {
                    self.active_downloads += 1
                }
                let task = urlSession.downloadTask(with: url)
                let download = DownloadModel(item, name: fileName, time: Date(), task: task)
                download.disk_location=savedURL
                downloadsDictionary[task.taskIdentifier] = download
                downloads.append(download)
                task.resume()
                return download
            }
        } catch {
            print("download err")
        }
        return nil
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            if(FileManager.default.fileExists(atPath: location.path)) {
                if let disk_location = downloadsDictionary[downloadTask.taskIdentifier]?.disk_location {
                    print("\(disk_location.path)")
                    try FileManager.default.moveItem(at: location, to: disk_location)
                }
            } else {
                //File already exists in downloads... what to do?
            }
        } catch {
            
        }
        if let model = downloadsDictionary[downloadTask.taskIdentifier] {
            DispatchQueue.main.async {
                self.totalBytesWritten += downloadTask.countOfBytesReceived - model.bytesWritten
                print("self.totalBytesWritten: \(self.totalBytesWritten); self.totalBytesExpected: \(self.totalBytesExpected)")
            }
        }
        downloadsDictionary[downloadTask.taskIdentifier]?.setCompleted()
        DispatchQueue.main.async {
            self.active_downloads -= 1
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        //CRASHING ON MANY ITEM DOWNLOADS???
        if let model = downloadsDictionary[downloadTask.taskIdentifier] {
            //appears to not be thread-safe? self.totalBytesExpected often larger than expected to be
            if model.totalBytes == 0 {
                DispatchQueue.main.async {
                    self.totalBytesExpected += totalBytesExpectedToWrite
                }
            }
            let bytesNewlyWritten = totalBytesWritten - model.bytesWritten
            DispatchQueue.main.async {
                self.totalBytesWritten += bytesNewlyWritten
                self.objectWillChange.send()
            }
            model.setProgress(downloadTask.progress.fractionCompleted, bytesWritten: totalBytesWritten, totalBytes: totalBytesExpectedToWrite)
        }
    }
    
    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        //err handling
    }
}
