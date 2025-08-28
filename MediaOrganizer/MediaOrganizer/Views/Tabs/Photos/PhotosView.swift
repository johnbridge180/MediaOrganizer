//
//  PhotosView.swift
//  MediaOrganizer
//
//  Created by reorganization on 8/25/25.
//

import SwiftUI

struct PhotosView: View {
    @Binding var idealGridItemSize: Double
    @Binding var multiSelect: Bool
    @Binding var sliderDisabled: Bool
    let minGridItemSize: Double
    let mongoHolder: MongoClientHolder
    let appDelegate: AppDelegate
    
    @AppStorage("api_endpoint_url") private var apiEndpointUrl: String = ""
    @State private var dataSource: MongoPhotoGridDataSource?

    init(idealGridItemSize: Binding<Double>, multiSelect: Binding<Bool>, sliderDisabled: Binding<Bool>, minGridItemSize: Double, mongoHolder: MongoClientHolder, appDelegate: AppDelegate) {
        self._idealGridItemSize = idealGridItemSize
        self._multiSelect = multiSelect
        self._sliderDisabled = sliderDisabled
        self.minGridItemSize = minGridItemSize
        self.mongoHolder = mongoHolder
        self.appDelegate = appDelegate
    }

    var body: some View {
        Group {
            if let dataSource = dataSource {
                ReusablePhotoGrid(
                    dataSource: dataSource,
                    idealGridItemSize: $idealGridItemSize,
                    multiSelectEnabled: $multiSelect,
                    minGridItemSize: minGridItemSize,
                    dragSelectEnabled: true,
                    onPhotoTap: { item in
                        if let mediaItem = dataSource.getMediaItem(for: item.id) {
                            appDelegate.openMediaItemDetailWindow(
                                rect: CGRect(x: 0, y: 0, width: 1500, height: 1000),
                                item: mediaItem,
                                initialThumb: nil,
                                orientation: .up
                            )
                        }
                    },
                    contextActions: [
                        PhotoGridAction(title: "Download") { items in
                            for item in items {
                                if let mediaItem = dataSource.getMediaItem(for: item.id) {
                                    DownloadManager.shared.download(mediaItem)
                                }
                            }
                        }
                    ]
                )
            } else {
                ProgressView()
            }
        }
        .onAppear {
            sliderDisabled = false
            if dataSource == nil || dataSource?.apiEndpointUrl != apiEndpointUrl {
                dataSource = MongoPhotoGridDataSource(
                    mongoHolder: mongoHolder,
                    filter: [:],
                    limit: 0,
                    apiEndpointUrl: apiEndpointUrl
                )
            }
        }
    }
}
