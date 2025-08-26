//
//  ViewportTracker.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/26/25.
//

import SwiftUI
import SwiftBSON

struct VisibleItem: Equatable {
    let id: BSONObjectID
    let frame: CGRect
}

struct VisibleItemsPreference: PreferenceKey {
    static var defaultValue: [VisibleItem] = []
    
    static func reduce(value: inout [VisibleItem], nextValue: () -> [VisibleItem]) {
        value.append(contentsOf: nextValue())
    }
}

enum ViewportPosition {
    case visible
    case nearVisible
    case farOffscreen
}

class ViewportTracker: ObservableObject {
    @Published private(set) var visibleItems: Set<BSONObjectID> = []
    @Published private(set) var nearVisibleItems: Set<BSONObjectID> = []
    @Published private(set) var scrollVelocity: CGFloat = 0
    
    private var lastScrollOffset: CGFloat = 0
    private var lastScrollTime: Date = Date()
    private var scrollVelocityHistory: [CGFloat] = []
    
    func updateVisibleItems(_ items: [VisibleItem], scrollViewFrame: CGRect) {
        let bufferZone: CGFloat = scrollViewFrame.height
        
        var newVisibleItems: Set<BSONObjectID> = []
        var newNearVisibleItems: Set<BSONObjectID> = []
        
        for item in items {
            let itemPosition = getViewportPosition(
                itemFrame: item.frame,
                scrollViewFrame: scrollViewFrame,
                bufferZone: bufferZone
            )
            
            switch itemPosition {
            case .visible:
                newVisibleItems.insert(item.id)
            case .nearVisible:
                newNearVisibleItems.insert(item.id)
            case .farOffscreen:
                break
            }
        }
        
        DispatchQueue.main.async {
            self.visibleItems = newVisibleItems
            self.nearVisibleItems = newNearVisibleItems
        }
    }
    
    func updateScrollVelocity(scrollOffset: CGFloat) {
        let currentTime = Date()
        let timeDelta = currentTime.timeIntervalSince(lastScrollTime)
        
        if timeDelta > 0 {
            let offsetDelta = scrollOffset - lastScrollOffset
            let currentVelocity = abs(offsetDelta / timeDelta)
            
            scrollVelocityHistory.append(currentVelocity)
            if scrollVelocityHistory.count > 10 {
                scrollVelocityHistory.removeFirst()
            }
            
            let smoothedVelocity = scrollVelocityHistory.reduce(0, +) / Double(scrollVelocityHistory.count)
            
            DispatchQueue.main.async {
                self.scrollVelocity = smoothedVelocity
            }
        }
        
        lastScrollOffset = scrollOffset
        lastScrollTime = currentTime
    }
    
    private func getViewportPosition(
        itemFrame: CGRect,
        scrollViewFrame: CGRect,
        bufferZone: CGFloat
    ) -> ViewportPosition {
        let scrollViewTop = scrollViewFrame.minY
        let scrollViewBottom = scrollViewFrame.maxY
        let itemTop = itemFrame.minY
        let itemBottom = itemFrame.maxY
        
        if itemBottom >= scrollViewTop && itemTop <= scrollViewBottom {
            return .visible
        }
        
        let expandedTop = scrollViewTop - bufferZone
        let expandedBottom = scrollViewBottom + bufferZone
        
        if itemBottom >= expandedTop && itemTop <= expandedBottom {
            return .nearVisible
        }
        
        return .farOffscreen
    }
    
    func getPositionFor(itemId: BSONObjectID) -> ViewportPosition {
        if visibleItems.contains(itemId) {
            return .visible
        } else if nearVisibleItems.contains(itemId) {
            return .nearVisible
        } else {
            return .farOffscreen
        }
    }
}