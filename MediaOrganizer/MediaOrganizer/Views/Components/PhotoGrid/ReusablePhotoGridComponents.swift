//
//  ReusablePhotoGridComponents.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/28/25.
//  Reorganized on 9/3/25 - This file now serves as a convenience import for all PhotoGrid components
//

// Import all necessary frameworks
import Foundation
import SwiftUI
import AppKit
import Combine


// MARK: - Models
struct PhotoGridItem: Identifiable, Hashable {
    let id: String
    let imageURL: URL
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PhotoGridItem, rhs: PhotoGridItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct PhotoGridAction {
    let title: String
    let handler: ([PhotoGridItem]) -> Void
    
    init(title: String, handler: @escaping ([PhotoGridItem]) -> Void) {
        self.title = title
        self.handler = handler
    }
}

enum PhotoGridScrollDirection {
    case vertical
    case horizontal
}

enum PhotoGridError: Error {
    case imageLoadFailed
    case cacheWriteFailed
    case invalidImageData
    case networkError(Error)
}

// MARK: - Data Source Protocol
protocol PhotoGridDataSource: ObservableObject {
    var items: [PhotoGridItem] { get }
    var isLoading: Bool { get }

    func loadItems(offset: Int, length: Int) async throws
    func getMediaItem(for id: String) -> MediaItem?
}


// MARK: - PhotoGridThumbnailCache
class PhotoGridThumbnailCache {
    static let shared = PhotoGridThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.mediaorganizer.thumbnailcache", qos: .userInitiated)
    private let cacheDirectory: URL

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024

        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("PhotoGridThumbnails")

        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    @MainActor
    func getThumbnail(for item: PhotoGridItem, thumbnailSize: CGFloat, isHighRes: Bool = true) async -> NSImage? {
        let thumbnailType = isHighRes ? "high" : "tiny"
        let cacheKey = "\(item.id)_\(thumbnailType)_\(Int(thumbnailSize))"

        if let cachedImage = cache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }

        if let diskImage = await loadFromDisk(cacheKey: cacheKey) {
            cache.setObject(diskImage, forKey: cacheKey as NSString)
            return diskImage
        }

        return await loadAndCacheImage(for: item, thumbnailSize: thumbnailSize, cacheKey: cacheKey)
    }
    
    private func loadAndCacheImage(for item: PhotoGridItem, thumbnailSize: CGFloat, cacheKey: String) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let data = try Data(contentsOf: item.imageURL)
                    
                    guard let originalImage = NSImage(data: data) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    Task {
                        let thumbnail = await self.createThumbnail(from: originalImage, thumbnailSize: thumbnailSize)
                        await MainActor.run {
                            self.cache.setObject(thumbnail, forKey: cacheKey as NSString)
                        }
                        await self.saveToDisk(image: thumbnail, cacheKey: cacheKey)
                        continuation.resume(returning: thumbnail)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func createThumbnail(from image: NSImage, thumbnailSize maxDimension: CGFloat) async -> NSImage {
        return await withCheckedContinuation { continuation in
            queue.async {
                let sourceSize = image.size

                let aspectRatio = sourceSize.width / sourceSize.height
                let thumbnailSize: CGSize

                if aspectRatio > 1 {
                    thumbnailSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
                } else {
                    thumbnailSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
                }

                let thumbnailImage = NSImage(size: thumbnailSize)

                thumbnailImage.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: thumbnailSize))
                thumbnailImage.unlockFocus()

                continuation.resume(returning: thumbnailImage)
            }
        }
    }

    private func loadFromDisk(cacheKey: String) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                let fileURL = self.cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
                guard FileManager.default.fileExists(atPath: fileURL.path),
                      let imageData = try? Data(contentsOf: fileURL),
                      let image = NSImage(data: imageData) else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func saveToDisk(image: NSImage, cacheKey: String) async {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: ())
                    return
                }

                let fileURL = self.cacheDirectory.appendingPathComponent("\(cacheKey).jpg")

                guard let tiffData = image.tiffRepresentation,
                      let bitmapImage = NSBitmapImageRep(data: tiffData),
                      let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                    continuation.resume(returning: ())
                    return
                }

                try? jpegData.write(to: fileURL)
                continuation.resume(returning: ())
            }
        }
    }

    func clearCache() {
        cache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func removeCachedImage(for itemId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let pattern = "\(itemId)_"
            let fileManager = FileManager.default

            if let enumerator = fileManager.enumerator(at: self.cacheDirectory, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    if fileURL.lastPathComponent.hasPrefix(pattern) {
                        try? fileManager.removeItem(at: fileURL)
                        let cacheKey = String(fileURL.lastPathComponent.dropLast(4))
                        DispatchQueue.main.async {
                            self.cache.removeObject(forKey: cacheKey as NSString)
                        }
                    }
                }
            }
        }
    }
}

