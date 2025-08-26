//
//  PhotoGridItemView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/26/25.
//

import SwiftUI
import SwiftBSON

struct PhotoGridItemView: View {
    let mediaItem: MediaItem
    let cacheRow: PreviewCache?
    let appDelegate: AppDelegate
    let isSelected: Bool
    let multiSelectMode: Bool
    let onSelectionToggle: () -> Void
    let viewportTracker: ViewportTracker
    
    @StateObject private var thumbnailViewModel: ThumbnailViewModel
    @State private var currentQuality: Int = 0
    
    init(mediaItem: MediaItem, cacheRow: PreviewCache?, appDelegate: AppDelegate, isSelected: Bool, multiSelectMode: Bool, viewportTracker: ViewportTracker, onSelectionToggle: @escaping () -> Void) {
        self.mediaItem = mediaItem
        self.cacheRow = cacheRow
        self.appDelegate = appDelegate
        self.isSelected = isSelected
        self.multiSelectMode = multiSelectMode
        self.viewportTracker = viewportTracker
        self.onSelectionToggle = onSelectionToggle
        
        let makeCGImageQueue = DispatchQueue(label: "com.jbridge.makeCGImageQueue", qos: .background)
        self._thumbnailViewModel = StateObject(wrappedValue: ThumbnailViewModel(mediaItem, cacheRow: cacheRow, makeCGImageQueue: makeCGImageQueue))
    }
    
    var body: some View {
        ZStack {
            ThumbnailView(appDelegate: appDelegate, thumbVModel: thumbnailViewModel)
            
            if multiSelectMode {
                Button {
                    onSelectionToggle()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 30))
                        .padding(8)
                }
                .buttonStyle(ImageSelectButton(selected: isSelected))
                .foregroundColor(Color.white)
            }
        }
        .contextMenu {
            Button("Download \(mediaItem.name)") {
                DownloadManager.shared.download(mediaItem)
            }
        }
        .onReceive(viewportTracker.$visibleItems) { _ in
            updateThumbnailQuality()
        }
        .onReceive(viewportTracker.$nearVisibleItems) { _ in
            updateThumbnailQuality()
        }
        .onReceive(viewportTracker.$scrollVelocity) { _ in
            updateThumbnailQuality()
        }
    }
    
    private func updateThumbnailQuality() {
        let position = viewportTracker.getPositionFor(itemId: mediaItem._id)
        let scrollVelocity = viewportTracker.scrollVelocity
        
        let targetQuality = calculateTargetQuality(position: position, scrollVelocity: scrollVelocity)
        
        if targetQuality != currentQuality {
            currentQuality = targetQuality
            thumbnailViewModel.setDisplayType(targetQuality)
        }
    }
    
    private func calculateTargetQuality(position: ViewportPosition, scrollVelocity: CGFloat) -> Int {
        switch position {
        case .visible:
            return scrollVelocity > 500 ? 1 : 2
        case .nearVisible:
            return 1
        case .farOffscreen:
            return 0
        }
    }
}

struct ImageSelectButton: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.black.opacity(selected ? 0.5 : 0.25))
            .foregroundColor(Color.white)
            .animation(.easeOut(duration: 0.1), value: selected)
    }
}
