//
//  PhotoGridView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/30/22.
//

import SwiftUI
import SwiftBSON

struct PhotoGridView: View {
    @Environment(\.managedObjectContext) private var moc

    @Binding var idealGridItemSize: Double
    @Binding var multiSelect: Bool
    let minGridItemSize: Double
    let scrollable: Bool
    let horizontalScroll: Bool
    let limit: Int
    let filter: BSONDocument

    @StateObject var mediaVModel: MediaItemsViewModel
    @StateObject private var viewportTracker = ViewportTracker()
    @StateObject private var layoutManager = PhotoGridLayoutManager()
    @StateObject private var qualityManager: ThumbnailQualityManager

    @State var selected: Set<BSONObjectID> = []

    init(idealGridItemSize: Binding<Double>, multiSelect: Binding<Bool>, minGridItemSize: Double, mongoHolder: MongoClientHolder, appDelegate: AppDelegate, filter: BSONDocument, limit: Int=0, scrollable: Bool = true, horizontalScroll: Bool = false) {
        self._idealGridItemSize = idealGridItemSize
        self._multiSelect = multiSelect
        self.minGridItemSize = minGridItemSize
        self.limit = limit
        self.filter = filter
        let mVmodel = MediaItemsViewModel(mongoHolder: mongoHolder, moc: PersistenceController.shared.container.viewContext, appDelegate: appDelegate)
        self._mediaVModel = StateObject(wrappedValue: mVmodel)
        self.scrollable = scrollable
        self.horizontalScroll = horizontalScroll
        
        let vTracker = ViewportTracker()
        self._viewportTracker = StateObject(wrappedValue: vTracker)
        self._qualityManager = StateObject(wrappedValue: ThumbnailQualityManager(viewportTracker: vTracker))
    }

    init(idealGridItemSize: Binding<Double>, minGridItemSize: Double, mongoHolder: MongoClientHolder, appDelegate: AppDelegate, filter: BSONDocument, limit: Int=0, scrollable: Bool = true, horizontalScroll: Bool = false) {
        let multiSelect: Binding<Bool> = Binding {
            false
        } set: { _ in

        }
        self._idealGridItemSize = idealGridItemSize
        self._multiSelect = multiSelect
        self.minGridItemSize = minGridItemSize
        self.limit = limit
        self.filter = filter
        let mVmodel = MediaItemsViewModel(mongoHolder: mongoHolder, moc: PersistenceController.shared.container.viewContext, appDelegate: appDelegate)
        self._mediaVModel = StateObject(wrappedValue: mVmodel)
        self.scrollable = scrollable
        self.horizontalScroll = horizontalScroll
        
        let vTracker = ViewportTracker()
        self._viewportTracker = StateObject(wrappedValue: vTracker)
        self._qualityManager = StateObject(wrappedValue: ThumbnailQualityManager(viewportTracker: vTracker))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let columnCount = max(1, Int(geometry.size.width / idealGridItemSize))
            let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: columnCount)
            
            _ = updateLayout(geometry: geometry)
            
