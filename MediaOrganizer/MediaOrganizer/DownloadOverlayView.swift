//
//  DownloadOverlayView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/7/23.
//

import SwiftUI

struct DownloadOverlayView: View {
    let downloadOverlayQueue: DispatchQueue = DispatchQueue(label: "com.jbridge.downloadOverlayQueue")
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @ObservedObject var downloadManager = DownloadManager.shared
    
    var body: some View {
        ScrollView {
            VStack {
                if(downloadManager.downloads.count>0) {
                    ForEach(downloadManager.downloads.reversed(), id: \.downloadTask.taskIdentifier) { download in
                        DownloadItemView(download: download, downloadOverlayQueue: downloadOverlayQueue, appDelegate: appDelegate)
                    }
                } else {
                    Spacer()
                    Text("Downloading files appear here after they are queued")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 15))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
    }
}

struct DownloadItemView: View {
    @ObservedObject var download: DownloadModel
    let downloadOverlayQueue: DispatchQueue
    let appDelegate: AppDelegate
    
    var body: some View {
        HStack {
            let thumbViewModel = ThumbViewModel(download.item, cache_row: download.cache_row, makeCGImageQueue: downloadOverlayQueue)
            let thumbView = MediaThumbView(appDelegate: appDelegate, thumbVModel: thumbViewModel)
            thumbView
                .frame(maxWidth: 75, maxHeight: 75)
                .onAppear {
                    thumbViewModel.setDisplayType(1)
                }
            VStack {
                Text(download.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !download.completed {
                    ProgressView(value: download.progress, total: 1.0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("\(Tools.getStringFromSize(download.bytesWritten)) of \(Tools.getStringFromSize(download.totalBytes))")
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if download.completed {
                Spacer()
                Button {
                    if let disk_location = download.disk_location {
                        NSWorkspace.shared.activateFileViewerSelecting([disk_location])
                    }
                } label: {
                    Label("Find", systemImage: "magnifyingglass.circle.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(height: 75.0)
    }
}

struct DownloadOverlayView_Previews: PreviewProvider {
    
    static var previews: some View {
        DownloadOverlayView()
    }
}
