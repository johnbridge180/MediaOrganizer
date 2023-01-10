//
//  MediaItemDetailViewModel.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/7/23.
//

import Foundation
import SwiftUI

class MediaItemDetailViewModel: ObservableObject {
    @AppStorage("api_endpoint_url") private var api_endpoint_url: String = ""
    
    let item: MediaItem
    
    var cgImage: CGImage?
    var orientation: Image.Orientation
    var imageProperties: [String: Any] = [:]
    
    private var preview_loader_observer: NSKeyValueObservation? = nil
    
    @Published var downloadProgress: Double = 0.0
    
    @Published var activeDownload: DownloadModel? = nil
    @Published var activePreviewExport: DownloadModel? = nil
    
    init(_ item: MediaItem, initialThumb: CGImage?, initialThumbOrientation: Image.Orientation) {
        self.item=item
        self.orientation=initialThumbOrientation
        if let thumb = initialThumb {
            self.cgImage=thumb
        }
    }
    
    func loadPreview() {
        guard let url = URL(string: api_endpoint_url+"?request=preview&oid="+(item._id.hex)) else {
            print("Invalid URL for \(item.name)\n")
            return
        }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let nn_data = data {
                if let imageSource = CGImageSourceCreateWithData(nn_data as CFData, nil) {
                    self.cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
                    let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource,0,nil)
                    if let propertiesDictionary = imageProperties as? [String: Any] {
                        self.imageProperties = propertiesDictionary
                        if let orientation_exifValue: UInt8 = propertiesDictionary["Orientation"] as? UInt8, let orientation=Tools.translateExifOrientationToImageOrientation(orientation_exifValue) {
                            self.orientation=orientation
                        }
                    }
                }
            }
        }
        self.preview_loader_observer = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                self.downloadProgress=progress.fractionCompleted
            }
        }
        task.resume()
    }
    
    func exportPreview() {
        let download = DownloadManager.shared.download(item, preview: true)
        DispatchQueue.main.async {
            self.activePreviewExport=download
        }
    }
    
    func downloadFile() {
        let download = DownloadManager.shared.download(item)
        DispatchQueue.main.async {
            self.activeDownload=download
        }
    }
}
