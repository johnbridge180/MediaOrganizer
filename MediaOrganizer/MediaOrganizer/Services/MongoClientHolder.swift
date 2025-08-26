//
//  MongoClientHolder.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/26/22.
//

import SwiftUI
import MongoSwift
import NIOPosix

class MongoClientHolder: ObservableObject {
    let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
    @AppStorage("mongodb_url") private var mongodbUrl: String = ""
    @Published var client: MongoClient?
    @Published var db: MongoDatabase?

    @MainActor
    func connect() async {
        do {
            print(mongodbUrl)
            client = try MongoClient(mongodbUrl, using: elg)
            db = client!.db("media_organizer")
        } catch {
            print("Error connecting to MongoDB")
        }
    }

    func close() {
        try? client?.syncClose()
        cleanupMongoSwift()
        try? elg.syncShutdownGracefully()
    }
}
