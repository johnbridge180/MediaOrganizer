//
//  MediaItemDetailView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/26/22.
//

import SwiftUI
import SwiftBSON

struct MediaItemDetailView: View {
    
    let dateFormatter: DateFormatter
    
    @StateObject var detailVModel: MediaItemDetailViewModel
    
    init(_ item: MediaItem, initialThumb: CGImage? = nil, initialThumbOrientation: Image.Orientation = .up) {
        self.dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        self._detailVModel=StateObject(wrappedValue: MediaItemDetailViewModel(item, initialThumb: initialThumb, initialThumbOrientation: initialThumbOrientation))
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()
                VStack {
                    HStack {
                        VStack {
                            //TODO: cache images on disk before displaying
                            if let cgImage = detailVModel.cgImage {
                                Image(cgImage, scale: 1.0, orientation: detailVModel.orientation, label: Text(detailVModel.item.name))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: geometry.size.height)
                            }
                            HStack {
                                if(detailVModel.downloadProgress<1.0) {
                                    Text("Loading Image")
                                    ProgressView(value: detailVModel.downloadProgress, total:1.0)
                                }
                            }
                        }
                        .onAppear {
                            detailVModel.loadPreview()
                        }
                        VStack {
                            HStack {
                                VStack {
                                    Text("Date:")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("Size:")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("Dimensions:")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("Camera:")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("Shutter Speed:")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("Lens:")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("Focal Length:")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("Aperture:")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .fixedSize()
                                VStack {
                                    Text(dateFormatter.string(from: detailVModel.item.time))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(Tools.getStringFromSize(detailVModel.item.size))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(detailVModel.item.exif_data.width)x\(detailVModel.item.exif_data.height)")
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(detailVModel.item.exif_data.make) \(detailVModel.item.exif_data.model)")
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(detailVModel.item.exif_data.shutter_speed)")
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(detailVModel.item.exif_data.lens)")
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(String(format: "%gmm", detailVModel.item.exif_data.focal_length)).lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(String(format:"ƒ/%g",detailVModel.item.exif_data.aperture))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .fixedSize()
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 5))
                    }
                    HStack {
                        Button() {
                            detailVModel.downloadFile()
                        } label: {
                            if let download = detailVModel.activeDownload {
                                DownloadButtonLabel(activeDownload: download, title: "Download")
                            } else {
                                Text("Download")
                            }
                        }
                        .background(VStack { if let activeDownload = detailVModel.activeDownload {
                            DownloadButtonBackgroundView(activeDownload: activeDownload)
                        } else {
                            Color.clear
                        }})
                        Button() {
                            detailVModel.exportPreview()
                        } label: {
                            if let download = detailVModel.activePreviewExport {
                                DownloadButtonLabel(activeDownload: download, title: "Export Preview")
                            } else {
                                Text("Export Preview")
                            }
                        }
                        .background(
                            VStack { if let activeDownload = detailVModel.activePreviewExport {
                                DownloadButtonBackgroundView(activeDownload: activeDownload)
                            } else {
                                Color.clear
                            }})
                    }
                }
                Spacer()
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .padding(EdgeInsets(top: 5, leading: 5, bottom: 20, trailing: 5))
    }
}

struct DownloadButtonBackgroundView: View {
    //TODO: explore changing to @StateObject (@ObservedObject will need to be reinstantiated if view is redrawn)
    @ObservedObject var activeDownload: DownloadModel
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                Color.blue
                    .frame(width: geometry.size.width*(activeDownload.progress))
                Color.clear
                    .frame(width: geometry.size.width*(1.0-(activeDownload.progress)))
            }
        }
        .cornerRadius(5)
    }
}

struct DownloadButtonLabel: View {
    //TODO: explore changing to @StateObject (@ObservedObject will need to be reinstantiated if view is redrawn)
    @ObservedObject var activeDownload: DownloadModel
    let title: String
    
    var body: some View {
        if activeDownload.completed {
            Label(title, systemImage: "checkmark.circle.fill")
        } else {
            Text(title)
        }
    }
}

struct MediaItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        try? MediaItemDetailView(MediaItem(_id: BSONObjectID("634491ff273cfa9985098782"), time: Date(timeIntervalSince1970: 1661834242000), name: "IMG_4303.CR3", upload_id: BSONObjectID("634491ff273cfa9985098781"), size: 28410943, upload_complete: true, exif_data: ExifData(width: 1, height: 1, make: "Make", model: "Model", shutter_speed: 0.1, iso_speed: 100, lens: "LENS", focal_length: 0.1, aperture: 4.0, flip: 0)), initialThumb: nil)
        EmptyView()
    }
}
