//
//  ReusablePhotoGridConfiguration.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/28/25.
//

import SwiftUI

struct ReusablePhotoGridConfiguration {
    var idealGridItemSize: Binding<Double>
    var multiSelectEnabled: Binding<Bool>
    var onPhotoTap: ((PhotoGridItem) -> Void)?
    var contextActions: [PhotoGridAction] = []
    var dragSelectEnabled: Bool = false
    var scrollDirection: PhotoGridScrollDirection = .vertical
    var minGridItemSize: Double = 50.0
    var scrollable: Bool = true
    
    init(
        idealGridItemSize: Binding<Double>,
        multiSelectEnabled: Binding<Bool> = .constant(false),
        minGridItemSize: Double = 50.0,
        scrollable: Bool = true,
        scrollDirection: PhotoGridScrollDirection = .vertical,
        dragSelectEnabled: Bool = false,
        onPhotoTap: ((PhotoGridItem) -> Void)? = nil,
        contextActions: [PhotoGridAction] = []
    ) {
        self.idealGridItemSize = idealGridItemSize
        self.multiSelectEnabled = multiSelectEnabled
        self.minGridItemSize = minGridItemSize
        self.scrollable = scrollable
        self.scrollDirection = scrollDirection
        self.dragSelectEnabled = dragSelectEnabled
        self.onPhotoTap = onPhotoTap
        self.contextActions = contextActions
    }
}