struct ViewportItemInfo {
    let itemId: String
    let isVisible: Bool
    let rowsFromVisible: Int
}

// MARK: - ViewportTracker
class ViewportTracker: ObservableObject {
    @Published var itemInfo: [String: ViewportItemInfo] = [:]

    private let updateQueue: DispatchQueue
    private var lastScrollFrameUpdate: Date = Date()
    private var lastSeenZStackOrigin: CGFloat = 0.0
    private let scrollUpdateDelay: Double = 0.2
    
    init() {
        self.updateQueue = DispatchQueue(label: "com.jbridge.viewportUpdateQueue", qos: .background)
    }
    
    func onScrollFrameUpdate(_ frame: CGRect, gridItems: [PhotoGridItem], width: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat) {
        let currentUpdate = Date()
        self.lastScrollFrameUpdate = currentUpdate
        
        updateQueue.asyncAfter(deadline: .now() + scrollUpdateDelay) { [weak self] in
            guard let self = self else { return }
            if self.lastScrollFrameUpdate == currentUpdate {
                self.updateRangeValues(isScrollUpdate: true, zstackOriginY: frame.origin.y, gridItems: gridItems, width: width, height: height, numColumns: numColumns, colWidth: colWidth)
            }
        }
    }
    
    func updateRangeValuesForResize(gridItems: [PhotoGridItem], width: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            self.updateRangeValues(zstackOriginY: self.lastSeenZStackOrigin, gridItems: gridItems, width: width, height: height, numColumns: numColumns, colWidth: colWidth)
        }
    }
    
    private func updateRangeValues(isScrollUpdate: Bool = false, zstackOriginY: CGFloat, gridItems: [PhotoGridItem], width: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat) {
        let shouldUpdate = !isScrollUpdate || abs(self.lastSeenZStackOrigin - zstackOriginY) >= (colWidth * 0.5)

        if !shouldUpdate {
            return
        }

        self.lastSeenZStackOrigin = zstackOriginY

        guard !gridItems.isEmpty && numColumns > 0 else { return }

        let visibleIndexRange = getAssumedDisplayedIndexRange(zstackOriginY: zstackOriginY, height: height, numColumns: numColumns, colWidth: colWidth, itemCount: gridItems.count)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            var newItemInfo: [String: ViewportItemInfo] = [:]

            for (index, item) in gridItems.enumerated() {
                let isVisible = visibleIndexRange.contains(index)
                let rowsFromVisible: Int

                if isVisible {
                    rowsFromVisible = 0
                } else {
                    let itemRow = index / numColumns
                    let visibleStartRow = visibleIndexRange.lowerBound / numColumns
                    let visibleEndRow = visibleIndexRange.upperBound / numColumns

                    if itemRow < visibleStartRow {
                        rowsFromVisible = visibleStartRow - itemRow
                    } else {
                        rowsFromVisible = itemRow - visibleEndRow
                    }
                }

                newItemInfo[item.id] = ViewportItemInfo(
                    itemId: item.id,
                    isVisible: isVisible,
                    rowsFromVisible: rowsFromVisible
                )
            }

            self.itemInfo = newItemInfo
        }
    }
    
    private func getAssumedDisplayedIndexRange(zstackOriginY: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat, itemCount: Int) -> ClosedRange<Int> {
        let maxNumRows: Int = colWidth == 0 ? 0 : Int(ceil(height / colWidth))
        let assumedAmtDisplayed: Int = maxNumRows * numColumns
        let numRowsAboveVisibleArea: Int = Int(zstackOriginY > 0 || colWidth == 0 ? 0 : abs(zstackOriginY) / colWidth)
        let startIndex: Int = numRowsAboveVisibleArea * numColumns
        let endIndex = min(itemCount - 1, startIndex + assumedAmtDisplayed)
        return max(0, startIndex)...max(0, endIndex)
    }
}

