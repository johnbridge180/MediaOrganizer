//
//  PhotoGridItem.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/28/25.
//

import Foundation

struct PhotoGridItem: Identifiable, Hashable {
    let id: String
    let imageURL: URL
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PhotoGridItem, rhs: PhotoGridItem) -> Bool {
        lhs.id == rhs.id
    }
}