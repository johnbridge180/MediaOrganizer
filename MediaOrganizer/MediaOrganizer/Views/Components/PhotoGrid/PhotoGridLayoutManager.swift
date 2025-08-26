//
//  PhotoGridLayoutManager.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/26/25.
//

import SwiftUI
import SwiftBSON

struct GridRow: Identifiable {
    let id: UUID = UUID()
    let items: [BSONObjectID]
    let targetHeight: CGFloat
    let itemWidths: [BSONObjectID: CGFloat]
}

class PhotoGridLayoutManager: ObservableObject {
    @Published private(set) var gridRows: [GridRow] = []
    
    private let minItemWidth: CGFloat = 100
    private let maxItemWidth: CGFloat = 300
    private let targetRowHeight: CGFloat = 200
    private let spacing: CGFloat = 1
    
    func calculateLayout(
        items: [BSONObjectID: MediaItemHolder],
        itemOrder: [BSONObjectID],
        containerWidth: CGFloat
    ) {
        guard !itemOrder.isEmpty && containerWidth > 0 else {
            gridRows = []
            return
        }
        
        let availableWidth = containerWidth - (spacing * 2)
        var rows: [GridRow] = []
        var currentRowItems: [BSONObjectID] = []
        var currentRowWidthSum: CGFloat = 0
        
        for itemId in itemOrder {
            guard let mediaItem = items[itemId] else { continue }
            
            let dimensions = mediaItem.item.getDisplayDimensions()
            let naturalAspectRatio = max(0.5, min(2.0, Double(dimensions.width) / Double(dimensions.height)))
            let naturalWidth = targetRowHeight * naturalAspectRatio
            
            let projectedRowWidth = currentRowWidthSum + naturalWidth + (currentRowItems.isEmpty ? 0 : spacing)
            
            if projectedRowWidth <= availableWidth || currentRowItems.isEmpty {
                currentRowItems.append(itemId)
                currentRowWidthSum += naturalWidth + (currentRowItems.count > 1 ? spacing : 0)
            } else {
                if !currentRowItems.isEmpty {
                    let row = createRow(
                        items: currentRowItems,
                        mediaItems: items,
                        availableWidth: availableWidth,
                        naturalWidthSum: currentRowWidthSum
                    )
                    rows.append(row)
                }
                
                currentRowItems = [itemId]
                currentRowWidthSum = naturalWidth
            }
        }
        
        if !currentRowItems.isEmpty {
            let row = createRow(
                items: currentRowItems,
                mediaItems: items,
                availableWidth: availableWidth,
                naturalWidthSum: currentRowWidthSum
            )
            rows.append(row)
        }
        
        DispatchQueue.main.async {
            self.gridRows = rows
        }
    }
    
    private func createRow(
        items: [BSONObjectID],
        mediaItems: [BSONObjectID: MediaItemHolder],
        availableWidth: CGFloat,
        naturalWidthSum: CGFloat
    ) -> GridRow {
        let spacingTotal = CGFloat(max(0, items.count - 1)) * spacing
        let availableForItems = availableWidth - spacingTotal
        
        let scaleFactor: CGFloat
        if naturalWidthSum > availableForItems {
            scaleFactor = availableForItems / naturalWidthSum
        } else {
            scaleFactor = 1.0
        }
        
        var itemWidths: [BSONObjectID: CGFloat] = [:]
        var actualRowHeight = targetRowHeight * scaleFactor
        
        actualRowHeight = max(120, min(250, actualRowHeight))
        let finalScaleFactor = actualRowHeight / targetRowHeight
        
        for itemId in items {
            guard let mediaItem = mediaItems[itemId] else { continue }
            
            let dimensions = mediaItem.item.getDisplayDimensions()
            let aspectRatio = max(0.5, min(2.0, Double(dimensions.width) / Double(dimensions.height)))
            let itemWidth = actualRowHeight * aspectRatio
            
            let clampedWidth = max(minItemWidth, min(maxItemWidth, itemWidth))
            itemWidths[itemId] = clampedWidth
        }
        
        return GridRow(
            items: items,
            targetHeight: actualRowHeight,
            itemWidths: itemWidths
        )
    }
    
    func getItemWidth(itemId: BSONObjectID) -> CGFloat {
        for row in gridRows {
            if let width = row.itemWidths[itemId] {
                return width
            }
        }
        return minItemWidth
    }
    
    func getRowHeight(for itemId: BSONObjectID) -> CGFloat {
        for row in gridRows {
            if row.items.contains(itemId) {
                return row.targetHeight
            }
        }
        return targetRowHeight
    }
}
