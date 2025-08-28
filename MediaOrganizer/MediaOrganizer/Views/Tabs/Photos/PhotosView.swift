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
    @StateObject private var dataSource: MongoPhotoGridDataSource

    init(idealGridItemSize: Binding<Double>, multiSelect: Binding<Bool>, sliderDisabled: Binding<Bool>, minGridItemSize: Double, mongoHolder: MongoClientHolder, appDelegate: AppDelegate) {
        self._idealGridItemSize = idealGridItemSize
        self._multiSelect = multiSelect
        self._sliderDisabled = sliderDisabled
        self.minGridItemSize = minGridItemSize
        self.mongoHolder = mongoHolder
        self.appDelegate = appDelegate
        
        // Initialize with empty API endpoint URL for now - will be updated in onAppear
        self._dataSource = StateObject(wrappedValue: MongoPhotoGridDataSource(
            mongoHolder: mongoHolder,
            filter: [:],
            limit: 0,
            apiEndpointUrl: ""
        ))
    }

    var body: some View {
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
        .onAppear {
            sliderDisabled = false
            // Update data source with correct API endpoint URL if needed
            if dataSource.apiEndpointUrl != apiEndpointUrl {
                let newDataSource = MongoPhotoGridDataSource(
                    mongoHolder: mongoHolder,
                    filter: [:],
                    limit: 0,
                    apiEndpointUrl: apiEndpointUrl
                )
                // Note: SwiftUI will handle the StateObject replacement
            }
        }
    }
}
