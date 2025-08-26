//
//  ThumbnailView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/24/22.
//

import SwiftUI
import SwiftBSON
import Foundation

struct ThumbnailView: View {
    @AppStorage("api_endpoint_url") private var apiEndpointUrl: String = ""

    var appDelegate: AppDelegate
    // TODO: explore changing to @StateObject (@ObservedObject will need to be reinstantiated if view is redrawn)
    @ObservedObject var thumbVModel: ThumbnailViewModel

    init(appDelegate: AppDelegate, thumbVModel: ThumbnailViewModel) {
        self.appDelegate=appDelegate
        self.thumbVModel=thumbVModel
    }

    var body: some View {
        if thumbVModel.type != 0 {
            if let img = thumbVModel.imageView {
                img
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        appDelegate.openMediaItemDetailWindow(rect: CGRect(x: 0, y: 0, width: 1500, height: 1000), item: thumbVModel.item, initialThumb: thumbVModel.cgImage, orientation: thumbVModel.orientation)
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

struct ThumbnailView_Previews: PreviewProvider {
    static var previews: some View {
        try? ThumbnailView(appDelegate: AppDelegate(), thumbVModel: ThumbnailViewModel(MediaItem(_id: BSONObjectID("634491ff273cfa9985098782"), time: Date(timeIntervalSince1970: 1661834242000), name: "IMG_4303.CR3", uploadId: BSONObjectID("634491ff273cfa9985098781"), size: 28410943, uploadComplete: true, exifData: ExifData(width: 1, height: 1, make: "Make", model: "Model", shutterSpeed: 0.1, isoSpeed: 100, lens: "LENS", focalLength: 0.1, aperture: 4.0, flip: 0)), cacheRow: nil, makeCGImageQueue: DispatchQueue(label: "com.jbridge.makeCGImageQueue")))
        EmptyView()
    }
}
