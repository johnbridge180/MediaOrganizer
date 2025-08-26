//
//  MediaItemDetailWindow.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/27/22.
//

import Foundation
import AppKit
import SwiftUI

class MediaItemDetailWindow: NSWindow {
    init(contentRect: CGRect) {
        super.init(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)

        makeKeyAndOrderFront(nil)
        self.center()
        isReleasedWhenClosed=true
        styleMask.insert(NSWindow.StyleMask.fullSizeContentView)
    }

    override func close() {
        self.orderOut(NSApp)
        super.close()
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}
