//
//  MediaOrganizerApp.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/17/22.
//

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    var mediaItemDetailWindows: [MediaItemDetailWindow] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func openMediaItemDetailWindow(rect: CGRect, thumb: NSImage, item: MediaItem) {
        let mediaItemDetailWindow = MediaItemDetailWindow(contentRect: rect)
        mediaItemDetailWindow.delegate=self
        mediaItemDetailWindow.title=item.name
        mediaItemDetailWindow.contentView = NSHostingView(rootView: MediaItemDetailView(thumb:thumb, item: item))
        mediaItemDetailWindows.append(mediaItemDetailWindow)
    }
}

@main
struct MediaOrganizerApp: App {
    
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem, addition: { })
            SidebarCommands()
        }
        .windowToolbarStyle(.unified)
        
        Settings {
            SettingsView()
        }
        .windowToolbarStyle(.unified)
    }
    
}
