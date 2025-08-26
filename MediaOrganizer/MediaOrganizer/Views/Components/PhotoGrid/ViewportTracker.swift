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
    @Published private(set) var scrollDirection: ScrollDirection = .none
    @Published private(set) var predictiveItems: Set<BSONObjectID> = []
    
    private var lastScrollOffset: CGFloat = 0
    private var lastScrollTime: Date = Date()
    private var scrollVelocityHistory: [CGFloat] = []
    private var scrollDirectionHistory: [ScrollDirection] = []
    
    enum ScrollDirection {
        case up, down, none
    }
    
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
        
        let newPredictiveItems = calculatePredictiveItems(items, scrollViewFrame: scrollViewFrame)
        
        DispatchQueue.main.async {
            self.visibleItems = newVisibleItems
            self.nearVisibleItems = newNearVisibleItems
            self.predictiveItems = newPredictiveItems
        }
    }
    
    func updateScrollVelocity(scrollOffset: CGFloat) {
        let currentTime = Date()
        let timeDelta = currentTime.timeIntervalSince(lastScrollTime)
        
        if timeDelta > 0 {
            let offsetDelta = scrollOffset - lastScrollOffset
            let currentVelocity = abs(offsetDelta / timeDelta)
            
            let currentDirection: ScrollDirection
            if abs(offsetDelta) < 5 {
                currentDirection = .none
            } else if offsetDelta > 0 {
                currentDirection = .down
            } else {
                currentDirection = .up
            }
            
            scrollVelocityHistory.append(currentVelocity)
            scrollDirectionHistory.append(currentDirection)
            
            if scrollVelocityHistory.count > 10 {
                scrollVelocityHistory.removeFirst()
                scrollDirectionHistory.removeFirst()
            }
            
            let smoothedVelocity = scrollVelocityHistory.reduce(0, +) / Double(scrollVelocityHistory.count)
            let dominantDirection = getDominantScrollDirection()
            
            DispatchQueue.main.async {
                self.scrollVelocity = smoothedVelocity
                self.scrollDirection = dominantDirection
            }
        }
        
        lastScrollOffset = scrollOffset
        lastScrollTime = currentTime
    }
    
    private func getDominantScrollDirection() -> ScrollDirection {
        let directionCounts = scrollDirectionHistory.reduce(into: [ScrollDirection: Int]()) { counts, direction in
            counts[direction, default: 0] += 1
        }
        
        let sortedDirections = directionCounts.sorted { $0.value > $1.value }
        return sortedDirections.first?.key ?? .none
    }
    
    private func calculatePredictiveItems(_ items: [VisibleItem], scrollViewFrame: CGRect) -> Set<BSONObjectID> {
        guard scrollDirection != .none && scrollVelocity > 100 else {
            return []
        }
        
        let predictiveBufferZone = scrollViewFrame.height * 1.5
        var predictiveItems: Set<BSONObjectID> = []
        
        for item in items {
            let isPredictiveCandidate: Bool
            
            switch scrollDirection {
            case .down:
                let predictiveZoneTop = scrollViewFrame.maxY
                let predictiveZoneBottom = scrollViewFrame.maxY + predictiveBufferZone
                isPredictiveCandidate = item.frame.minY >= predictiveZoneTop && item.frame.minY <= predictiveZoneBottom
                
            case .up:
                let predictiveZoneTop = scrollViewFrame.minY - predictiveBufferZone
                let predictiveZoneBottom = scrollViewFrame.minY
                isPredictiveCandidate = item.frame.maxY >= predictiveZoneTop && item.frame.maxY <= predictiveZoneBottom
                
            case .none:
                isPredictiveCandidate = false
            }
            
            if isPredictiveCandidate {
                predictiveItems.insert(item.id)
            }
        }
        
        return predictiveItems
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
