//
//  SearchOverlayPanel.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/12/23.
//

import Foundation

import Foundation
import AppKit
import SwiftUI

class SearchOverlayPanel: NSPanel {
    let searchParser: SearchParser
    
    init(_ searchParser: SearchParser, contentRect: NSRect, backing: NSWindow.BackingStoreType = .buffered, defer flag: Bool = false) {
        self.searchParser=searchParser
        super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .titled, .closable, .borderless, .fullSizeContentView], backing: backing, defer: flag)
        isFloatingPanel = true
        level = .floating
        collectionBehavior.insert(.fullScreenAuxiliary)
        animationBehavior = .utilityWindow
        hidesOnDeactivate = true
 
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        let view = SearchOverlayView(searchParser: searchParser)
        let hostingView = NSHostingView(rootView: view.ignoresSafeArea())
        contentView = hostingView
    }
    
    override func resignMain() {
        super.resignMain()
    }
    
    override var canBecomeKey: Bool {
        return false
    }
     
    override var canBecomeMain: Bool {
        return true
    }
    
    func present() {
        orderFront(nil)
        makeKey()
    }
}
