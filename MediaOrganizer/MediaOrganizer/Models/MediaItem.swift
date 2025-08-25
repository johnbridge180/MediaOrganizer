//
//  MediaItem.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/7/23.
//

import Foundation
import SwiftBSON

struct ExifData: Codable, Hashable {
    let width: Int
    let height: Int
    let make: String
    let model: String
    let shutter_speed: Double
    let iso_speed: Double
    let lens: String
    let focal_length: Double
    let aperture: Double
    let flip: Int
}

struct MediaItem: Codable, Hashable {
    let _id: BSONObjectID
    let time: Date
    let name: String
    let upload_id: BSONObjectID
    let size: Int64
    let upload_complete: Bool
    let exif_data: ExifData
    
    func getDisplayDimensions() -> (width: Int, height: Int) {
        if self.exif_data.flip >= 5 {
            return (width: self.exif_data.height, height: self.exif_data.width)
        }
        return (width: self.exif_data.width, height: self.exif_data.height)
    }
}

struct MediaItemHolder: Hashable, Identifiable {
    var id: String {
        return item._id.hex
    }
    
    static func == (lhs: MediaItemHolder, rhs: MediaItemHolder) -> Bool {
        return lhs.item._id.hex==rhs.item._id.hex
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(item._id.hex)
    }
    let item: MediaItem
    let cache_row: PreviewCache?
    var view: MediaThumbView
}
