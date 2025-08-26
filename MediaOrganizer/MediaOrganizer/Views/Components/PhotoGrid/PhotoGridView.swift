//
//  PhotoGridView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/30/22.
//

import SwiftUI
import SwiftBSON

struct PhotoGridRow: Identifiable {
    var id: Int
    var items: [MediaItemHolder]
}

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
    @StateObject var gridViewModel: PhotoGridViewModel

    @State var selected: [BSONObjectID: Bool] = [:]

    @State var dragging: Bool = false
    @State var dragStart: CGPoint = CGPoint()
    @State var dragEnd: CGPoint = CGPoint()

    init(idealGridItemSize: Binding<Double>, multiSelect: Binding<Bool>? = nil, minGridItemSize: Double, mongoHolder: MongoClientHolder, appDelegate: AppDelegate, filter: BSONDocument, limit: Int=0, scrollable: Bool = true, horizontalScroll: Bool = false) {
        self._idealGridItemSize = idealGridItemSize
        self._multiSelect = multiSelect ?? Binding(get: { false }, set: { _ in })
        self.minGridItemSize = minGridItemSize
        self.limit = limit
        self.filter = filter
        let mVmodel = MediaItemsViewModel(mongoHolder: mongoHolder, moc: PersistenceController.shared.container.viewContext, appDelegate: appDelegate)
        self._mediaVModel = StateObject(wrappedValue: mVmodel)
        self.scrollable = scrollable
        self.horizontalScroll = horizontalScroll
        self._gridViewModel = StateObject(wrappedValue: PhotoGridViewModel(minGridItemSize: minGridItemSize, mediaViewModel: mVmodel))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if scrollable {
                    ScrollView(horizontalScroll ? .horizontal : .vertical, showsIndicators: true) {
                        photoGrid(geometry: geometry)
                            .onFrameChange { frame in
                                if !horizontalScroll {
                                    mediaVModel.onScrollFrameUpdate(frame, width: geometry.size.width, height: geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photoWidth)
                                }
                            }
                    }
                } else {
                    photoGrid(geometry: geometry)
                }
            }
            .onChange(of: multiSelect, perform: { newValue in
                if !newValue {
                    selected = [:]
                }
            })
            .onChange(of: geometry.size) { newValue in
                if !mediaVModel.isFetching && !mediaVModel.items.isEmpty && !horizontalScroll {
                    DispatchQueue.main.async {
                        gridViewModel.setOffsets(width: newValue.width, idealGridItemSize: idealGridItemSize)
                    }
                    mediaVModel.updateRangeValuesForResize(width: newValue.width, height: newValue.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photoWidth)
                }
            }
            .onChange(of: idealGridItemSize, perform: { newValue in
                if !mediaVModel.isFetching && !mediaVModel.items.isEmpty {
                    DispatchQueue.main.async {
                        withAnimation {
                            gridViewModel.setOffsets(width: horizontalScroll ? CGFloat(mediaVModel.itemOrder.count)*idealGridItemSize : geometry.size.width, idealGridItemSize: newValue)
                        }
                        mediaVModel.updateRangeValuesForResize(width: horizontalScroll ? CGFloat(mediaVModel.itemOrder.count)*idealGridItemSize : geometry.size.width, height: horizontalScroll ? idealGridItemSize : geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photoWidth)
                    }
                }
            })
            .onAppear {
                Task {
                    do {
                        try await mediaVModel.fetchRows(limit: self.limit, filter: self.filter)
                        gridViewModel.setOffsets(width: horizontalScroll ? CGFloat(mediaVModel.itemOrder.count)*idealGridItemSize : geometry.size.width, idealGridItemSize: idealGridItemSize)

                        mediaVModel.setRangeValues(zstackOriginY: 0, width: horizontalScroll ? CGFloat(mediaVModel.itemOrder.count)*idealGridItemSize : geometry.size.width, height: horizontalScroll ? idealGridItemSize : geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photoWidth)
                    } catch {
                        print("Error fetching media items: \(error)")
                    }
                }
            }
            .onDisappear {
                do {
                    try moc.save()
                } catch {
                    print("Error saving managed object context: \(error)")
                }
            }
        }
        .frame(minWidth: 300, minHeight: scrollable ? 0 : gridViewModel.zstackHeight)
    }
    
    private func photoGrid(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            backgroundRectangle(geometry: geometry)
            photoGridItems
            if dragging && !horizontalScroll {
                dragSelectionOverlay
            }
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }
    
    private func backgroundRectangle(geometry: GeometryProxy) -> some View {
        Rectangle()
            .frame(
                width: horizontalScroll ? CGFloat(mediaVModel.itemOrder.count) * idealGridItemSize : geometry.size.width,
                height: horizontalScroll ? idealGridItemSize : gridViewModel.zstackHeight
            )
            .opacity(0)
    }
    
    private var photoGridItems: some View {
        ForEach(mediaVModel.itemOrder, id: \.hex) { object in
            if let item = mediaVModel.items[object] {
                photoGridItem(for: item, object: object)
            }
        }
    }
    
    private func photoGridItem(for item: MediaItemHolder, object: BSONObjectID) -> some View {
        let dimensions = item.item.getDisplayDimensions()
        return ZStack {
            item.view
            if multiSelect {
                selectionButton(for: item, dimensions: dimensions)
            }
        }
        .frame(width: gridViewModel.photoWidth, height: gridViewModel.photoWidth)
        .offset(gridViewModel.offsets[object] ?? CGSize())
        .contextMenu {
            contextMenuContent(for: item)
        }
    }
    
    private func selectionButton(for item: MediaItemHolder, dimensions: (width: Int32, height: Int32)) -> some View {
        Button {
            handleItemSelection(for: item.item._id)
        } label: {
            Image(systemName: selected[item.item._id] ?? false ? "checkmark.circle.fill" : "circle")
                .font(.system(size: ThumbnailViewModel.Constants.largeIconThreshold < gridViewModel.photoWidth ? ThumbnailViewModel.Constants.largeIconSize : gridViewModel.photoWidth/ThumbnailViewModel.Constants.iconSizeDivider))
                .padding()
                .frame(
                    width: dimensions.width >= dimensions.height ?
                    gridViewModel.photoWidth : gridViewModel.photoWidth * Double(dimensions.width)/Double(dimensions.height),
                    height: dimensions.width >= dimensions.height ?
                    gridViewModel.photoWidth * Double(dimensions.height)/Double(dimensions.width) : gridViewModel.photoWidth
                )
        }
        .buttonStyle(ImageSelectButton(selected: selected[item.item._id] ?? false))
        .foregroundColor(Color.white)
    }
    
    @ViewBuilder
    private func contextMenuContent(for item: MediaItemHolder) -> some View {
        if selected[item.item._id] == true {
            Button("Download \(selected.count) items") {
                for (key, value) in selected where value {
                    if let mediaItem = mediaVModel.items[key] {
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
    
    private var dragSelectionOverlay: some View {
        Rectangle()
            .fill(Color.blue.opacity(0.25))
            .border(.blue)
            .frame(width: abs(dragEnd.x - dragStart.x), height: abs(dragEnd.y - dragStart.y))
            .offset(
                x: dragEnd.x > dragStart.x ? dragStart.x : dragEnd.x,
                y: dragEnd.y > dragStart.y ? dragStart.y : dragEnd.y
            )
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragging = true
                dragStart = value.startLocation
                dragEnd = value.location
            }
            .onEnded { _ in
                handleDragEnd()
            }
    }
    
    private func handleDragEnd() {
        let rectangle = (
            x1: dragEnd.x > dragStart.x ? dragStart.x : dragEnd.x,
            y1: dragEnd.y > dragStart.y ? dragStart.y : dragEnd.y,
            x2: dragEnd.x > dragStart.x ? dragEnd.x : dragStart.x,
            y2: dragEnd.y > dragStart.y ? dragEnd.y : dragStart.y
        )
        
        guard !(rectangle.x1 == 0 && rectangle.y1 == 0 && rectangle.x2 == 0 && rectangle.y2 == 0) else {
            resetDragState()
            return
        }
        
        if !NSEvent.modifierFlags.contains(.command) {
            selected = [:]
        }
        multiSelect = true
        let photosInRectangle = gridViewModel.getPhotosInRectangle(rectangle)
        for selectedObjectID in photosInRectangle {
            selected[selectedObjectID] = true
        }
        
        resetDragState()
    }
    
    private func resetDragState() {
        dragging = false
        dragStart = CGPoint()
        dragEnd = CGPoint()
    }
    
    private func handleItemSelection(for itemId: BSONObjectID) {
        if NSEvent.modifierFlags.contains(.shift) && !selected.isEmpty {
            handleShiftSelection(for: itemId)
        } else {
            toggleItemSelection(for: itemId)
        }
    }
    
    private func handleShiftSelection(for itemId: BSONObjectID) {
        guard let index = mediaVModel.itemOrder.firstIndex(of: itemId) else { return }
        
        let closestLeftIndex = findClosestSelectedIndex(from: index, direction: -1)
        let closestRightIndex = findClosestSelectedIndex(from: index, direction: 1)
        
        if closestLeftIndex == -1 || (closestRightIndex != -1 && closestRightIndex - index < index - closestLeftIndex) {
            selectRange(from: index + 1, to: closestRightIndex)
        } else {
            selectRange(from: closestLeftIndex, to: index - 1)
        }
        selected[itemId] = true
    }
    
    private func findClosestSelectedIndex(from startIndex: Int, direction: Int) -> Int {
        var i = startIndex + direction
        while i >= 0 && i < mediaVModel.itemOrder.count {
            if selected[mediaVModel.itemOrder[i]] != nil {
                return i
            }
            i += direction
        }
        return -1
    }
    
    private func selectRange(from start: Int, to end: Int) {
        guard start >= 0 && end < mediaVModel.itemOrder.count && start <= end else { return }
        for k in start...end {
            selected[mediaVModel.itemOrder[k]] = true
        }
    }
    
    private func toggleItemSelection(for itemId: BSONObjectID) {
        if selected[itemId] == nil {
            selected[itemId] = true
        } else {
            selected.removeValue(forKey: itemId)
        }
    }
}

struct PhotoGridView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoGridView(idealGridItemSize: Binding(get: { return 100.0}, set: {_ in }), minGridItemSize: 50.0, mongoHolder: MongoClientHolder(), appDelegate: AppDelegate(), filter: [:], limit: 10, scrollable: true)
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
