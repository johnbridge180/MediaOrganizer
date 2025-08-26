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

    var body: some View {
        PhotoGridView(idealGridItemSize: $idealGridItemSize, multiSelect: $multiSelect, minGridItemSize: minGridItemSize, mongoHolder: mongoHolder, appDelegate: appDelegate, filter: [:])
            .onAppear {
                sliderDisabled = false
            }
    }
}