            if scrollable {
                ScrollView(horizontalScroll ? .horizontal : .vertical, showsIndicators: true) {
                    LazyVGrid(columns: columns, spacing: 1) {
                        ForEach(mediaVModel.itemOrder, id: \.hex) { objectID in
                            if let item = mediaVModel.items[objectID] {
                                PhotoGridItemView(
                                    mediaItem: item.item,
                                    cacheRow: item.cacheRow,
                                    appDelegate: mediaVModel.appDelegate ?? AppDelegate(),
                                    isSelected: selected.contains(objectID),
                                    multiSelectMode: multiSelect,
                                    viewportTracker: viewportTracker,
                                    qualityManager: qualityManager
                                ) {
                                    handleItemSelection(objectID)
                                }
                                .frame(
                                    width: layoutManager.getItemWidth(itemId: objectID),
                                    height: layoutManager.getRowHeight(for: objectID)
                                )
                                .background(
                                    GeometryReader { itemGeometry in
                                        Color.clear.preference(
                                            key: VisibleItemsPreference.self,
                                            value: [VisibleItem(
                                                id: objectID,
                                                frame: itemGeometry.frame(in: .named("scrollView"))
                                            )]
                                        )
                                    }
                                )
                                .contextMenu {
                                    if selected.contains(objectID) && selected.count > 1 {
                                        Button("Download \(selected.count) items") {
                                            for selectedID in selected {
                                                if let mediaItem = mediaVModel.items[selectedID] {
                                                    DownloadManager.shared.download(mediaItem.item)
                                                }
                                            }
                                        }
                                    } else {
                                        Button("Download \(item.item.name)") {
                                            DownloadManager.shared.download(item.item)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(VisibleItemsPreference.self) { visibleItems in
                    handleVisibleItemsChange(visibleItems, scrollViewFrame: geometry.frame(in: .global))
                }
            } else {
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(mediaVModel.itemOrder, id: \.hex) { objectID in
                        if let item = mediaVModel.items[objectID] {
                            PhotoGridItemView(
                                mediaItem: item.item,
                                cacheRow: item.cacheRow,
                                appDelegate: mediaVModel.appDelegate ?? AppDelegate(),
                                isSelected: selected.contains(objectID),
                                multiSelectMode: multiSelect,
                                viewportTracker: viewportTracker,
                                qualityManager: qualityManager
                            ) {
                                handleItemSelection(objectID)
                            }
                            .frame(
                                width: layoutManager.getItemWidth(itemId: objectID),
                                height: layoutManager.getRowHeight(for: objectID)
                            )
                            .background(
                                GeometryReader { itemGeometry in
                                    Color.clear.preference(
                                        key: VisibleItemsPreference.self,
                                        value: [VisibleItem(
                                            id: objectID,
                                            frame: itemGeometry.frame(in: .named("scrollView"))
                                        )]
                                    )
                                }
                            )
                            .contextMenu {
                                if selected.contains(objectID) && selected.count > 1 {
                                    Button("Download \(selected.count) items") {
                                        for selectedID in selected {
                                            if let mediaItem = mediaVModel.items[selectedID] {
                                                DownloadManager.shared.download(mediaItem.item)
                                            }
                                        }
                                    }
                                } else {
                                    Button("Download \(item.item.name)") {
                                        DownloadManager.shared.download(item.item)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 1)
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(VisibleItemsPreference.self) { visibleItems in
                    handleVisibleItemsChange(visibleItems, scrollViewFrame: geometry.frame(in: .global))
                }
            }
        }
        .onChange(of: multiSelect) { newValue in
            if !newValue {
                selected = []
            }
        }
        .onChange(of: mediaVModel.itemOrder) { _ in
            updateLayout(geometry: nil)
        }
        .onChange(of: idealGridItemSize) { _ in
            updateLayout(geometry: nil)
        }
        .onAppear {
            Task {
                do {
                    try await mediaVModel.fetchRows(limit: self.limit, filter: self.filter)
                } catch {}
            }
        }
        .onDisappear {
            do {
                try moc.save()
            } catch {}
        }
        .frame(minWidth: 300)
    }
    
    private func handleItemSelection(_ objectID: BSONObjectID) {
        if NSEvent.modifierFlags.contains(.shift) && !selected.isEmpty {
            handleShiftSelection(objectID)
        } else if NSEvent.modifierFlags.contains(.command) {
            toggleSelection(objectID)
        } else {
            if multiSelect {
                toggleSelection(objectID)
            } else {
                selected = [objectID]
                multiSelect = true
            }
        }
    }
    
    private func toggleSelection(_ objectID: BSONObjectID) {
        if selected.contains(objectID) {
            selected.remove(objectID)
        } else {
            selected.insert(objectID)
        }
    }
    
    private func handleShiftSelection(_ objectID: BSONObjectID) {
        guard let targetIndex = mediaVModel.itemOrder.firstIndex(of: objectID) else { return }
        
        let selectedIndices = selected.compactMap { mediaVModel.itemOrder.firstIndex(of: $0) }
        guard let closestIndex = selectedIndices.min(by: { abs($0 - targetIndex) < abs($1 - targetIndex) }) else {
            selected.insert(objectID)
            return
        }
        
        let range = min(closestIndex, targetIndex)...max(closestIndex, targetIndex)
        for index in range {
            selected.insert(mediaVModel.itemOrder[index])
        }
    }
    
    private func calculateAspectRatio(for mediaItem: MediaItem) -> Double {
        let dimensions = mediaItem.getDisplayDimensions()
        let aspectRatio = Double(dimensions.width) / Double(dimensions.height)
        
        return max(0.5, min(2.0, aspectRatio))
    }
    
    private func updateLayout(geometry: GeometryProxy?) {
        let containerWidth = geometry?.size.width ?? 800
        
        DispatchQueue.main.async {
            self.layoutManager.calculateLayout(
                items: self.mediaVModel.items,
                itemOrder: self.mediaVModel.itemOrder,
                containerWidth: containerWidth
            )
        }
    }
    
    private func handleVisibleItemsChange(_ visibleItems: [VisibleItem], scrollViewFrame: CGRect) {
        let scrollOffset = scrollViewFrame.minY
        viewportTracker.updateScrollVelocity(scrollOffset: scrollOffset)
        viewportTracker.updateVisibleItems(visibleItems, scrollViewFrame: scrollViewFrame)
    }
}

struct PhotoGridView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoGridView(idealGridItemSize: Binding(get: { return 100.0}, set: {_ in }), minGridItemSize: 50.0, mongoHolder: MongoClientHolder(), appDelegate: AppDelegate(), filter: [:], limit: 10, scrollable: true)
    }
}
