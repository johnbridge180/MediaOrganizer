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
    
    private var downloadsDictionary: [URLSessionTask:DownloadModel] = [:]
    
    private var operationQueue: OperationQueue = OperationQueue()
    private var urlSession: URLSession!
    
    override private init() {
        super.init()
        
        let config = URLSessionConfiguration.background(withIdentifier: "com.jbridge.MediaOrganizer.backgroundDownloadSession")
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: operationQueue)
    }
    
    func download(_ item: MediaItem, preview: Bool = false) -> DownloadModel? {
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
                let task = urlSession.downloadTask(with: url)
                let download = DownloadModel(item, name: fileName, task: task)
                download.disk_location=savedURL
                downloadsDictionary[task] = download
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
                if let disk_location = downloadsDictionary[downloadTask]?.disk_location {
                    print("\(disk_location.path)")
                    try FileManager.default.moveItem(at: location, to: disk_location)
                }
            } else {
                //File already exists in downloads... what to do?
            }
        } catch {
            
        }
        downloadsDictionary[downloadTask]?.setCompleted()
    }
    
    func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        downloadsDictionary[downloadTask]?.setProgress(downloadTask.progress.fractionCompleted, bytesWritten: totalBytesWritten, totalBytes: totalBytesExpectedToWrite)
    }
    
    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        //err handling
    }
}
