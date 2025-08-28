//
//  PhotoGridThumbnailCache.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/28/25.
//

import Foundation
import SwiftUI

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
