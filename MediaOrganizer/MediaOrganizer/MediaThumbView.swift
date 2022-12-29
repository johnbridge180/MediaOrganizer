//
//  PhotoView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/24/22.
//

import SwiftUI
import SwiftBSON
import Foundation

struct ExifData: Codable, Hashable {
    let flip: Int
}

struct MediaItem: Codable, Hashable {
    let _id: BSONObjectID
    let time: Date?
    let name: String
    let upload_id: BSONObjectID
    let size: Int64
    let upload_complete: Bool
    let exif_data: ExifData
}

struct MediaItemHolder: Hashable {
    let item: MediaItem
    let cache_row: PreviewCache?
}

struct MediaThumbView: View {
    
    @AppStorage("api_endpoint_url") private var api_endpoint_url: String = ""
    
    var appDelegate: AppDelegate
    
    let item: MediaItem
    
    @State var cached_image_location: URL? = nil
    
    @State var isCached: Bool
    
    @State var cache_row: PreviewCache? = nil
    
    init(_ item: MediaItem, appDelegate: AppDelegate, entry: PreviewCache) {
        self.item=item
        self.appDelegate=appDelegate
        _isCached=State(initialValue: entry.thumb_cached)
        if(entry.thumb_cached) {
            do {
                let cacheURL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                _cached_image_location = State(initialValue: cacheURL.appendingPathComponent(item._id.hex+".thumb."+(cache_row?.thumb_ext ?? "jpg")))
                entry.last_accessed=Date()
            } catch {}
        }
        _cache_row=State(initialValue: entry)
    }
    
    init(_ item: MediaItem, appDelegate: AppDelegate) {
        self.item=item
        self.appDelegate=appDelegate
        print("This one not cached\n")
        _isCached=State(initialValue: false)
    }
    
    var body: some View {
        if #available(macOS 12.0, *) {
            //TODO: rotate images before storing on server + reduce jpeg compression quality and scale down img?
            AsyncImage(url: cached_image_location) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        appDelegate.openMediaItemDetailWindow(rect: CGRect(x: 0, y: 0, width: 1500, height: 1000), thumb: NSImage(), item: item)
                    }
            } placeholder: {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .task {
                checkCache()
            }
        } else {
            if isCached, let cached_img_url: URL = cached_image_location,
               let dataProvider:CGDataProvider = CGDataProvider(url: cached_img_url as CFURL),
               let cgImage: CGImage = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .perceptual),
               let orientation: Image.Orientation = Image.Orientation(rawValue: UInt8(item.exif_data.flip)) {
                Image(cgImage, scale: 1, orientation: orientation, label: Text(item.name))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        appDelegate.openMediaItemDetailWindow(rect: CGRect(x: 0, y: 0, width: 1500, height: 1000), thumb: NSImage(), item: item)
                    }
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onAppear {
                        checkCache()
                    }
            }
        }
    }
    
    func checkCache() {
        if(isCached==false) {
            print("downloading for no reason?")
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
                        if(cache_row==nil) {
                            print("Thumbnail download mime type: \(String(describing: response?.mimeType))")
                            let file_extension = "jpg"
                            let cache_entry: PreviewCache = PreviewCache(context: PersistenceController.shared.container.viewContext)
                            cache_entry.oid_hex=item._id.hex
                            cache_entry.thumb_ext=file_extension
                            cache_entry.thumb_size=response?.expectedContentLength ?? Int64((try? url?.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                            cache_entry.last_accessed=Date()
                            cache_entry.preview_cached=false
                            cache_entry.preview_size=0
                            cache_entry.prev_ext=file_extension
                            let savedURL = cacheURL.appendingPathComponent(item._id.hex+".thumb."+file_extension)
                            cache_entry.thumb_cached=true
                            if(!FileManager.default.fileExists(atPath: savedURL.path)) {
                                try FileManager.default.moveItem(at: fileURL, to: savedURL)
                            }
                            DispatchQueue.main.async {
                                cached_image_location=savedURL
                                isCached=true
                            }
                            cache_row=cache_entry
                        } else {
                            cache_row?.last_accessed=Date()
                            let savedURL = cacheURL.appendingPathComponent(item._id.hex+".thumb."+(cache_row?.thumb_ext ?? "jpg"))
                            if(!FileManager.default.fileExists(atPath: savedURL.path)) {
                                try FileManager.default.moveItem(at: fileURL, to: savedURL)
                            }
                            cache_row?.thumb_cached=true
                            DispatchQueue.main.async {
                                cached_image_location=savedURL
                                isCached=true
                            }
                        }
                    } catch {
                        print ("file error: \(error)")
                    }
                }
                downloadTask.resume()
            }
        }
    }
}

struct MediaThumbView_Previews: PreviewProvider {
    static var previews: some View {
        try? MediaThumbView(MediaItem(_id: BSONObjectID("634491ff273cfa9985098782"), time: Date(timeIntervalSince1970: 1661834242000), name: "IMG_4303.CR3", upload_id: BSONObjectID("634491ff273cfa9985098781"), size: 28410943, upload_complete: true, exif_data: ExifData(flip: 0)),appDelegate: AppDelegate())
        EmptyView()
    }
}
