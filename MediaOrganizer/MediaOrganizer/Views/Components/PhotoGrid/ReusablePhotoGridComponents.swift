//
//  ReusablePhotoGridComponents.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/28/25.
//

import Foundation
import SwiftUI
import SwiftBSON
import MongoSwift

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage

extension NSImage {
    func jpegRepresentation(compressionFactor: CGFloat) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor])
    }
}
#endif

// MARK: - PhotoGridItem
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

// MARK: - PhotoGridAction
struct PhotoGridAction {
    let title: String
    let handler: ([PhotoGridItem]) -> Void
    
    init(title: String, handler: @escaping ([PhotoGridItem]) -> Void) {
        self.title = title
        self.handler = handler
    }
}

// MARK: - PhotoGridDataSource Protocol
protocol PhotoGridDataSource: ObservableObject {
    var items: [PhotoGridItem] { get }
    var isLoading: Bool { get }
    
    func loadItems() async throws
    func loadMoreItems() async throws
}

// MARK: - PhotoGridThumbnailCache
class PhotoGridThumbnailCache {
    static let shared = PhotoGridThumbnailCache()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let cacheDirectory: URL
    private let metadataURL: URL
    private var cacheMetadata: CacheMetadata
    
    private struct CacheMetadata: Codable {
        var totalSize: Int64 = 0
        var itemCount: Int = 0
        var items: [String: CacheItemInfo] = [:]
    }
    
    private struct CacheItemInfo: Codable {
        let fileSize: Int64
        let createdAt: Date
        let originalURL: String
    }
    
    private init() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cacheDir.appendingPathComponent("PhotoGridThumbnails")
        self.metadataURL = cacheDirectory.appendingPathComponent("metadata.plist")
        
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        if let data = try? Data(contentsOf: metadataURL),
           let metadata = try? PropertyListDecoder().decode(CacheMetadata.self, from: data) {
            self.cacheMetadata = metadata
        } else {
            self.cacheMetadata = CacheMetadata()
        }
        
        setupMemoryCache()
    }
    
    private func setupMemoryCache() {
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100MB memory limit
        memoryCache.countLimit = 1000 // Max 1000 images in memory
    }
    
    func getThumbnail(for item: PhotoGridItem, size: CGSize) async -> UIImage? {
        let cacheKey = cacheKey(for: item, size: size)
        
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }
        
        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            
            // Add to memory cache
            let cost = Int(data.count)
            memoryCache.setObject(image, forKey: cacheKey as NSString, cost: cost)
            return image
        }
        
        // Load and cache the image
        return await loadAndCacheImage(for: item, size: size, cacheKey: cacheKey)
    }
    
    private func loadAndCacheImage(for item: PhotoGridItem, size: CGSize, cacheKey: String) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: item.imageURL)
            guard let originalImage = UIImage(data: data) else { return nil }
            
            let thumbnail = await createThumbnail(from: originalImage, size: size)
            
            // Cache to disk
            #if canImport(UIKit)
            let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8)
            #else
            let thumbnailData = thumbnail.jpegRepresentation(compressionFactor: 0.8)
            #endif
            if let thumbnailData = thumbnailData {
                let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
                try? thumbnailData.write(to: fileURL)
                
                // Update metadata
                await updateMetadata(cacheKey: cacheKey, fileSize: Int64(thumbnailData.count), originalURL: item.imageURL.absoluteString)
                
                // Cache to memory
                let cost = thumbnailData.count
                memoryCache.setObject(thumbnail, forKey: cacheKey as NSString, cost: cost)
            }
            
            return thumbnail
        } catch {
            print("Failed to load image from \(item.imageURL): \(error)")
            return nil
        }
    }
    
    @MainActor
    private func createThumbnail(from image: UIImage, size: CGSize) -> UIImage {
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        #else
        let targetRect = NSRect(origin: .zero, size: size)
        let thumbnailImage = NSImage(size: size)
        thumbnailImage.lockFocus()
        image.draw(in: targetRect, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
        thumbnailImage.unlockFocus()
        return thumbnailImage
        #endif
    }
    
    private func cacheKey(for item: PhotoGridItem, size: CGSize) -> String {
        let sizeString = "\(Int(size.width))x\(Int(size.height))"
        return "\(item.id)_\(sizeString)".replacingOccurrences(of: "/", with: "_")
    }
    
    private func updateMetadata(cacheKey: String, fileSize: Int64, originalURL: String) async {
        await MainActor.run {
            let wasNew = cacheMetadata.items[cacheKey] == nil
            
            cacheMetadata.items[cacheKey] = CacheItemInfo(
                fileSize: fileSize,
                createdAt: Date(),
                originalURL: originalURL
            )
            
            if wasNew {
                cacheMetadata.totalSize += fileSize
                cacheMetadata.itemCount += 1
            }
            
            saveMetadata()
        }
    }
    
    private func saveMetadata() {
        do {
            let data = try PropertyListEncoder().encode(cacheMetadata)
            try data.write(to: metadataURL)
        } catch {
            print("Failed to save cache metadata: \(error)")
        }
    }
    
    var cacheSize: Int64 {
        cacheMetadata.totalSize
    }
    
    var itemCount: Int {
        cacheMetadata.itemCount
    }
    
    func clearCache() {
        memoryCache.removeAllObjects()
        
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        cacheMetadata = CacheMetadata()
        saveMetadata()
    }
}

