//
//  ReusablePhotoGridViewModel.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/28/25.
//

import Foundation
import SwiftUI

class ReusablePhotoGridViewModel: ObservableObject {
    let minGridItemSize: Double
    
    var offsets: [String: CGSize] = [:]
    var photoWidth: CGFloat = 0.0
    var zstackHeight: CGFloat = 0.0
    var numCols: Int = 0
    
    private var lastItemCount: Int = 0
    private var lastWidth: CGFloat = 0
    private var lastIdealSize: Double = 0
    
    init(minGridItemSize: Double) {
        self.minGridItemSize = minGridItemSize
    }
    
    func setOffsets(items: [PhotoGridItem], width: CGFloat, idealGridItemSize: Double) {
        let numCols = self.getNumColumns(width: width, idealGridItemSize: idealGridItemSize)
        let photoWidth = self.getColWidth(width: width, numCols: numCols)
        
        let currentItemCount = items.count
        let canDoIncrementalUpdate = (width == lastWidth &&
                                     idealGridItemSize == lastIdealSize &&
                                     currentItemCount > lastItemCount &&
                                     lastItemCount > 0)
        
        if canDoIncrementalUpdate {
            for i in lastItemCount..<currentItemCount {
                offsets[items[i].id] = self.getOffset(for: i, width: width, numCols: numCols, colWidth: photoWidth)
            }
        } else {
            let currentItemSet = Set(items.map { $0.id })
            offsets = offsets.filter { currentItemSet.contains($0.key) }
            for i in 0..<currentItemCount {
                offsets[items[i].id] = self.getOffset(for: i, width: width, numCols: numCols, colWidth: photoWidth)
            }
        }
        
        self.numCols = numCols
        self.photoWidth = photoWidth
        self.zstackHeight = photoWidth * CGFloat(self.getNumRows(items: items, width: width, idealGridItemSize: idealGridItemSize, numCols: numCols))
        
        lastItemCount = currentItemCount
        lastWidth = width
        lastIdealSize = idealGridItemSize
        self.objectWillChange.send()
    }
    
    func getOffset(for index: Int, width: CGFloat, numCols: Int, colWidth: CGFloat) -> CGSize {
        return CGSize(width: CGFloat(index % numCols) * colWidth, height: CGFloat(index / numCols) * colWidth)
    }
    
    func getPhotosInRectangle(_ rect: (x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat), items: [PhotoGridItem]) -> [String] {
        var photoIds: [String] = []
        
        var startRow = Int(rect.y1 / photoWidth)
        var endRow = Int(rect.y2 / photoWidth)
        var startCol = Int(rect.x1 / photoWidth)
        var endCol = Int(rect.x2 / photoWidth)
        
        if startCol >= numCols { startCol = numCols - 1 } else if startCol < 0 { startCol = 0 }
        if endCol >= numCols { endCol = numCols - 1 } else if endCol < 0 { endCol = 0 }
        
        var i = startRow * numCols
        while i <= endRow * numCols && i <= items.count {
            var k = startCol
            while k <= endCol {
                if i + k >= items.count {
                    break
                }
                photoIds.append(items[i + k].id)
                k += 1
            }
            i += numCols
        }
        return photoIds
    }
    
    func getColWidth(width: CGFloat, numCols: Int) -> CGFloat {
        if numCols == 0 {
            return 0
        }
        return width / CGFloat(numCols)
    }
    
    func getNumRows(items: [PhotoGridItem], width: CGFloat, idealGridItemSize: Double, numCols: Int) -> Int {
        if items.isEmpty || width == 0 || numCols == 0 {
            return 0
        }
        return Int(ceil(Double(items.count) / Double(numCols)))
    }
    
    func getNumColumns(width: CGFloat, idealGridItemSize: Double) -> Int {
        if idealGridItemSize == 0 {
            return 0
        }
        return Int(floor(width / idealGridItemSize))
    }
}
