//
//  DownloadOperation.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/23/25.
//

import Foundation

//credit: https://fluffy.es/download-files-sequentially/
class DownloadOperation: Operation {
    private var url: URL
    private var urlSession: URLSession
    private var task: URLSessionDownloadTask!
    
    enum OperationState : Int {
        case ready
        case executing
        case finished
    }
    
    // default state is ready (when the operation is created)
    private var state : OperationState = .ready {
        willSet {
            self.willChangeValue(forKey: "isExecuting")
            self.willChangeValue(forKey: "isFinished")
        }
        
        didSet {
            self.didChangeValue(forKey: "isExecuting")
            self.didChangeValue(forKey: "isFinished")
        }
    }
    
    override var isReady: Bool { return state == .ready }
    override var isExecuting: Bool { return state == .executing }
    override var isFinished: Bool { return state == .finished }
    
    init(_ url: URL, urlSession: URLSession) {
        self.url = url
        self.urlSession = urlSession
        super.init()
    }
    
    func setFinished() {
        self.state = .finished
    }
    
    override func start() {
        if self.isCancelled {
            state = .finished
            return
        }
        state = .executing
        
        // Create task - delegate will handle progress
        task = urlSession.downloadTask(with: url)
        
        task.resume()
    }
    
    override func cancel() {
        super.cancel()
        
        self.task.cancel()
    }
}
