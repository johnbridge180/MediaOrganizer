//
//  MediaOrganizerApp.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/17/22.
//

import SwiftUI

@main
struct MediaOrganizerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
