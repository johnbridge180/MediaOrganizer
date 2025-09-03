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
import SwiftBSON
import MongoSwift
import AppKit
import Combine

// MARK: - Extensions
extension NSImage {
    func jpegRepresentation(compressionFactor: CGFloat) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor])
    }
}

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
    
    func loadItems() async throws
    func getMediaItem(for id: String) -> MediaItem?
}

// MARK: - MongoPhotoGridDataSource
class MongoPhotoGridDataSource: PhotoGridDataSource {
    @Published var items: [PhotoGridItem] = []
    @Published var isLoading: Bool = false
    
    private let mongoHolder: MongoClientHolder
    private let filter: BSONDocument
    private let limit: Int
    let apiEndpointUrl: String
    
    private var mediaItems: [String: MediaItem] = [:]
    
    init(mongoHolder: MongoClientHolder, filter: BSONDocument, limit: Int, apiEndpointUrl: String) {
        self.mongoHolder = mongoHolder
        self.filter = filter
        self.limit = limit
        self.apiEndpointUrl = apiEndpointUrl
    }
    
    @MainActor
    func loadItems() async throws {
        isLoading = true
        defer { isLoading = false }
        
        if mongoHolder.client == nil {
            await mongoHolder.connect()
        }
        
        guard let client = mongoHolder.client else {
            throw PhotoGridError.networkError(NSError(domain: "MongoConnection", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not connect to MongoDB"]))
        }
        
        let filesCollection = client.db("media_organizer").collection("files")
        var options = FindOptions(sort: ["time": -1])
        if limit > 0 {
            options = FindOptions(limit: limit, sort: ["time": -1, "_id": -1])
        }
        
        var newItems: [PhotoGridItem] = []
        var newMediaItems: [String: MediaItem] = [:]
        
        for try await doc in try await filesCollection.find(filter, options: options) {
            if let item: MediaItem = try? BSONDecoder().decode(MediaItem.self, from: doc) {
                let gridItem = PhotoGridItem(
                    id: item._id.hex,
                    imageURL: URL(string: apiEndpointUrl + "?request=thumbnail&oid=" + item._id.hex) ?? URL(fileURLWithPath: "/")
                )
                newItems.append(gridItem)
                newMediaItems[item._id.hex] = item
            }
        }
        
        self.items = newItems
        self.mediaItems = newMediaItems
    }
    
    func getMediaItem(for id: String) -> MediaItem? {
        return mediaItems[id]
    }
}

// MARK: - PhotoGridThumbnailCache
class PhotoGridThumbnailCache {
    static let shared = PhotoGridThumbnailCache()
    
    private enum Constants {
        static let tinyThumbnailWidth: CGFloat = 100.0
        static let largeIconThreshold: CGFloat = 180.0
    }
    
    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.mediaorganizer.thumbnailcache", qos: .userInitiated)
    
    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }
    
    @MainActor
    func getThumbnail(for item: PhotoGridItem, displaySize: CGSize, isVisible: Bool = true) async -> NSImage? {
        // Determine if we need high-res or tiny thumbnail based on display size and visibility
        let maxDisplayDimension = max(displaySize.width, displaySize.height)
        let useHighRes = isVisible && maxDisplayDimension >= Constants.largeIconThreshold
        
        let thumbnailType = useHighRes ? "high" : "tiny"
        let cacheKey = "\(item.id)_\(thumbnailType)"
        
        // Check cache first
        if let cachedImage = cache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }
        
        // Load and cache image
        return await loadAndCacheImage(for: item, useHighRes: useHighRes, cacheKey: cacheKey)
    }
    
