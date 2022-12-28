//
//  PhotoView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/24/22.
//

import SwiftUI
import SwiftBSON
import Foundation

struct MediaItem: Codable, Hashable {
    let _id: BSONObjectID
    let time: Date?
    let name: String
    let upload_id: BSONObjectID
    let size: Int64
    let upload_complete: Bool
}

struct MediaThumbView: View {
    
    @AppStorage("api_endpoint_url") private var api_endpoint_url: String = ""
    
    var appDelegate: AppDelegate
    
    let item: MediaItem
    
    @State var img: NSImage = NSImage()
    
    init(_ item: MediaItem, appDelegate: AppDelegate) {
        self.item=item
        self.appDelegate=appDelegate
    }
    
    var body: some View {
        Image(nsImage: img)
            .antialiased(true)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 500, maxHeight: 500)
        .onAppear {
            Task {
                guard let url = URL(string: api_endpoint_url+"?request=thumbnail&oid="+item._id.hex) else {
                    print("Invalid URL for \(item.name)\n")
                    return
                }
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    autoreleasepool {
                        img = NSImage(data: data) ?? NSImage()
                    }
                } catch {
                    print("Unable to load thumbnail for \(item.name)\n");
                }
            }
        }
        .onDisappear {
            img=NSImage()
        }
        .onTapGesture {
            appDelegate.openMediaItemDetailWindow(rect: CGRect(x: 0, y: 0, width: 1500, height: 1000), thumb: img, item: item)
        }
    }
}

struct MediaThumbView_Previews: PreviewProvider {
    static var previews: some View {
        try? MediaThumbView(MediaItem(_id: BSONObjectID("634491ff273cfa9985098782"), time: Date(timeIntervalSince1970: 1661834242000), name: "IMG_4303.CR3", upload_id: BSONObjectID("634491ff273cfa9985098781"), size: 28410943, upload_complete: true),appDelegate: AppDelegate())
        EmptyView()
    }
}
