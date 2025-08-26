//
//  DownloadOverlayPanel.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/8/23.
//

import Foundation
import AppKit
import SwiftUI

class DownloadOverlayPanel: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType = .buffered, defer flag: Bool = false) {
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

        let view = DownloadOverlayView()
        let hostingView = NSHostingView(rootView: view.ignoresSafeArea())
        contentView = hostingView
    }

    override func resignMain() {
        super.resignMain()
        close()
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    func present() {
        orderFront(nil)
        makeKey()
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = NSVisualEffectView.State.active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
