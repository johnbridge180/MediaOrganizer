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
    
    private let highResThreshold: CGFloat = 500
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
        if visible.contains(itemId) {
            return isScrollingFast ? 1 : 2
        } else if nearVisible.contains(itemId) {
            return 1
        } else {
            return 0
        }
    }
    
    private func cleanupUnregisteredItems(knownItems: Set<BSONObjectID>) {
        let registeredItems = Set(itemViewModels.keys)
        let itemsToRemove = registeredItems.subtracting(knownItems)
        
        if itemsToRemove.count > 50 {
            for itemId in itemsToRemove {
                if let viewModel = itemViewModels[itemId] {
                    DispatchQueue.main.async {
                        viewModel.setDisplayType(0)
                    }
                }
                itemViewModels.removeValue(forKey: itemId)
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
        
    }
    
    deinit {
        cancellables.removeAll()
    }
}