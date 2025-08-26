//
//  PhotoGridView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/30/22.
//

import SwiftUI
import SwiftBSON

struct PhotoGridRow: Identifiable {
    var id: Int
    var items: [MediaItemHolder]
}

struct PhotoGridView: View {
    @Environment(\.managedObjectContext) private var moc

    @Binding var idealGridItemSize: Double
    @Binding var multiSelect: Bool
    let minGridItemSize: Double
    let scrollable: Bool
    let horizontalScroll: Bool
    let limit: Int
    let filter: BSONDocument

    @StateObject var mediaVModel: MediaItemsViewModel
    @StateObject var gridViewModel: PhotoGridViewModel

    @State var selected: [BSONObjectID: Bool] = [:]

    @State var dragging: Bool = false
    @State var dragStart: CGPoint = CGPoint()
    @State var dragEnd: CGPoint = CGPoint()

    init(idealGridItemSize: Binding<Double>, multiSelect: Binding<Bool>? = nil, minGridItemSize: Double, mongoHolder: MongoClientHolder, appDelegate: AppDelegate, filter: BSONDocument, limit: Int=0, scrollable: Bool = true, horizontalScroll: Bool = false) {
        self._idealGridItemSize = idealGridItemSize
        self._multiSelect = multiSelect ?? Binding(get: { false }, set: { _ in })
        self.minGridItemSize = minGridItemSize
        self.limit = limit
        self.filter = filter
        let mVmodel = MediaItemsViewModel(mongoHolder: mongoHolder, moc: PersistenceController.shared.container.viewContext, appDelegate: appDelegate)
        self._mediaVModel = StateObject(wrappedValue: mVmodel)
        self.scrollable = scrollable
        self.horizontalScroll = horizontalScroll
        self._gridViewModel = StateObject(wrappedValue: PhotoGridViewModel(minGridItemSize: minGridItemSize, mediaViewModel: mVmodel))
    }

