//
//  Tools.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/7/23.
//

import Foundation
import SwiftUI

class Tools {
    static func translateExifOrientationToImageOrientation(_ exifOrientationValue: UInt8) -> Image.Orientation? {
        var orientation: Image.Orientation = .up
        switch exifOrientationValue {
        case 2:
            orientation = .upMirrored
            case 3:
            orientation = .down
            case 4:
            orientation = .downMirrored
            case 5:
            orientation = .leftMirrored
            case 6:
            orientation = .right
            case 7:
            orientation = .rightMirrored
            case 8:
            orientation = .left
        default:
            orientation = .up
        }
        return orientation
    }
    static func getStringFromSize(_ size: Int64) -> String {
        return "\(size/1024/1024)MiB"
    }
}