// MARK: - ReusablePhotoGridViewModel
class ReusablePhotoGridViewModel: ObservableObject {
    let minGridItemSize: Double
    
    var offsets: [String: CGSize] = [:]
    var photoWidth: CGFloat = 0.0
    var zstackHeight: CGFloat = 0.0
    var numCols: Int = 0
    
    private var lastItemCount: Int = 0
    private var lastWidth: CGFloat = 0
    private var lastIdealSize: Double = 0
    
    init(minGridItemSize: Double) {
        self.minGridItemSize = minGridItemSize
    }
    
    func setOffsets(items: [PhotoGridItem], width: CGFloat, idealGridItemSize: Double) {
        let numCols = self.getNumColumns(width: width, idealGridItemSize: idealGridItemSize)
        let photoWidth = self.getColWidth(width: width, numCols: numCols)
        
        let currentItemCount = items.count
        let canDoIncrementalUpdate = (width == lastWidth &&
                                     idealGridItemSize == lastIdealSize &&
                                     currentItemCount > lastItemCount &&
                                     lastItemCount > 0)
        
        if canDoIncrementalUpdate {
            for i in lastItemCount..<currentItemCount {
                offsets[items[i].id] = self.getOffset(for: i, width: width, numCols: numCols, colWidth: photoWidth)
            }
        } else {
            let currentItemSet = Set(items.map { $0.id })
            offsets = offsets.filter { currentItemSet.contains($0.key) }
            for i in 0..<currentItemCount {
                offsets[items[i].id] = self.getOffset(for: i, width: width, numCols: numCols, colWidth: photoWidth)
            }
        }
        
        self.numCols = numCols
        self.photoWidth = photoWidth
        self.zstackHeight = photoWidth * CGFloat(self.getNumRows(items: items, width: width, idealGridItemSize: idealGridItemSize, numCols: numCols))
        
        lastItemCount = currentItemCount
        lastWidth = width
        lastIdealSize = idealGridItemSize
        self.objectWillChange.send()
    }
    
    func getOffset(for index: Int, width: CGFloat, numCols: Int, colWidth: CGFloat) -> CGSize {
        return CGSize(width: CGFloat(index % numCols) * colWidth, height: CGFloat(index / numCols) * colWidth)
    }
    
    func getPhotosInRectangle(_ rect: (x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat), items: [PhotoGridItem]) -> [String] {
        guard numCols > 0 && photoWidth > 0 else { return [] }

        let startRow = max(0, Int(rect.y1 / photoWidth))
        let endRow = min(Int(ceil(rect.y2 / photoWidth)), Int(ceil(CGFloat(items.count) / CGFloat(numCols))) - 1)
        let startCol = max(0, Int(rect.x1 / photoWidth))
        let endCol = min(Int(ceil(rect.x2 / photoWidth)) - 1, numCols - 1)

        var photoIds: [String] = []
        photoIds.reserveCapacity((endRow - startRow + 1) * (endCol - startCol + 1))

        for row in startRow...endRow {
            for col in startCol...endCol {
                let index = row * numCols + col
                if index < items.count {
                    photoIds.append(items[index].id)
                }
            }
        }

        return photoIds
    }
    
    func getColWidth(width: CGFloat, numCols: Int) -> CGFloat {
        if numCols == 0 {
            return 0
        }
        return width / CGFloat(numCols)
    }
    