// MARK: - ReusableThumbnailView
struct ReusableThumbnailView: View {
    let item: PhotoGridItem
    let size: CGSize
    let onTap: (PhotoGridItem) -> Void
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            if let image = image {
                #if canImport(UIKit)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        onTap(item)
                    }
                #else
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        onTap(item)
                    }
                #endif
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
        .id(item.id + "\(size.width)x\(size.height)")
    }
    
    private func loadImage() async {
        guard image == nil else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        image = await PhotoGridThumbnailCache.shared.getThumbnail(for: item, size: size)
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

// MARK: - PhotoGridScrollDirection
enum PhotoGridScrollDirection {
    case vertical
    case horizontal
}

// MARK: - ReusablePhotoGrid
struct ReusablePhotoGrid<DataSource: PhotoGridDataSource>: View {
    @ObservedObject var dataSource: DataSource
    @StateObject private var gridViewModel: ReusablePhotoGridViewModel
    
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
                            }
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
                        gridViewModel.setOffsets(
                            items: dataSource.items,
                            width: width,
                            idealGridItemSize: idealGridItemSize
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

struct SelectionButtonStyle: ButtonStyle {
    let selected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.black.opacity(selected ? 0.5 : 0.25))
            .foregroundColor(Color.white)
            .animation(.easeOut(duration: 0.1), value: selected)
    }
}

// MARK: - MongoPhotoGridDataSource
class MongoPhotoGridDataSource: PhotoGridDataSource {
    @Published var items: [PhotoGridItem] = []
    @Published var isLoading: Bool = false
    
    private let mongoHolder: MongoClientHolder
    private let filter: BSONDocument
    private let limit: Int
    private(set) var apiEndpointUrl: String
    
    private var mediaItemLookup: [String: MediaItem] = [:]
    
    init(mongoHolder: MongoClientHolder, filter: BSONDocument, limit: Int = 0, apiEndpointUrl: String) {
        self.mongoHolder = mongoHolder
        self.filter = filter
        self.limit = limit
        self.apiEndpointUrl = apiEndpointUrl
    }
    
    func getMediaItem(for itemId: String) -> MediaItem? {
        return mediaItemLookup[itemId]
    }
    
    @MainActor
    func loadItems() async throws {
        isLoading = true
        defer { isLoading = false }
        
        if mongoHolder.client == nil {
            await mongoHolder.connect()
        }
        
        guard let client = mongoHolder.client else { 
            throw PhotoGridError.connectionFailed
        }
        
        let filesCollection = client.db("media_organizer").collection("files")
        var options = FindOptions(sort: ["time": -1])
        if limit > 0 {
            options = FindOptions(limit: limit, sort: ["time": -1, "_id": -1])
        }
        
        var newItems: [PhotoGridItem] = []
        
        for try await doc in try await filesCollection.find(filter, options: options) {
            if let item: MediaItem = try? BSONDecoder().decode(MediaItem.self, from: doc) {
                let imageURL = createImageURL(for: item)
                let photoGridItem = PhotoGridItem(id: item._id.hex, imageURL: imageURL)
                newItems.append(photoGridItem)
                mediaItemLookup[item._id.hex] = item
            }
        }
        
        items = newItems
    }
    
    func loadMoreItems() async throws {
        // Implementation for pagination if needed in the future
    }
    
    private func createImageURL(for mediaItem: MediaItem) -> URL {
        let baseURL = apiEndpointUrl.isEmpty ? "http://localhost:8080" : apiEndpointUrl
        let urlString = "\(baseURL)/api/files/\(mediaItem._id.hex)/thumbnail"
        return URL(string: urlString) ?? URL(fileURLWithPath: "/dev/null")
    }
}

enum PhotoGridError: Error {
    case connectionFailed
    case loadingFailed(String)
}
