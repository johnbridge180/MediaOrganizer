//
//  ThumbViewModel.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/5/23.
//

import SwiftUI

class ThumbViewModel: ObservableObject {
    @AppStorage("api_endpoint_url") private var api_endpoint_url: String = ""
    
    var image_view: Image? = nil
    var cgImage: CGImage? = nil
    var orientation: Image.Orientation = .up
    var type: Int = 0
    
    let makeCGImageQueue: DispatchQueue
    
    private var cache_row: PreviewCache?
    var item: MediaItem
    
    var isCached: Bool
    
    private var cached_image_location: URL?
    private var tinythumb_location: URL?
    
    private var checkedCache = false
    
    init(_ item: MediaItem, cache_row: PreviewCache?, makeCGImageQueue: DispatchQueue) {
        self.item=item
        self.cache_row=cache_row
        self.makeCGImageQueue=makeCGImageQueue
        if let row:PreviewCache = cache_row {
            self.isCached=row.thumb_cached
            checkedCache=true
            do {
                let cacheURL = try
                FileManager.default.url(for: .cachesDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: nil,
                                        create: true)
                cached_image_location=cacheURL.appendingPathComponent(self.item._id.hex+".thumb."+(row.thumb_ext ?? "jpg"))
                tinythumb_location=cacheURL.appendingPathComponent(item._id.hex+".tiny."+(row.thumb_ext ?? "jpg"))
            } catch {}
        } else {
            isCached=false
        }
    }
    
    func setDisplayType(_ type: Int) {
        if(type != self.type || cgImage==nil) {
            self.type=type
            if type==2, let url = cached_image_location {
                setImage(from: url)
            } else if type==1, let url = tinythumb_location {
                setImage(from: url)
            } else {
                DispatchQueue.main.async(qos: .background, execute: {
                    self.objectWillChange.send()
                })
            }
        }
    }
    
    func getDisplayType() -> Int {
        return type
    }
    func checkCache() {
        if(isCached==false) {
            if let url = URL(string: api_endpoint_url+"?request=thumbnail&oid="+item._id.hex) {
                let downloadTask = URLSession.shared.downloadTask(with: url) {
                    url, response, error in
                    // check for and handle errors:
                    // * error should be nil
                    // * response should be an HTTPURLResponse with statusCode in 200..<299
                    
                    guard let fileURL = url else { return }
                    do {
                        let cacheURL = try
                        FileManager.default.url(for: .cachesDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
                        if(self.cache_row==nil) {
                            let file_extension = "jpg"
                            let cache_entry: PreviewCache = PreviewCache(context: PersistenceController.shared.container.viewContext)
                            cache_entry.oid_hex=self.item._id.hex
                            cache_entry.thumb_ext=file_extension
                            cache_entry.thumb_size=response?.expectedContentLength ?? Int64((try? url?.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                            cache_entry.last_accessed=Date()
                            cache_entry.preview_cached=false
                            cache_entry.preview_size=0
                            cache_entry.prev_ext=file_extension
                            let savedURL = cacheURL.appendingPathComponent(self.item._id.hex+".thumb."+file_extension)
                            cache_entry.thumb_cached=true
                            if(!FileManager.default.fileExists(atPath: savedURL.path)) {
                                try FileManager.default.moveItem(at: fileURL, to: savedURL)
                            }
                            if(self.type==2) {
                                self.setImage(from: savedURL)
                            }
                            if let tiny_thumb: CGImage = self.createTinyThumbnail(savedURL) {
                                let tinythumbURL = cacheURL.appendingPathComponent(self.item._id.hex+".tiny."+file_extension)
                                let ciimage = CIImage(cgImage: tiny_thumb)
                                let cicontext = CIContext()
                                if let colorspace = ciimage.colorSpace ?? CGColorSpace(name: CGColorSpace.dcip3) {
                                    try cicontext.writeJPEGRepresentation(of: ciimage, to: tinythumbURL, colorSpace: colorspace)
                                    cache_entry.tiny_cached = true
                                    cache_entry.tiny_size = Int64(try tinythumbURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                                    self.tinythumb_location=tinythumbURL
                                    if(self.type==1) {
                                        self.setImage(from: tinythumbURL)
                                    }
                                }
                            }
                            self.cached_image_location=savedURL
                            self.isCached=true
                            self.cache_row=cache_entry
                        } else {
                            self.cache_row?.last_accessed=Date()
                            let savedURL = cacheURL.appendingPathComponent(self.item._id.hex+".thumb."+(self.cache_row?.thumb_ext ?? "jpg"))
                            if(!FileManager.default.fileExists(atPath: savedURL.path)) {
                                try FileManager.default.moveItem(at: fileURL, to: savedURL)
                            }
                            if(self.type==2) {
                                self.setImage(from: savedURL)
                            }
                            self.cache_row?.thumb_cached=true
                            self.cached_image_location=savedURL
                            if let tiny_thumb: CGImage = self.createTinyThumbnail(savedURL) {
                                let tinythumbURL = cacheURL.appendingPathComponent(self.item._id.hex+".tiny."+(self.cache_row?.thumb_ext ?? "jpg"))
                                let ciimage = CIImage(cgImage: tiny_thumb)
                                let cicontext = CIContext()
                                if let colorspace = ciimage.colorSpace ?? CGColorSpace(name: CGColorSpace.dcip3) {
                                    try cicontext.writeJPEGRepresentation(of: ciimage, to: tinythumbURL, colorSpace: colorspace)
                                    if(self.type==1) {
                                        self.setImage(from: tinythumbURL)
                                    }
                                    self.cache_row?.tiny_cached = true
                                    self.cache_row?.tiny_size = Int64(try tinythumbURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                                    self.tinythumb_location=tinythumbURL
                                }
                            }
                            self.isCached=true
                        }
                        DispatchQueue.main.async {
                            self.objectWillChange.send()
                        }
                    } catch {
                        print ("file error: \(error)")
                    }
                }
                downloadTask.resume()
            }
        }
    }
    //credit: https://medium.com/@zippicoder/downsampling-images-for-better-memory-consumption-and-uicollectionview-performance-35e0b4526425
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
                let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource,0,nil)
                self.orientation = .up
                if let propertiesDictionary = imageProperties as? [String: Any] {
                    if let orientation_exifValue: UInt8 = propertiesDictionary["Orientation"] as? UInt8, let orientation=Tools.translateExifOrientationToImageOrientation(orientation_exifValue) {
                        self.orientation=orientation
                    }
                }
                if let cgImage = self.cgImage {
                    self.image_view = Image(cgImage, scale: 1, orientation: self.orientation, label: Text(self.item.name))
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
