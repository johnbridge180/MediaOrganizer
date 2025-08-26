//
//  ThumbnailViewModel.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/5/23.
//

import SwiftUI
import Combine

class ThumbnailViewModel: ObservableObject {
    @AppStorage("api_endpoint_url") private var apiEndpointUrl: String = ""

    var imageView: Image?
    var cgImage: CGImage?
    var orientation: Image.Orientation = .up
    var type: Int = 0

    let makeCGImageQueue: DispatchQueue
    
    private var qualityChangeTimer: Timer?
    private var pendingQuality: Int?
    private var isTransitioning: Bool = false

    private var cacheRow: PreviewCache?
    var item: MediaItem

    var isCached: Bool

    private var cachedImageLocation: URL?
    private var tinythumbLocation: URL?

    private var checkedCache = false

    init(_ item: MediaItem, cacheRow: PreviewCache?, makeCGImageQueue: DispatchQueue) {
        self.item=item
        self.cacheRow=cacheRow
        self.makeCGImageQueue=makeCGImageQueue
        if let row: PreviewCache = cacheRow {
            self.isCached=row.thumb_cached
            checkedCache=true
            do {
                let cacheURL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                cachedImageLocation=cacheURL.appendingPathComponent(self.item._id.hex+".thumb."+(row.thumb_ext ?? "jpg"))
                tinythumbLocation=cacheURL.appendingPathComponent(item._id.hex+".tiny."+(row.thumb_ext ?? "jpg"))
            } catch {}
        } else {
            isCached=false
        }
    }

