//
//  ThumbnailQualityManager.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/26/25.
//

import SwiftUI
import SwiftBSON
import Combine

class ThumbnailQualityManager: ObservableObject {
    private let viewportTracker: ViewportTracker
    private var cancellables = Set<AnyCancellable>()
    private var qualityUpdateQueue = DispatchQueue(label: "com.mediaorganizer.qualityUpdate", qos: .userInitiated)
    
    private var itemViewModels: [BSONObjectID: ThumbnailViewModel] = [:]
    private var lastQualityUpdate: Date = Date()
    
    private var highResThreshold: CGFloat = 500
    private let qualityUpdateThrottle: TimeInterval = 0.1
    
    init(viewportTracker: ViewportTracker) {
        self.viewportTracker = viewportTracker
        setupObservers()
    }
    
    private func setupObservers() {
        Publishers.CombineLatest3(
            viewportTracker.$visibleItems,
            viewportTracker.$nearVisibleItems,
            viewportTracker.$scrollVelocity
        )
        .debounce(for: .seconds(qualityUpdateThrottle), scheduler: qualityUpdateQueue)
        .sink { [weak self] visibleItems, nearVisibleItems, scrollVelocity in
            self?.updateThumbnailQualities(
                visible: visibleItems,
                nearVisible: nearVisibleItems,
                scrollVelocity: scrollVelocity
            )
        }
        .store(in: &cancellables)
    }
    
    func registerItem(_ itemId: BSONObjectID, viewModel: ThumbnailViewModel) {
        itemViewModels[itemId] = viewModel
    }
    
    func unregisterItem(_ itemId: BSONObjectID) {
        itemViewModels.removeValue(forKey: itemId)
    }
    
    private func updateThumbnailQualities(
        visible: Set<BSONObjectID>,
        nearVisible: Set<BSONObjectID>,
        scrollVelocity: CGFloat
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastQualityUpdate) > qualityUpdateThrottle else { return }
        lastQualityUpdate = now
        
        let isScrollingFast = scrollVelocity > highResThreshold
        
        let allTrackedItems = Set(itemViewModels.keys)
        let allKnownItems = visible.union(nearVisible)
        
        for itemId in allTrackedItems {
            guard let viewModel = itemViewModels[itemId] else { continue }
            
            let targetQuality = calculateQuality(
                itemId: itemId,
                visible: visible,
                nearVisible: nearVisible,
                isScrollingFast: isScrollingFast
            )
            
            DispatchQueue.main.async {
                viewModel.setDisplayType(targetQuality)
            }
        }
        
        cleanupUnregisteredItems(knownItems: allKnownItems)
    }
    
    private func calculateQuality(
        itemId: BSONObjectID,
        visible: Set<BSONObjectID>,
        nearVisible: Set<BSONObjectID>,
        isScrollingFast: Bool
    ) -> Int {
        return updateItemQuality(itemId, visible: visible, nearVisible: nearVisible, scrollVelocity: viewportTracker.scrollVelocity)
    }
    
    private func updateItemQuality(_ itemID: BSONObjectID, visible: Set<BSONObjectID>, nearVisible: Set<BSONObjectID>, scrollVelocity: CGFloat) -> Int {
        let position: ViewportPosition
        if visible.contains(itemID) {
            position = .visible
        } else if nearVisible.contains(itemID) {
            position = .nearVisible
        } else {
            position = .farOffscreen
        }
        
        let targetQuality: Int
        
        switch (position, scrollVelocity) {
        case (.visible, let velocity) where velocity < 500:
            targetQuality = 2
        case (.visible, _):
            targetQuality = 1
        case (.nearVisible, _):
            targetQuality = 1
        case (.farOffscreen, _):
            targetQuality = 0
        }
        
        return targetQuality
    }
    
    private enum ViewportPosition {
        case visible
        case nearVisible
        case farOffscreen
    }
    
    private func cleanupUnregisteredItems(knownItems: Set<BSONObjectID>) {
        let registeredItems = Set(itemViewModels.keys)
        let itemsToRemove = registeredItems.subtracting(knownItems)
        
        aggressiveMemoryCleanup(itemsToRemove: itemsToRemove, knownItems: knownItems)
    }
    
    private func aggressiveMemoryCleanup(itemsToRemove: Set<BSONObjectID>, knownItems: Set<BSONObjectID>) {
        let memoryPressureThreshold = 20
        let farOffscreenThreshold = 100
        
        if itemsToRemove.count > memoryPressureThreshold {
            for itemId in itemsToRemove {
                if let viewModel = itemViewModels[itemId] {
                    DispatchQueue.main.async {
                        viewModel.setDisplayType(0)
                    }
                }
                itemViewModels.removeValue(forKey: itemId)
            }
        }
        
        if itemViewModels.count > farOffscreenThreshold {
            let currentVisible = viewportTracker.visibleItems
            let currentNearVisible = viewportTracker.nearVisibleItems
            let currentlyRelevant = currentVisible.union(currentNearVisible)
            
            let candidatesForDowngrade = Set(itemViewModels.keys).subtracting(currentlyRelevant).subtracting(knownItems)
            
            for itemId in candidatesForDowngrade {
                if let viewModel = itemViewModels[itemId] {
                    DispatchQueue.main.async {
                        viewModel.setDisplayType(0)
                    }
                }
            }
        }
    }
    
    func forceQualityUpdate() {
        updateThumbnailQualities(
            visible: viewportTracker.visibleItems,
            nearVisible: viewportTracker.nearVisibleItems,
            scrollVelocity: viewportTracker.scrollVelocity
        )
    }
    
    func setScrollVelocityThreshold(_ threshold: CGFloat) {
        highResThreshold = threshold
    }
    
    deinit {
        cancellables.removeAll()
    }
}