    var body: some View {
        GeometryReader { geometry in
            let grid = ZStack(alignment: .topLeading) {
                Rectangle()
                    .frame(width: horizontalScroll ? CGFloat(mediaVModel.itemOrder.count)*idealGridItemSize : geometry.size.width, height: horizontalScroll ? idealGridItemSize : gridViewModel.zstackHeight)
                    .opacity(0)
                ForEach(mediaVModel.itemOrder, id: \.hex) { object in
                    if let item = mediaVModel.items[object] {
                        let dimensions = item.item.getDisplayDimensions()
                        ZStack {
                            mediaVModel.items[object]?.view
                            if self.multiSelect {
                                Button {
                                    if NSEvent.modifierFlags.contains(.shift) && !self.selected.isEmpty {
                                        guard let index = mediaVModel.itemOrder.firstIndex(of: item.item._id) else { return }
                                        var i = index-1
                                        var closestLeftIndex = -1
                                        while i >= 0 {
                                            if self.selected[mediaVModel.itemOrder[i]] != nil {
                                                closestLeftIndex = i
                                                break
                                            }
                                            i -= 1
                                        }
                                        i = index + 1
                                        var closestRightIndex = -1
                                        while i<mediaVModel.itemOrder.count {
                                            if self.selected[mediaVModel.itemOrder[i]] != nil {
                                                closestRightIndex = i
                                                break
                                            }
                                            i += 1
                                        }

                                        if closestLeftIndex == -1 || (closestRightIndex != -1 && closestRightIndex-index < index-closestLeftIndex) {
                                            for k in (index+1)...closestRightIndex {
                                                self.selected[mediaVModel.itemOrder[k]] = true
                                            }
                                        } else {
                                            for k in closestLeftIndex...(index-1) {
                                                self.selected[mediaVModel.itemOrder[k]] = true
                                            }
                                        }
                                        self.selected[item.item._id] = true
                                    } else {
                                        if self.selected[item.item._id] == nil {
                                            self.selected[item.item._id] = true
                                        } else {
                                            self.selected.removeValue(forKey: item.item._id)
                                        }
                                    }

                                } label: {
                                    Image(systemName: selected[item.item._id] ?? false ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 180 < gridViewModel.photoWidth ? 60 : gridViewModel.photoWidth/3.0))
                                        .padding()
                                        .frame(
                                            width: dimensions.width >= dimensions.height ?
                                            gridViewModel.photoWidth : gridViewModel.photoWidth * Double(dimensions.width)/Double(dimensions.height),
                                            height: dimensions.width >= dimensions.height ?
                                            gridViewModel.photoWidth * Double(dimensions.height)/Double(dimensions.width) : gridViewModel.photoWidth
                                        )
                                }
                                .buttonStyle(ImageSelectButton(selected: selected[item.item._id] ?? false))
                                .foregroundColor(Color.white)
                            }
                        }
                        .frame(width: gridViewModel.photoWidth, height: gridViewModel.photoWidth)
                        .offset(gridViewModel.offsets[object] ?? CGSize())
                        .contextMenu {
                            if self.selected[item.item._id] == true {
                                Button("Download \(self.selected.count) items") {
                                    for (key, value) in self.selected where value {
                                        if let mediaItem = self.mediaVModel.items[key] {
                                            DownloadManager.shared.download(mediaItem.item)
                                        }
                                    }
                                }
                            } else {
                                Button("Download \(item.item.name)") {
                                    DownloadManager.shared.download(item.item)
                                }
                            }
                        }
                    }

                }
                if dragging && !horizontalScroll {
                    Rectangle()
                        .fill(Color.blue.opacity(0.25))
                        .border(.blue)
                        .frame(width: abs(self.dragEnd.x-self.dragStart.x), height: abs(self.dragEnd.y-self.dragStart.y))
                        .offset(x: self.dragEnd.x > self.dragStart.x ? self.dragStart.x : self.dragEnd.x, y: self.dragEnd.y > self.dragStart.y ? self.dragStart.y : self.dragEnd.y)
                }
            }
                .contentShape(Rectangle())
                .gesture(
                        DragGesture()
                        .onChanged({ value in
                            self.dragging = true
                            self.dragStart = value.startLocation
                            self.dragEnd = value.location
                        })
                        .onEnded({ _ in
                            let rectangle = (x1: self.dragEnd.x > self.dragStart.x ? self.dragStart.x : self.dragEnd.x, y1: self.dragEnd.y > self.dragStart.y ? self.dragStart.y : self.dragEnd.y, x2: self.dragEnd.x > self.dragStart.x ? self.dragEnd.x : self.dragStart.x, y2: self.dragEnd.y > self.dragStart.y ? self.dragEnd.y : self.dragStart.y)
                            if !(rectangle.x1 == 0 && rectangle.y1==0 && rectangle.x2==0 && rectangle.y2==0) {
                                if !NSEvent.modifierFlags.contains(.command) {
                                    self.selected = [:]
                                }
                                self.multiSelect = true
                                let photosInRectangle = gridViewModel.getPhotosInRectangle(rectangle)
                                for selectedObjectID in photosInRectangle {
                                    self.selected[selectedObjectID] = true
                                }

                                self.dragging = false
                                self.dragStart = CGPoint()
                                self.dragEnd = CGPoint()
                            }
                        })
                )

            VStack {
                if scrollable {
                    ScrollView(horizontalScroll ? .horizontal : .vertical, showsIndicators: true) {
                            grid
                                .onFrameChange { frame in
                                    if !horizontalScroll {
                                        mediaVModel.onScrollFrameUpdate(frame, width: geometry.size.width, height: geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photoWidth)
                                    }
                                }
                    }
                } else /*if(!mediaVModel.isFetching)*/ {
                    grid
                }
            }
            .onChange(of: multiSelect, perform: { newValue in
                if !newValue {
                    selected = [:]
                }
            })
            .onChange(of: geometry.size) { newValue in
                if !mediaVModel.isFetching && !mediaVModel.items.isEmpty && !horizontalScroll {
                    DispatchQueue.main.async {
                        gridViewModel.setOffsets(width: newValue.width, idealGridItemSize: idealGridItemSize)
                    }
                    mediaVModel.updateRangeValuesForResize(width: newValue.width, height: newValue.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photoWidth)
                }
            }
            .onChange(of: idealGridItemSize, perform: { newValue in
                if !mediaVModel.isFetching && !mediaVModel.items.isEmpty {
                    DispatchQueue.main.async {
                        withAnimation {
                            gridViewModel.setOffsets(width: horizontalScroll ? CGFloat(mediaVModel.itemOrder.count)*idealGridItemSize : geometry.size.width, idealGridItemSize: newValue)
                        }
                        mediaVModel.updateRangeValuesForResize(width: horizontalScroll ? CGFloat(mediaVModel.itemOrder.count)*idealGridItemSize : geometry.size.width, height: horizontalScroll ? idealGridItemSize : geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photoWidth)
                    }
                }
            })
            .onAppear {
                Task {
                    do {
                        try await mediaVModel.fetchRows(limit: self.limit, filter: self.filter)
                        gridViewModel.setOffsets(width: horizontalScroll ? CGFloat(mediaVModel.itemOrder.count)*idealGridItemSize : geometry.size.width, idealGridItemSize: idealGridItemSize)

                        mediaVModel.setRangeValues(zstackOriginY: 0, width: horizontalScroll ? CGFloat(mediaVModel.itemOrder.count)*idealGridItemSize : geometry.size.width, height: horizontalScroll ? idealGridItemSize : geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photoWidth)
                    } catch {}
                }
            }
            .onDisappear {
                do {
                    try moc.save()
                } catch {}
            }
        }
        .frame(minWidth: 300, minHeight: scrollable ? 0 : gridViewModel.zstackHeight)
    }
}

struct PhotoGridView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoGridView(idealGridItemSize: Binding(get: { return 100.0}, set: {_ in }), minGridItemSize: 50.0, mongoHolder: MongoClientHolder(), appDelegate: AppDelegate(), filter: [:], limit: 10, scrollable: true)
    }
}

struct ImageSelectButton: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.black.opacity(selected ? 0.5 : 0.25))
            .foregroundColor(Color.white)
            .animation(.easeOut(duration: 0.1), value: selected)
    }
}
