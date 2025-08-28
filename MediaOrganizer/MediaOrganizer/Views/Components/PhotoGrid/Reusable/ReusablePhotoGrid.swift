//
//  ReusablePhotoGrid.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/28/25.
//

import SwiftUI

enum PhotoGridScrollDirection {
    case vertical
    case horizontal
}

struct ReusablePhotoGrid<DataSource: PhotoGridDataSource>: View {
    @ObservedObject var dataSource: DataSource
    @StateObject private var gridViewModel: ReusablePhotoGridViewModel
    
    // Configuration properties
    @State private var idealGridItemSize: Double = 100
    @State private var multiSelectEnabled: Bool = false
    private let minGridItemSize: Double
    private let scrollable: Bool
    private let scrollDirection: PhotoGridScrollDirection
    
    // Callbacks
    private var onPhotoTap: ((PhotoGridItem) -> Void)?
    private var contextActions: [PhotoGridAction] = []
    private var dragSelectEnabled: Bool = false
    
    // Selection state
    @State private var selected: [String: Bool] = [:]
    
    // Drag state
    @State private var dragging: Bool = false
    @State private var dragStart: CGPoint = CGPoint()
    @State private var dragEnd: CGPoint = CGPoint()
    
    init(dataSource: DataSource, minGridItemSize: Double = 50.0, scrollable: Bool = true, scrollDirection: PhotoGridScrollDirection = .vertical) {
        self.dataSource = dataSource
        self.minGridItemSize = minGridItemSize
        self.scrollable = scrollable
        self.scrollDirection = scrollDirection
        self._gridViewModel = StateObject(wrappedValue: ReusablePhotoGridViewModel(minGridItemSize: minGridItemSize))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let grid = ZStack(alignment: .topLeading) {
                Rectangle()
                    .frame(
                        width: scrollDirection == .horizontal ? CGFloat(dataSource.items.count) * idealGridItemSize : geometry.size.width,
                        height: scrollDirection == .horizontal ? idealGridItemSize : gridViewModel.zstackHeight
                    )
                    .opacity(0)
                
                ForEach(dataSource.items) { item in
                    ZStack {
                        ReusableThumbnailView(
                            item: item,
                            size: CGSize(width: gridViewModel.photoWidth, height: gridViewModel.photoWidth),
                            onTap: { item in
                                onPhotoTap?(item)
                            }
                        )
                        
                        if multiSelectEnabled {
                            Button {
                                handleItemSelection(for: item.id)
                            } label: {
                                Image(systemName: selected[item.id] ?? false ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: gridViewModel.photoWidth > 100 ? 24 : gridViewModel.photoWidth / 4))
                                    .padding()
                                    .frame(width: gridViewModel.photoWidth, height: gridViewModel.photoWidth)
                            }
                            .buttonStyle(SelectionButtonStyle(selected: selected[item.id] ?? false))
                            .foregroundColor(Color.white)
                        }
                    }
                    .frame(width: gridViewModel.photoWidth, height: gridViewModel.photoWidth)
                    .offset(gridViewModel.offsets[item.id] ?? CGSize())
                    .contextMenu {
                        if !contextActions.isEmpty {
                            let selectedItems = getSelectedItems()
                            ForEach(contextActions.indices, id: \.self) { index in
                                let action = contextActions[index]
                                Button(action.title) {
                                    let itemsToProcess = selectedItems.isEmpty ? [item] : selectedItems
                                    action.handler(itemsToProcess)
                                }
                            }
                        }
                    }
                }
                
                if dragging && dragSelectEnabled && scrollDirection == .vertical {
                    Rectangle()
                        .fill(Color.blue.opacity(0.25))
                        .border(.blue)
                        .frame(width: abs(dragEnd.x - dragStart.x), height: abs(dragEnd.y - dragStart.y))
                        .offset(
                            x: dragEnd.x > dragStart.x ? dragStart.x : dragEnd.x,
                            y: dragEnd.y > dragStart.y ? dragStart.y : dragEnd.y
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragSelectEnabled {
                            dragging = true
                            dragStart = value.startLocation
                            dragEnd = value.location
                        }
                    }
                    .onEnded { _ in
                        if dragSelectEnabled {
                            handleDragSelection()
                            dragging = false
                            dragStart = CGPoint()
                            dragEnd = CGPoint()
                        }
                    }
            )
            
            VStack {
                if scrollable {
                    ScrollView(scrollDirection == .horizontal ? .horizontal : .vertical, showsIndicators: true) {
                        grid
                    }
                } else {
                    grid
                }
            }
            .onChange(of: multiSelectEnabled) { newValue in
                if !newValue {
                    selected = [:]
                }
            }
            .onChange(of: geometry.size) { newValue in
                if !dataSource.isLoading && !dataSource.items.isEmpty && scrollDirection == .vertical {
                    DispatchQueue.main.async {
                        gridViewModel.setOffsets(
                            items: dataSource.items,
                            width: newValue.width,
                            idealGridItemSize: idealGridItemSize
                        )
                    }
                }
            }
            .onChange(of: idealGridItemSize) { newValue in
                if !dataSource.isLoading && !dataSource.items.isEmpty {
                    DispatchQueue.main.async {
                        withAnimation {
                            let width = scrollDirection == .horizontal ? 
                                CGFloat(dataSource.items.count) * idealGridItemSize : 
                                geometry.size.width
                            gridViewModel.setOffsets(
                                items: dataSource.items,
                                width: width,
                                idealGridItemSize: newValue
                            )
                        }
                    }
                }
            }
        }
        .task {
            do {
                try await dataSource.loadItems()
                DispatchQueue.main.async {
                    let width = scrollDirection == .horizontal ? 
                        CGFloat(dataSource.items.count) * idealGridItemSize : 
                        UIScreen.main.bounds.width
                    gridViewModel.setOffsets(
                        items: dataSource.items,
                        width: width,
                        idealGridItemSize: idealGridItemSize
                    )
                }
            } catch {
                print("Error loading items: \(error)")
            }
        }
        .frame(minWidth: 300, minHeight: scrollable ? 0 : gridViewModel.zstackHeight)
    }
    
    // MARK: - Selection Logic
    
    private func handleItemSelection(for itemId: String) {
        if NSEvent.modifierFlags.contains(.shift) && !selected.isEmpty {
            handleShiftSelection(for: itemId)
        } else {
            toggleItemSelection(for: itemId)
        }
    }
    
    private func handleShiftSelection(for itemId: String) {
        guard let index = dataSource.items.firstIndex(where: { $0.id == itemId }) else { return }
        
        let closestLeftIndex = findClosestSelectedIndex(from: index, direction: -1)
        let closestRightIndex = findClosestSelectedIndex(from: index, direction: 1)
        
        if closestLeftIndex == -1 || (closestRightIndex != -1 && closestRightIndex - index < index - closestLeftIndex) {
            selectRange(from: index + 1, to: closestRightIndex)
        } else {
            selectRange(from: closestLeftIndex, to: index - 1)
        }
        selected[itemId] = true
    }
    
    private func findClosestSelectedIndex(from startIndex: Int, direction: Int) -> Int {
        var i = startIndex + direction
        while i >= 0 && i < dataSource.items.count {
            if selected[dataSource.items[i].id] != nil {
                return i
            }
            i += direction
        }
        return -1
    }
    
    private func selectRange(from start: Int, to end: Int) {
        guard start >= 0 && end < dataSource.items.count && start <= end else { return }
        for k in start...end {
            selected[dataSource.items[k].id] = true
        }
    }
    
    private func toggleItemSelection(for itemId: String) {
        if selected[itemId] == nil {
            selected[itemId] = true
        } else {
            selected.removeValue(forKey: itemId)
        }
    }
    
    private func handleDragSelection() {
        let rectangle = (
            x1: dragEnd.x > dragStart.x ? dragStart.x : dragEnd.x,
            y1: dragEnd.y > dragStart.y ? dragStart.y : dragEnd.y,
            x2: dragEnd.x > dragStart.x ? dragEnd.x : dragStart.x,
            y2: dragEnd.y > dragStart.y ? dragEnd.y : dragStart.y
        )
        
        if !(rectangle.x1 == 0 && rectangle.y1 == 0 && rectangle.x2 == 0 && rectangle.y2 == 0) {
            if !NSEvent.modifierFlags.contains(.command) {
                selected = [:]
            }
            multiSelectEnabled = true
            let photosInRectangle = gridViewModel.getPhotosInRectangle(rectangle, items: dataSource.items)
            for selectedId in photosInRectangle {
                selected[selectedId] = true
            }
        }
    }
    
    private func getSelectedItems() -> [PhotoGridItem] {
        return dataSource.items.filter { selected[$0.id] == true }
    }
}