    func getNumRows(items: [PhotoGridItem], width: CGFloat, idealGridItemSize: Double, numCols: Int) -> Int {
        if items.isEmpty || width == 0 || numCols == 0 {
            return 0
        }
        return Int(ceil(Double(items.count) / Double(numCols)))
    }
    
    func getNumColumns(width: CGFloat, idealGridItemSize: Double) -> Int {
        if idealGridItemSize == 0 {
            return 0
        }
        return Int(floor(width / idealGridItemSize))
    }
}

// MARK: - ReusableThumbnailView
struct ReusableThumbnailView: View {
    let item: PhotoGridItem
    let size: CGSize
    let onTap: (PhotoGridItem) -> Void
    let viewportTracker: ViewportTracker?
    
    @State private var image: NSImage?
    @State private var isLoading = false
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        onTap(item)
                    }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Group {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            }
                        }
                    )
            }
        }
        .onAppear {
            Task {
                await loadImage()
            }
        }
        .onDisappear {
            isVisible = false
            image = nil
        }
        .onChange(of: viewportTracker?.itemInfo ?? [:]) { itemInfo in
            guard let info = itemInfo[item.id] else { return }

            let wasVisible = isVisible
            isVisible = info.isVisible

            if (info.isVisible && image == nil) || (info.rowsFromVisible <= 1 && image == nil) {
                Task {
                    await loadImage()
                }
            }

            if !isVisible && wasVisible {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if !isVisible {
                        image = nil
                    }
                }
            }
        }
        .id(item.id + "\(size.width)x\(size.height)")
    }
    
    private func loadImage() async {
        guard image == nil else { return }

        isLoading = true
        defer { isLoading = false }

        let maxDisplayDimension = max(size.width, size.height)
        let info = viewportTracker?.itemInfo[item.id]
        let shouldUseHighRes = (info?.isVisible == true) || (info?.rowsFromVisible ?? Int.max) <= 1
        let thumbnailSize: CGFloat = shouldUseHighRes ? max(300.0, maxDisplayDimension) : 100.0

        image = await PhotoGridThumbnailCache.shared.getThumbnail(for: item, thumbnailSize: thumbnailSize, isHighRes: shouldUseHighRes)
    }
}

// MARK: - ReusablePhotoGrid
struct ReusablePhotoGrid<DataSource: PhotoGridDataSource>: View {
    @ObservedObject var dataSource: DataSource
    @StateObject private var gridViewModel: ReusablePhotoGridViewModel
    @StateObject private var viewportTracker = ViewportTracker()
    
    @Binding var idealGridItemSize: Double
    @Binding var multiSelectEnabled: Bool
    let minGridItemSize: Double
    let scrollable: Bool
    let scrollDirection: PhotoGridScrollDirection
    let dragSelectEnabled: Bool
    let onPhotoTap: ((PhotoGridItem) -> Void)?
    let contextActions: [PhotoGridAction]
    
    // Selection state
    @State private var selected: [String: Bool] = [:]
    
    // Drag state
    @State private var dragging: Bool = false
    @State private var dragStart: CGPoint = CGPoint()
    @State private var dragEnd: CGPoint = CGPoint()
    