    private func loadAndCacheImage(for item: PhotoGridItem, useHighRes: Bool, cacheKey: String) async -> NSImage? {
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
                    
                    Task { @MainActor in
                        let thumbnail = await self.createThumbnail(from: originalImage, useHighRes: useHighRes)
                        self.cache.setObject(thumbnail, forKey: cacheKey as NSString)
                        continuation.resume(returning: thumbnail)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    @MainActor
    private func createThumbnail(from image: NSImage, useHighRes: Bool) async -> NSImage {
        // Choose max dimension based on resolution level
        let maxDimension: CGFloat = useHighRes ? 300.0 : Constants.tinyThumbnailWidth
        let sourceSize = image.size
        
        // Calculate thumbnail size preserving aspect ratio
        let aspectRatio = sourceSize.width / sourceSize.height
        let thumbnailSize: CGSize
        
        if aspectRatio > 1 {
            // Landscape: width is larger
            thumbnailSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait or square: height is larger or equal
            thumbnailSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        let thumbnailImage = NSImage(size: thumbnailSize)
        
        thumbnailImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbnailSize))
        thumbnailImage.unlockFocus()
        
        return thumbnailImage
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    func removeCachedImage(for itemId: String) {
        let highResKey = "\(itemId)_high"
        let tinyKey = "\(itemId)_tiny"
        cache.removeObject(forKey: highResKey as NSString)
        cache.removeObject(forKey: tinyKey as NSString)
    }
}

// MARK: - ViewportTracker
class ViewportTracker: ObservableObject {
    @Published var visibleItems: Set<String> = []
    @Published var highResItems: Set<String> = []
    
    private let updateQueue: DispatchQueue
    private var lastScrollFrameUpdate: Date = Date()
    private var lastSeenZStackOrigin: CGFloat = 0.0
    private let scrollUpdateDelay: Double = 0.2
    private let lowresTriggerWidth: Double = 100.0
    
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
        // Performance optimization: only update if scroll distance is significant
        if isScrollUpdate && abs(self.lastSeenZStackOrigin - zstackOriginY) < colWidth {
            return
        }
        self.lastSeenZStackOrigin = zstackOriginY
        
        guard !gridItems.isEmpty && numColumns > 0 else { return }
        
        let assumedIndexRange = getAssumedDisplayedIndexRange(zstackOriginY: zstackOriginY, height: height, numColumns: numColumns, colWidth: colWidth, itemCount: gridItems.count)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if colWidth > self.lowresTriggerWidth {
                // High-res mode: visible items + buffer get high-res, others get tiny thumbnails
                let modifier = numColumns  // One row buffer above and below
                let bigthumbLowerBound = assumedIndexRange.lowerBound - modifier
                let bigthumbUpperBound = assumedIndexRange.upperBound + modifier
                let bigthumbIndexRange = max(0, bigthumbLowerBound)...min(gridItems.count - 1, bigthumbUpperBound)
                
                let highResItemIds = Set(bigthumbIndexRange.compactMap { index in
                    index < gridItems.count ? gridItems[index].id : nil
                })
                
                let allVisibleIds = Set(gridItems.map { $0.id })
                
                self.highResItems = highResItemIds
                self.visibleItems = allVisibleIds
            } else {
                // Low-res mode: everything gets tiny thumbnails
                let allItemIds = Set(gridItems.map { $0.id })
                self.highResItems = []
                self.visibleItems = allItemIds
            }
        }
    }
    
    private func getAssumedDisplayedIndexRange(zstackOriginY: CGFloat, height: CGFloat, numColumns: Int, colWidth: CGFloat, itemCount: Int) -> ClosedRange<Int> {
        let maxNumRows: Int = colWidth == 0 ? 0 : Int(ceil(height / colWidth))
        let assumedAmtDisplayed: Int = maxNumRows * numColumns
        // zstackOriginY will be negative after scrolling
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
        var photoIds: [String] = []
        
        let startRow = Int(rect.y1 / photoWidth)
        let endRow = Int(rect.y2 / photoWidth)
        var startCol = Int(rect.x1 / photoWidth)
        var endCol = Int(rect.x2 / photoWidth)
        
        if startCol >= numCols { startCol = numCols - 1 } else if startCol < 0 { startCol = 0 }
        if endCol >= numCols { endCol = numCols - 1 } else if endCol < 0 { endCol = 0 }
        
        var i = startRow * numCols
        while i <= endRow * numCols && i <= items.count {
            var k = startCol
            while k <= endCol {
                if i + k >= items.count {
                    break
                }
                photoIds.append(items[i + k].id)
                k += 1
            }
            i += numCols
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
        .onChange(of: viewportTracker?.highResItems ?? Set<String>()) { highResItems in
            let shouldUseHighRes = highResItems.contains(item.id)
            let wasVisible = isVisible
            isVisible = (viewportTracker?.visibleItems ?? Set<String>()).contains(item.id)
            
            // Load or upgrade image when visibility or resolution needs change
            if (shouldUseHighRes && !wasVisible) || (isVisible && image == nil) {
                Task {
                    await loadImage()
                }
            }
            
            // Clear image when no longer visible to save memory
            if !isVisible && wasVisible {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
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
        
        // Use high-res items set to determine thumbnail quality
        let shouldUseHighRes = (viewportTracker?.highResItems ?? Set<String>()).contains(item.id)
        image = await PhotoGridThumbnailCache.shared.getThumbnail(for: item, displaySize: size, isVisible: shouldUseHighRes)
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
                                Button(action.title) {
                                    let itemsToProcess = selectedItems.isEmpty ? [item] : selectedItems
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
                    DispatchQueue.main.async {
                        withAnimation {
                            let width = scrollDirection == .horizontal ? 
                                CGFloat(dataSource.items.count) * idealGridItemSize : 
                                geometry.size.width
                            gridViewModel.setOffsets(
                                items: dataSource.items,
                                width: width,
                                idealGridItemSize: newValue
                            )
                        }
                    }
                    let width = scrollDirection == .horizontal ? 
                        CGFloat(dataSource.items.count) * idealGridItemSize : 
                        geometry.size.width
                    viewportTracker.updateRangeValuesForResize(gridItems: dataSource.items, width: width, height: geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photoWidth)
                }
            }
        }
        .onAppear {
            Task {
                do {
                    try await dataSource.loadItems()
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
        let rectangle = (
            x1: dragEnd.x > dragStart.x ? dragStart.x : dragEnd.x,
            y1: dragEnd.y > dragStart.y ? dragStart.y : dragEnd.y,
            x2: dragEnd.x > dragStart.x ? dragEnd.x : dragStart.x,
            y2: dragEnd.y > dragStart.y ? dragEnd.y : dragStart.y
        )
        
        if !(rectangle.x1 == 0 && rectangle.y1 == 0 && rectangle.x2 == 0 && rectangle.y2 == 0) {
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
