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
    let qualityManager: ThumbnailQualityManager
    
    @StateObject private var thumbnailViewModel: ThumbnailViewModel
    @State private var currentQuality: Int = 0
    
    init(mediaItem: MediaItem, cacheRow: PreviewCache?, appDelegate: AppDelegate, isSelected: Bool, multiSelectMode: Bool, viewportTracker: ViewportTracker, qualityManager: ThumbnailQualityManager, onSelectionToggle: @escaping () -> Void) {
        self.mediaItem = mediaItem
        self.cacheRow = cacheRow
        self.appDelegate = appDelegate
        self.isSelected = isSelected
        self.multiSelectMode = multiSelectMode
        self.viewportTracker = viewportTracker
        self.qualityManager = qualityManager
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
        .onAppear {
            qualityManager.registerItem(mediaItem._id, viewModel: thumbnailViewModel)
        }
        .onDisappear {
            qualityManager.unregisterItem(mediaItem._id)
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