    init(
        dataSource: DataSource,
        idealGridItemSize: Binding<Double>,
        multiSelectEnabled: Binding<Bool> = .constant(false),
        minGridItemSize: Double = 50.0,
        scrollable: Bool = true,
        scrollDirection: PhotoGridScrollDirection = .vertical,
        dragSelectEnabled: Bool = false,
        onPhotoTap: ((PhotoGridItem) -> Void)? = nil,
        contextActions: [PhotoGridAction] = []
    ) {
        self.dataSource = dataSource
        self._idealGridItemSize = idealGridItemSize
        self._multiSelectEnabled = multiSelectEnabled
        self.minGridItemSize = minGridItemSize
        self.scrollable = scrollable
        self.scrollDirection = scrollDirection
        self.dragSelectEnabled = dragSelectEnabled
        self.onPhotoTap = onPhotoTap
        self.contextActions = contextActions
        self._gridViewModel = StateObject(wrappedValue: ReusablePhotoGridViewModel(minGridItemSize: minGridItemSize))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let grid = ZStack(alignment: .topLeading) {
                Rectangle()
                    .frame(
                        width: scrollDirection == .horizontal ? CGFloat(dataSource.items.count) * idealGridItemSize : geometry.size.width,
                        height: scrollDirection == .horizontal ? idealGridItemSize : gridViewModel.zstackHeight
                    )
                    .opacity(0)
                
                ForEach(dataSource.items) { item in
                    ZStack {
                        ReusableThumbnailView(
                            item: item,
                            size: CGSize(width: gridViewModel.photoWidth, height: gridViewModel.photoWidth),
                            onTap: { item in
                                onPhotoTap?(item)
                            },
                            viewportTracker: viewportTracker
                        )
                        
                        if multiSelectEnabled {
                            Button {
                                handleItemSelection(for: item.id)
                            } label: {
                                Image(systemName: selected[item.id] ?? false ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: gridViewModel.photoWidth > 100 ? 24 : gridViewModel.photoWidth / 4))
                                    .padding()
                                    .frame(width: gridViewModel.photoWidth, height: gridViewModel.photoWidth)
                            }
                            .buttonStyle(SelectionButtonStyle(selected: selected[item.id] ?? false))
                            .foregroundColor(Color.white)
                        }
                    }
                    .frame(width: gridViewModel.photoWidth, height: gridViewModel.photoWidth)
                    .offset(gridViewModel.offsets[item.id] ?? CGSize())
                    .contextMenu {
                        if !contextActions.isEmpty {
                            let selectedItems = getSelectedItems()
                            ForEach(contextActions.indices, id: \.self) { index in
                                let action = contextActions[index]
                                let itemsToProcess = selectedItems.isEmpty ? [item] : selectedItems
                                let title = itemsToProcess.count > 1 ? "\(action.title) (\(itemsToProcess.count))" : action.title
                                Button(title) {
                                    action.handler(itemsToProcess)
                                }
                            }
                        }
                    }
                }
                
                if dragging && dragSelectEnabled && scrollDirection == .vertical {
                    Rectangle()
                        .fill(Color.blue.opacity(0.25))
                        .border(.blue)
                        .frame(width: abs(dragEnd.x - dragStart.x), height: abs(dragEnd.y - dragStart.y))
                        .offset(
                            x: dragEnd.x > dragStart.x ? dragStart.x : dragEnd.x,
                            y: dragEnd.y > dragStart.y ? dragStart.y : dragEnd.y
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragSelectEnabled {
                            dragging = true
                            dragStart = value.startLocation
                            dragEnd = value.location
                        }
                    }
                    .onEnded { _ in
                        if dragSelectEnabled {
                            handleDragSelection()
                            dragging = false
                            dragStart = CGPoint()
                            dragEnd = CGPoint()
                        }
                    }
            )
            
            VStack {
                if scrollable {
                    ScrollView(scrollDirection == .horizontal ? .horizontal : .vertical, showsIndicators: true) {
                        grid
                            .onFrameChange { frame in
                                if scrollDirection == .vertical {
                                    viewportTracker.onScrollFrameUpdate(frame, gridItems: dataSource.items, width: geometry.size.width, height: geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photoWidth)
                                }
                            }
                    }
                } else {
                    grid
                }
            }
            .onChange(of: multiSelectEnabled) { newValue in
                if !newValue {
                    selected = [:]
                }
            }
            .onChange(of: geometry.size) { newValue in
                if !dataSource.isLoading && !dataSource.items.isEmpty && scrollDirection == .vertical {
                    DispatchQueue.main.async {
                        gridViewModel.setOffsets(
                            items: dataSource.items,
                            width: newValue.width,
                            idealGridItemSize: idealGridItemSize
                        )
                    }
                    viewportTracker.updateRangeValuesForResize(gridItems: dataSource.items, width: newValue.width, height: newValue.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photoWidth)
                }
            }
            .onChange(of: idealGridItemSize) { newValue in
                if !dataSource.isLoading && !dataSource.items.isEmpty {
                    let width = scrollDirection == .horizontal ?
                        CGFloat(dataSource.items.count) * idealGridItemSize :
                        geometry.size.width
                    DispatchQueue.main.async {
                        withAnimation {
                            gridViewModel.setOffsets(
                                items: dataSource.items,
                                width: width,
                                idealGridItemSize: newValue
                            )
                        }
                    }
                    viewportTracker.updateRangeValuesForResize(gridItems: dataSource.items, width: width, height: geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photoWidth)
                }
            }
        }
        .onAppear {
            Task {
                do {
                    try await dataSource.loadItems(offset: 0, length: 0)
                    DispatchQueue.main.async {
                        let width = scrollDirection == .horizontal ? 
                            CGFloat(dataSource.items.count) * idealGridItemSize : 
                            NSScreen.main?.frame.width ?? 1200
                        let height = scrollDirection == .horizontal ? 
                            idealGridItemSize : 
                            NSScreen.main?.frame.height ?? 800
                        
                        gridViewModel.setOffsets(
                            items: dataSource.items,
                            width: width,
                            idealGridItemSize: idealGridItemSize
                        )
                        
                        // Initialize viewport tracking like original
                        viewportTracker.updateRangeValuesForResize(
                            gridItems: dataSource.items,
                            width: width,
                            height: height,
                            numColumns: gridViewModel.numCols,
                            colWidth: gridViewModel.photoWidth
                        )
                    }
                } catch {
                    print("Error loading items: \(error)")
                }
            }
        }
        .frame(minWidth: 300, minHeight: scrollable ? 0 : gridViewModel.zstackHeight)
    }
    
    // MARK: - Selection Logic
    
    private func handleItemSelection(for itemId: String) {
        if NSEvent.modifierFlags.contains(.shift) && !selected.isEmpty {
            handleShiftSelection(for: itemId)
        } else {
            toggleItemSelection(for: itemId)
        }
    }
    
    private func handleShiftSelection(for itemId: String) {
        guard let index = dataSource.items.firstIndex(where: { $0.id == itemId }) else { return }
        
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
        while i >= 0 && i < dataSource.items.count {
            if selected[dataSource.items[i].id] != nil {
                return i
            }
            i += direction
        }
        return -1
    }
    
    private func selectRange(from start: Int, to end: Int) {
        guard start >= 0 && end < dataSource.items.count && start <= end else { return }
        for k in start...end {
            selected[dataSource.items[k].id] = true
        }
    }
    
    private func toggleItemSelection(for itemId: String) {
        if selected[itemId] == nil {
            selected[itemId] = true
        } else {
            selected.removeValue(forKey: itemId)
        }
    }
    
    private func handleDragSelection() {
        let xValues = [dragStart.x, dragEnd.x]
        let yValues = [dragStart.y, dragEnd.y]
        let rectangle = (
            x1: xValues.min()!,
            y1: yValues.min()!,
            x2: xValues.max()!,
            y2: yValues.max()!
        )
        
        let hasValidRectangle = rectangle.x2 > rectangle.x1 && rectangle.y2 > rectangle.y1

        if hasValidRectangle {
            if !NSEvent.modifierFlags.contains(.command) {
                selected = [:]
            }
            multiSelectEnabled = true
            let photosInRectangle = gridViewModel.getPhotosInRectangle(rectangle, items: dataSource.items)
            for selectedId in photosInRectangle {
                selected[selectedId] = true
            }
        }
    }
    
    private func getSelectedItems() -> [PhotoGridItem] {
        return dataSource.items.filter { selected[$0.id] == true }
    }
}

// MARK: - SelectionButtonStyle
struct SelectionButtonStyle: ButtonStyle {
    let selected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.black.opacity(selected ? 0.5 : 0.25))
            .foregroundColor(Color.white)
            .animation(.easeOut(duration: 0.1), value: selected)
    }
}
