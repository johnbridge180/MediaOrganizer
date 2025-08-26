//
//  ThumbnailViewModel.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/5/23.
//

import SwiftUI

class ThumbnailViewModel: ObservableObject {
    @AppStorage("api_endpoint_url") private var apiEndpointUrl: String = ""

    var imageView: Image?
    var cgImage: CGImage?
    var orientation: Image.Orientation = .up
    var type: Int = 0

    let makeCGImageQueue: DispatchQueue

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

    func setDisplayType(_ type: Int) {
        if type != self.type || cgImage==nil {
            self.type=type
            if type==2, let url = cachedImageLocation {
                setImage(from: url)
            } else if type==1, let url = tinythumbLocation {
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
        if isCached==false {
            if let url = URL(string: apiEndpointUrl+"?request=thumbnail&oid="+item._id.hex) {
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
                        if self.cacheRow==nil {
                            let fileExtension = "jpg"
                            let cacheEntry: PreviewCache = PreviewCache(context: PersistenceController.shared.container.viewContext)
                            cacheEntry.oid_hex=self.item._id.hex
                            cacheEntry.thumb_ext=fileExtension
                            cacheEntry.thumb_size=response?.expectedContentLength ?? Int64((try? url?.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                            cacheEntry.last_accessed=Date()
                            cacheEntry.preview_cached=false
                            cacheEntry.preview_size=0
                            cacheEntry.prev_ext=fileExtension
                            let savedURL = cacheURL.appendingPathComponent(self.item._id.hex+".thumb."+fileExtension)
                            cacheEntry.thumb_cached=true
                            if !FileManager.default.fileExists(atPath: savedURL.path) {
                                try FileManager.default.moveItem(at: fileURL, to: savedURL)
                            }
                            if self.type==2 {
                                self.setImage(from: savedURL)
                            }
                            if let tinyThumb: CGImage = self.createTinyThumbnail(savedURL) {
                                let tinythumbURL = cacheURL.appendingPathComponent(self.item._id.hex+".tiny."+fileExtension)
                                let ciimage = CIImage(cgImage: tinyThumb)
                                let cicontext = CIContext()
                                if let colorspace = ciimage.colorSpace ?? CGColorSpace(name: CGColorSpace.dcip3) {
                                    try cicontext.writeJPEGRepresentation(of: ciimage, to: tinythumbURL, colorSpace: colorspace)
                                    cacheEntry.tiny_cached = true
                                    cacheEntry.tiny_size = Int64(try tinythumbURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                                    self.tinythumbLocation=tinythumbURL
                                    if self.type==1 {
                                        self.setImage(from: tinythumbURL)
                                    }
                                }
                            }
                            self.cachedImageLocation=savedURL
                            self.isCached=true
                            self.cacheRow=cacheEntry
                        } else {
                            self.cacheRow?.last_accessed=Date()
                            let savedURL = cacheURL.appendingPathComponent(self.item._id.hex+".thumb."+(self.cacheRow?.thumb_ext ?? "jpg"))
                            if !FileManager.default.fileExists(atPath: savedURL.path) {
                                try FileManager.default.moveItem(at: fileURL, to: savedURL)
                            }
                            if self.type==2 {
                                self.setImage(from: savedURL)
                            }
                            self.cacheRow?.thumb_cached=true
                            self.cachedImageLocation=savedURL
                            if let tinyThumb: CGImage = self.createTinyThumbnail(savedURL) {
                                let tinythumbURL = cacheURL.appendingPathComponent(self.item._id.hex+".tiny."+(self.cacheRow?.thumb_ext ?? "jpg"))
                                let ciimage = CIImage(cgImage: tinyThumb)
                                let cicontext = CIContext()
                                if let colorspace = ciimage.colorSpace ?? CGColorSpace(name: CGColorSpace.dcip3) {
                                    try cicontext.writeJPEGRepresentation(of: ciimage, to: tinythumbURL, colorSpace: colorspace)
                                    if self.type==1 {
                                        self.setImage(from: tinythumbURL)
                                    }
                                    self.cacheRow?.tiny_cached = true
                                    self.cacheRow?.tiny_size = Int64(try tinythumbURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                                    self.tinythumbLocation=tinythumbURL
                                }
                            }
                            self.isCached=true
                        }
                        DispatchQueue.main.async {
                            self.objectWillChange.send()
                        }
                    } catch {
                        print("file error: \(error)")
                    }
                }
                downloadTask.resume()
            }
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
