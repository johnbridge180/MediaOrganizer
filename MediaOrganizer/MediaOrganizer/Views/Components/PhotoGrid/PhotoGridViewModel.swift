//
//  PhotoGridViewModel.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/5/23.
//

import Foundation
import SwiftUI
import SwiftBSON

class PhotoGridViewModel: ObservableObject {

    let minGridItemSize: Double

    var mediaVModel: MediaItemsViewModel

    var offsets: [BSONObjectID: CGSize] = [:]
    var photoWidth: CGFloat = 0.0
    var zstackHeight: CGFloat = 0.0
    var numCols: Int = 0
    
    private var lastItemCount: Int = 0
    private var lastWidth: CGFloat = 0
    private var lastIdealSize: Double = 0

    init(minGridItemSize: Double, mediaViewModel: MediaItemsViewModel) {
        self.minGridItemSize = minGridItemSize
        self.mediaVModel = mediaViewModel
    }

    func setOffsets(width: CGFloat, idealGridItemSize: Double) {
        let numCols = self.getNumColumns(width: width, idealGridItemSize: idealGridItemSize)
        let photoWidth = self.getColWidth(width: width, numCols: numCols)
        
        let currentItemCount = mediaVModel.itemOrder.count
        let canDoIncrementalUpdate = (width == lastWidth && 
                                     idealGridItemSize == lastIdealSize && 
                                     currentItemCount > lastItemCount &&
                                     lastItemCount > 0)
        
        if canDoIncrementalUpdate {
            for i in lastItemCount..<currentItemCount {
                offsets[mediaVModel.itemOrder[i]] = self.getOffset(for: i, width: width, numCols: numCols, colWidth: photoWidth)
            }
        } else {
            let currentItemSet = Set(mediaVModel.itemOrder)
            offsets = offsets.filter { currentItemSet.contains($0.key) }
            for i in 0..<currentItemCount {
                offsets[mediaVModel.itemOrder[i]] = self.getOffset(for: i, width: width, numCols: numCols, colWidth: photoWidth)
            }
        }
        
        self.numCols = numCols
        self.photoWidth = photoWidth
        self.zstackHeight = photoWidth*CGFloat(self.getNumRows(width: width, idealGridItemSize: idealGridItemSize, numCols: numCols))

        lastItemCount = currentItemCount
        lastWidth = width
        lastIdealSize = idealGridItemSize
        self.objectWillChange.send()
    }

    func getOffset(for index: Int, width: CGFloat, numCols: Int, colWidth: CGFloat) -> CGSize {
        return CGSize(width: CGFloat(index%numCols)*colWidth, height: CGFloat(index/numCols)*colWidth)
    }

    func getPhotosInRectangle(_ rect: (x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)) -> [BSONObjectID] {
        var photos: [BSONObjectID] = []

        var startRow = Int(rect.y1 / photoWidth)
        var endRow = Int(rect.y2 / photoWidth)
        var startCol = Int(rect.x1 / photoWidth)
        var endCol = Int(rect.x2 / photoWidth)

        if startCol >= numCols { startCol = numCols-1} else if startCol<0 { startCol = 0 }
        if endCol >= numCols { endCol = numCols-1 } else if endCol<0 { endCol = 0 }

        var i = startRow*numCols
        while i <= endRow*numCols && i <= mediaVModel.itemOrder.count {
            var k=startCol
            while k<=endCol {
                if i+k >= mediaVModel.itemOrder.count {
                    break
                }
                photos.append(mediaVModel.itemOrder[i+k])
                k += 1
            }
            i+=numCols
        }
        return photos
    }

    func getColWidth(width: CGFloat, numCols: Int) -> CGFloat {
        if numCols==0 {
            return 0
        }
        return width/CGFloat(numCols)
    }
    func getNumRows(width: CGFloat, idealGridItemSize: Double, numCols: Int) -> Int {
        if mediaVModel.itemOrder.isEmpty || width==0 || numCols==0 {
            return 0
        }
        return Int(ceil((Double(mediaVModel.itemOrder.count)/Double(numCols))))
    }
    func getNumColumns(width: CGFloat, idealGridItemSize: Double) -> Int {
        if idealGridItemSize==0 {
            return 0
        }
        return Int(floor(width/idealGridItemSize))
    }
}
