//
//  Grid.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/5/23.
//

import Foundation
import SwiftUI
import SwiftBSON

class GridViewModel: ObservableObject {
    
    let minGridItemSize: Double
    
    var mediaVModel: MediaItemsViewModel
    
    var offsets: [BSONObjectID:CGSize] = [:]
    var photo_width: CGFloat = 0.0
    var zstack_height: CGFloat = 0.0
    var numCols: Int = 0
    
    init(minGridItemSize: Double, mediaViewModel: MediaItemsViewModel) {
        self.minGridItemSize=minGridItemSize
        self.mediaVModel=mediaViewModel
    }
    
    func setOffsets(width: CGFloat, idealGridItemSize: Double) {
        let numCols = self.getNumColumns(width: width, idealGridItemSize: idealGridItemSize)
        let photo_width = self.getColWidth(width: width, numCols: numCols)
            self.offsets=[:]
            self.numCols = numCols
            self.photo_width = photo_width
            for i in 0..<self.mediaVModel.item_order.count {
                print("i: \(i)")
                offsets[mediaVModel.item_order[i]]=self.getOffset(for: i, width: width, numCols: numCols, colWidth: photo_width)
            }
            self.zstack_height = photo_width*CGFloat(self.getNumRows(width: width, idealGridItemSize: idealGridItemSize, numCols: numCols))
            self.objectWillChange.send()
    }
    
    func getOffset(for index: Int, width: CGFloat, numCols: Int, colWidth: CGFloat) -> CGSize {
        return CGSize(width: CGFloat(index%numCols)*colWidth, height: CGFloat(index/numCols)*colWidth)
    }
    
    func getColWidth(width: CGFloat, numCols: Int) -> CGFloat {
        if(numCols==0) {
            return 0
        }
        return width/CGFloat(numCols)
    }
    func getNumRows(width: CGFloat, idealGridItemSize: Double, numCols: Int) -> Int {
        if(mediaVModel.item_order.count==0 || width==0 || numCols==0) {
            return 0
        }
        return Int(ceil((Double(mediaVModel.item_order.count)/Double(numCols))))
    }
    func getNumColumns(width: CGFloat, idealGridItemSize: Double) -> Int {
        if(idealGridItemSize==0) {
            return 0
        }
        return Int(floor(width/idealGridItemSize))
    }
}