    convenience init(_ item: MediaItem, makeCGImageQueue: DispatchQueue) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PreviewCache")
        fetchRequest.fetchLimit=1
        fetchRequest.predicate = NSPredicate(format: "oid_hex == %@", item._id.hex)
        do {
            let cacheRows = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            let cacheRow = !cacheRows.isEmpty ? (cacheRows[0] as? PreviewCache) : nil
            self.init(item, cacheRow: cacheRow, makeCGImageQueue: makeCGImageQueue)
        } catch {
            print("Error in ThumbViewModel: \(error)")
            self.init(item, cacheRow: nil, makeCGImageQueue: makeCGImageQueue)
        }
    }
    
    deinit {
        qualityChangeTimer?.invalidate()
    }

    func setDisplayType(_ targetType: Int) {
        guard targetType != self.type || cgImage == nil else { return }
        
        qualityChangeTimer?.invalidate()
        pendingQuality = targetType
        
        let debounceDelay: TimeInterval = isTransitioning ? 0.1 : 0.05
        
        qualityChangeTimer = Timer.scheduledTimer(withTimeInterval: debounceDelay, repeats: false) { [weak self] _ in
            self?.applyQualityChange()
        }
    }
    
    private func applyQualityChange() {
        guard let targetType = pendingQuality else { return }
        pendingQuality = nil
        
        let previousType = self.type
        
        if targetType == previousType && cgImage != nil {
            return
        }
        
        isTransitioning = true
        defer { isTransitioning = false }
        
        if shouldUseProgressiveLoading(from: previousType, to: targetType) {
            performProgressiveLoading(to: targetType)
        } else {
            performDirectQualityChange(to: targetType)
        }
    }
    
    private func shouldUseProgressiveLoading(from: Int, to: Int) -> Bool {
        return from == 0 && to == 2 && tinythumbLocation != nil
    }
    
    private func performProgressiveLoading(to finalType: Int) {
        if let url = tinythumbLocation {
            self.type = 1
            setImage(from: url)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.performDirectQualityChange(to: finalType)
            }
        } else {
            performDirectQualityChange(to: finalType)
        }
    }
    
    private func performDirectQualityChange(to targetType: Int) {
        self.type = targetType
        
        switch targetType {
        case 2:
            if let url = cachedImageLocation {
                setImage(from: url)
            } else {
                loadPlaceholder()
            }
        case 1:
            if let url = tinythumbLocation {
                setImage(from: url)
            } else {
                loadPlaceholder()
            }
        case 0:
            loadPlaceholder()
        default:
            loadPlaceholder()
        }
    }
    
    private func loadPlaceholder() {
        cgImage = nil
        imageView = nil
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    func getDisplayType() -> Int {
        return type
    }
    func checkCache() {
        guard !isCached else { return }
        guard let url = URL(string: apiEndpointUrl+"?request=thumbnail&oid="+item._id.hex) else { return }
        
        let downloadTask = URLSession.shared.downloadTask(with: url) { url, response, error in
            self.handleDownloadCompletion(url: url, response: response, error: error)
        }
        downloadTask.resume()
    }
    
    private func handleDownloadCompletion(url: URL?, response: URLResponse?, error: Error?) {
        guard let fileURL = url else { return }
        do {
            let cacheURL = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            if cacheRow == nil {
                try createNewCacheEntry(fileURL: fileURL, cacheURL: cacheURL, response: response)
            } else {
                try updateExistingCacheEntry(fileURL: fileURL, cacheURL: cacheURL)
            }
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } catch {
            print("file error: \(error)")
        }
    }
    
    private func createNewCacheEntry(fileURL: URL, cacheURL: URL, response: URLResponse?) throws {
        let fileExtension = "jpg"
        let cacheEntry = PreviewCache(context: PersistenceController.shared.container.viewContext)
        setupCacheEntry(cacheEntry, fileExtension: fileExtension, response: response, fileURL: fileURL)
        
        let savedURL = cacheURL.appendingPathComponent(item._id.hex + ".thumb." + fileExtension)
        cacheEntry.thumb_cached = true
        
        try moveFileIfNeeded(from: fileURL, to: savedURL)
        setImageIfNeeded(for: savedURL, type: 2)
        try processTinyThumbnail(savedURL: savedURL, cacheURL: cacheURL, fileExtension: fileExtension, cacheEntry: cacheEntry)
        
        cachedImageLocation = savedURL
        isCached = true
        self.cacheRow = cacheEntry
    }
    
    private func updateExistingCacheEntry(fileURL: URL, cacheURL: URL) throws {
        cacheRow?.last_accessed = Date()
        let fileExt = cacheRow?.thumb_ext ?? "jpg"
        let savedURL = cacheURL.appendingPathComponent(item._id.hex + ".thumb." + fileExt)
        
        try moveFileIfNeeded(from: fileURL, to: savedURL)
        setImageIfNeeded(for: savedURL, type: 2)
        cacheRow?.thumb_cached = true
        cachedImageLocation = savedURL
        
        try processTinyThumbnailForExisting(savedURL: savedURL, cacheURL: cacheURL, fileExt: fileExt)
        isCached = true
    }
    
    private func setupCacheEntry(_ cacheEntry: PreviewCache, fileExtension: String, response: URLResponse?, fileURL: URL) {
        cacheEntry.oid_hex = item._id.hex
        cacheEntry.thumb_ext = fileExtension
        cacheEntry.thumb_size = response?.expectedContentLength ?? Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        cacheEntry.last_accessed = Date()
        cacheEntry.preview_cached = false
        cacheEntry.preview_size = 0
        cacheEntry.prev_ext = fileExtension
    }
    
    private func moveFileIfNeeded(from source: URL, to destination: URL) throws {
        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.moveItem(at: source, to: destination)
        }
    }
    
    private func setImageIfNeeded(for url: URL, type: Int) {
        if self.type == type {
            setImage(from: url)
        }
    }
    
    private func processTinyThumbnail(savedURL: URL, cacheURL: URL, fileExtension: String, cacheEntry: PreviewCache) throws {
        guard let tinyThumb = createTinyThumbnail(savedURL) else { return }
        
        let tinythumbURL = cacheURL.appendingPathComponent(item._id.hex + ".tiny." + fileExtension)
        try saveTinyThumbnail(tinyThumb, to: tinythumbURL)
        
        cacheEntry.tiny_cached = true
        cacheEntry.tiny_size = Int64(try tinythumbURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        tinythumbLocation = tinythumbURL
        setImageIfNeeded(for: tinythumbURL, type: 1)
    }
    
    private func processTinyThumbnailForExisting(savedURL: URL, cacheURL: URL, fileExt: String) throws {
        guard let tinyThumb = createTinyThumbnail(savedURL) else { return }
        
        let tinythumbURL = cacheURL.appendingPathComponent(item._id.hex + ".tiny." + fileExt)
        try saveTinyThumbnail(tinyThumb, to: tinythumbURL)
        
        setImageIfNeeded(for: tinythumbURL, type: 1)
        cacheRow?.tiny_cached = true
        cacheRow?.tiny_size = Int64(try tinythumbURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        tinythumbLocation = tinythumbURL
    }
    
    private func saveTinyThumbnail(_ tinyThumb: CGImage, to url: URL) throws {
        let ciimage = CIImage(cgImage: tinyThumb)
        let cicontext = CIContext()
        let colorspace = ciimage.colorSpace ?? CGColorSpace(name: CGColorSpace.dcip3)
        
        if let colorspace = colorspace {
            try cicontext.writeJPEGRepresentation(of: ciimage, to: url, colorSpace: colorspace)
        }
    }
    // credit: https://medium.com/@zippicoder/downsampling-images-for-better-memory-consumption-and-uicollectionview-performance-35e0b4526425
    func createTinyThumbnail(_ url: URL) -> CGImage? {

        let tinyThumbnailWidth: CGFloat = 100.0

        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions) else {
            return nil
        }
        let maxDimensionInPixels = max(tinyThumbnailWidth, tinyThumbnailWidth) * (NSScreen.main?.backingScaleFactor ?? 1)

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }

        return downsampledImage
    }

    func setImage(from url: URL) {
        makeCGImageQueue.async {
            if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) {
                self.cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
                let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
                self.orientation = .up
                if let propertiesDictionary = imageProperties as? [String: Any] {
                    if let orientationExifValue: UInt8 = propertiesDictionary["Orientation"] as? UInt8, let orientation=Tools.translateExifOrientationToImageOrientation(orientationExifValue) {
                        self.orientation=orientation
                    }
                }
                if let cgImage = self.cgImage {
                    self.imageView = Image(cgImage, scale: 1, orientation: self.orientation, label: Text(self.item.name))
                        .resizable()
                    self.cgImage=cgImage
                }
                DispatchQueue.main.async(qos: .userInteractive, execute: {
                    self.objectWillChange.send()
                })
            }
       }
    }
}
