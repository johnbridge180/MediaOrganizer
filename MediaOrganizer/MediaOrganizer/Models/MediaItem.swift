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
    let shutterSpeed: Double
    let isoSpeed: Double
    let lens: String
    let focalLength: Double
    let aperture: Double
    let flip: Int
}

struct MediaItem: Codable, Hashable {
    let _id: BSONObjectID
    let time: Date
    let name: String
    let uploadId: BSONObjectID
    let size: Int64
    let uploadComplete: Bool
    let exifData: ExifData

    func getDisplayDimensions() -> (width: Int, height: Int) {
        if self.exifData.flip >= 5 {
            return (width: self.exifData.height, height: self.exifData.width)
        }
        return (width: self.exifData.width, height: self.exifData.height)
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
    let cacheRow: PreviewCache?
    var view: ThumbnailView
}
