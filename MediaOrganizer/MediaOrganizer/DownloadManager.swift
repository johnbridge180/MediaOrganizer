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
    
    var downloadsDictionary: [String:DownloadModel] = [:]
    
    private var operationQueue: OperationQueue = OperationQueue()
    private var delegateQueue: OperationQueue = OperationQueue()
    private var updateProgressQueue: OperationQueue = OperationQueue()
    private var urlSession: URLSession!
    
    override private init() {
        super.init()
        
        let config = URLSessionConfiguration.background(withIdentifier: "com.jbridge.MediaOrganizer.backgroundDownloadSession")
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
        operationQueue.maxConcurrentOperationCount = 5
        updateProgressQueue.maxConcurrentOperationCount = 1
        //delegateQueue.maxConcurrentOperationCount = 1
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
            let time = Date()
            if let url = URL(string: api_endpoint_url+"?request=\(request)&oid="+item._id.hex+"&time=\(time.timeIntervalSince1970)") {
                let operation = DownloadOperation(url, urlSession: urlSession)
                let download = DownloadModel(item, name: fileName, time: time, source: url, destination: savedURL, operation: operation)
                downloadsDictionary[url.absoluteString] = download
                downloads.append(download)
                operationQueue.addOperation(download.operation)
                return download
            }
        } catch {
            print("download err")
        }
        return nil
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print(location)
        do {
            if(FileManager.default.fileExists(atPath: location.path)) {
                if let response = downloadTask.response, let responseURL = response.url, let model = self.downloadsDictionary[responseURL.absoluteString] {
                    print("\(model.destination.path)")
                    try FileManager.default.moveItem(at: location, to: model.destination)
                    model.setCompleted()
                }
            } else {
                //File already exists in downloads... what to do?
            }
        } catch {
            //err handling
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let currentRequest = downloadTask.currentRequest, let requestURL = currentRequest.url, let model = downloadsDictionary[requestURL.absoluteString] {
            Task {
                await model.setProgress(downloadTask.progress.fractionCompleted, bytesWritten: totalBytesWritten, totalBytes: totalBytesExpectedToWrite)
            }
        } else {
            print("boo on \(downloadTask.currentRequest)")
        }
    }
    
    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        //err handling
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        if let currentRequest = downloadTask.currentRequest, let requestURL = currentRequest.url {
            if downloadsDictionary[requestURL.absoluteString] == nil {
                downloadTask.cancel()
            }
        }
    }
}

