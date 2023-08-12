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
    
    var downloadsPanel: DownloadOverlayPanel? = nil
    var searchPanel: SearchOverlayPanel? = nil
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func openMediaItemDetailWindow(rect: CGRect, item: MediaItem, initialThumb: CGImage? = nil, orientation: Image.Orientation) {
        let mediaItemDetailWindow = MediaItemDetailWindow(contentRect: rect)
        mediaItemDetailWindow.delegate=self
        mediaItemDetailWindow.title=item.name
        mediaItemDetailWindow.contentView = NSHostingView(rootView: MediaItemDetailView(item, initialThumb: initialThumb, initialThumbOrientation: orientation))
        mediaItemDetailWindows.append(mediaItemDetailWindow)
        //do sum w this? mediaItemDetailWindows[0].addTabbedWindow(<#T##window: NSWindow##NSWindow#>, ordered: <#T##NSWindow.OrderingMode#>)
    }
    
    func openDownloadsPanel() {
        if NSApp.windows.count>0 {
            let window = NSApp.windows[0]
            let height: CGFloat = DownloadManager.shared.downloads.count==0 ? 100.0 : (DownloadManager.shared.downloads.count > 5 ? 385 : CGFloat(DownloadManager.shared.downloads.count)*75.0 + 10)
            self.downloadsPanel = DownloadOverlayPanel(contentRect: CGRect(x: window.frame.maxX-325, y: window.frame.maxY-(height+45), width: 300, height: height))
        }
        self.downloadsPanel?.present()
    }
    
    func openSearchPanel(_ searchParser: SearchParser) {
        if NSApp.windows.count>0 {
            let window = NSApp.windows[0]
            let height: CGFloat = 500
            self.searchPanel = SearchOverlayPanel(searchParser, contentRect: CGRect(x: window.frame.maxX-375, y: window.frame.maxY-(height+45), width: 300, height: height))
        }
        self.searchPanel?.present()
    }
    func closeSearchPanel() {
        self.searchPanel?.close()
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
