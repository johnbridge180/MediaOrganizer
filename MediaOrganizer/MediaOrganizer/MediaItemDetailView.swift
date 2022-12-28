//
//  MediaItemDetailView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/26/22.
//

import SwiftUI
import SwiftBSON

struct MediaItemDetailView: View {
    
    
    @AppStorage("api_endpoint_url") private var api_endpoint_url: String = ""
    
    @State var preview_loader_observer: NSKeyValueObservation? = nil
    
    var item: MediaItem
    @State var preview: NSImage
    @State var progress: Double = 0.0
    
    init(thumb: NSImage, item: MediaItem) {
        self.item=item
        self._preview=State(initialValue: thumb)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                VStack {
                    //TODO: cache all images on disk before displaying (1. because NSImage eats up ridiculous amounts of RAM, 2. cache makes fetch faster in future)
                    Image(nsImage: preview)
                        .antialiased(true)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width*(3.0/5), maxHeight: geometry.size.height)
                        .onAppear {
                            Task {
                                guard let url = URL(string: api_endpoint_url+"?request=preview&oid="+(item._id.hex)) else {
                                    print("Invalid URL for \(item.name)\n")
                                    return
                                }
                                let task = URLSession.shared.dataTask(with: url) { data, response, error in
                                    autoreleasepool {
                                        self.preview = NSImage(data: data ?? Data()) ?? NSImage()
                                    }
                                }
                                self.preview_loader_observer = task.progress.observe(\.fractionCompleted) { progress, _ in
                                    self.progress=progress.fractionCompleted
                                }
                                task.resume()
                            }
                        }
                    HStack {
                        if(progress<1.0) {
                            Text("Loading Image")
                            ProgressView(value: progress, total:1.0)
                        }
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                //TODO: get text to line up properly
                VStack {
                    Text(item.name)
                        .frame(maxWidth: .infinity,alignment: .center)
                        .font(.system(size: 36, weight: .bold))
                    HStack {
                        VStack {
                            
                        }
                        .frame(maxWidth: .infinity)
                        VStack {
                            
                            HStack {
                                VStack {
                                    Text("Date: ")
                                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                                    Text("File Size: ")
                                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                                }
                                VStack {
                                    if #available(macOS 12.0, *) {
                                        Text("\(item.time?.formatted(date: .abbreviated, time: .shortened) ?? "err")")
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                        
                                    } else {
                                        // Fallback on earlier versions
                                    }
                                    Text("\((item.size)/1024/1024)MiB")
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                            }
                        }
                    }
                    Spacer()
                    HStack{
                        Button("Download") {
                            
                        }
                        Button("Export Preview") {
                            
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: geometry.size.height, alignment: .topLeading)
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 0))
            }
        }
        .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        .onDisappear {
            preview=NSImage()
        }
    }
}


struct MediaItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        try? MediaItemDetailView(thumb: NSImage(), item: MediaItem(_id: BSONObjectID("634491ff273cfa9985098782"), time: Date(timeIntervalSince1970: 1661834242000), name: "IMG_4303.CR3", upload_id: BSONObjectID("634491ff273cfa9985098781"), size: 28410943, upload_complete: true))
    }
}
