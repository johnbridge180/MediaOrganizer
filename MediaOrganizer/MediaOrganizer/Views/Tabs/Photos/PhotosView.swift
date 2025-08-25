//
//  PhotosView.swift
//  MediaOrganizer
//
//  Created by reorganization on 8/25/25.
//

import SwiftUI

struct PhotosView: View {
    @Binding var idealGridItemSize: Double
    @Binding var multi_select: Bool
    @Binding var slider_disabled: Bool
    let minGridItemSize: Double
    let mongo_holder: MongoClientHolder
    let appDelegate: AppDelegate
    
    var body: some View {
        PhotoGridView(idealGridItemSize: $idealGridItemSize, multi_select: $multi_select, minGridItemSize: minGridItemSize, mongo_holder: mongo_holder, appDelegate: appDelegate, filter: [:])
            .onAppear {
                slider_disabled = false
            }
    }
}