// MARK: - Modifiers

extension ReusablePhotoGrid {
    func idealGridItemSize(_ size: Binding<Double>) -> some View {
        var modified = self
        modified._idealGridItemSize = State(wrappedValue: size.wrappedValue)
        return modified.onChange(of: size.wrappedValue) { newValue in
            modified.idealGridItemSize = newValue
        }
    }
    
    func multiSelectEnabled(_ enabled: Binding<Bool>) -> some View {
        var modified = self
        modified._multiSelectEnabled = State(wrappedValue: enabled.wrappedValue)
        return modified.onChange(of: enabled.wrappedValue) { newValue in
            modified.multiSelectEnabled = newValue
        }
    }
    
    func onPhotoTap(_ handler: @escaping (PhotoGridItem) -> Void) -> ReusablePhotoGrid {
        var modified = self
        modified.onPhotoTap = handler
        return modified
    }
    
    func contextActions(_ actions: [PhotoGridAction]) -> ReusablePhotoGrid {
        var modified = self
        modified.contextActions = actions
        return modified
    }
    
    func dragSelectEnabled(_ enabled: Bool) -> ReusablePhotoGrid {
        var modified = self
        modified.dragSelectEnabled = enabled
        return modified
    }
}

struct SelectionButtonStyle: ButtonStyle {
    let selected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.black.opacity(selected ? 0.5 : 0.25))
            .foregroundColor(Color.white)
            .animation(.easeOut(duration: 0.1), value: selected)
    }
}