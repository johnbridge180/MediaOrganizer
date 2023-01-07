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
    let time: Date
    let name: String
    let upload_id: BSONObjectID
    let size: Int64
    let upload_complete: Bool
    let exif_data: ExifData
}

struct MediaItemHolder: Hashable, Identifiable {
    var id: String {
        return item._id.hex
    }
    
    static func == (lhs: MediaItemHolder, rhs: MediaItemHolder) -> Bool {
        return lhs.item._id.hex==rhs.item._id.hex
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(item._id.hex)
    }
    let item: MediaItem
    let cache_row: PreviewCache?
    var view: MediaThumbView
}

struct MediaThumbView: View {
    @AppStorage("api_endpoint_url") private var api_endpoint_url: String = ""
    
    var appDelegate: AppDelegate
    @ObservedObject var thumbVModel: ThumbViewModel
    
    init(appDelegate: AppDelegate, thumbVModel: ThumbViewModel) {
        self.appDelegate=appDelegate
        self.thumbVModel=thumbVModel
    }
    
    var body: some View {
        if thumbVModel.type != 0 {
            if let img = thumbVModel.image_view {
                img
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        appDelegate.openMediaItemDetailWindow(rect: CGRect(x: 0, y: 0, width: 1500, height: 1000), thumb: NSImage(), item: thumbVModel.item)
                    }
            } else if !thumbVModel.isCached {
                ProgressView()
                    .onAppear {
                        thumbVModel.checkCache()
                    }
            }
        } else {
            Rectangle()
                .opacity(0.0)
        }
    }
}

struct MediaThumbView_Previews: PreviewProvider {
    static var previews: some View {
        try? MediaThumbView(appDelegate: AppDelegate(), thumbVModel: ThumbViewModel(MediaItem(_id: BSONObjectID("634491ff273cfa9985098782"), time: Date(timeIntervalSince1970: 1661834242000), name: "IMG_4303.CR3", upload_id: BSONObjectID("634491ff273cfa9985098781"), size: 28410943, upload_complete: true, exif_data: ExifData(flip: 0)), cache_row: nil, makeCGImageQueue: DispatchQueue(label: "com.jbridge.makeCGImageQueue")))
        EmptyView()
    }
}
