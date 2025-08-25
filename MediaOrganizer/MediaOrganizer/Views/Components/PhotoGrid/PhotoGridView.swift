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
    @Binding var multi_select: Bool
    let minGridItemSize: Double
    let scrollable: Bool
    let horizontalScroll: Bool
    let limit: Int
    let filter: BSONDocument
    
    @StateObject var mediaVModel: MediaItemsViewModel
    @StateObject var gridViewModel: PhotoGridViewModel
    
    @State var selected: [BSONObjectID:Bool] = [:]
    
    @State var dragging: Bool = false
    @State var dragStart: CGPoint = CGPoint()
    @State var dragEnd: CGPoint = CGPoint()

    init(idealGridItemSize: Binding<Double>, multi_select: Binding<Bool>, minGridItemSize: Double, mongo_holder: MongoClientHolder, appDelegate: AppDelegate, filter: BSONDocument, limit: Int=0, scrollable: Bool = true, horizontalScroll: Bool = false) {
        self._idealGridItemSize=idealGridItemSize
        self._multi_select=multi_select
        self.minGridItemSize=minGridItemSize
        self.limit=limit
        self.filter=filter
        let mVmodel = MediaItemsViewModel(mongo_holder: mongo_holder, moc: PersistenceController.shared.container.viewContext, appDelegate: appDelegate)
        self._mediaVModel=StateObject(wrappedValue: mVmodel)
        self.scrollable=scrollable
        self.horizontalScroll=horizontalScroll
        self._gridViewModel=StateObject(wrappedValue: PhotoGridViewModel(minGridItemSize: minGridItemSize, mediaViewModel: mVmodel))
    }
    
    init(idealGridItemSize: Binding<Double>, minGridItemSize: Double, mongo_holder: MongoClientHolder, appDelegate: AppDelegate, filter: BSONDocument, limit: Int=0, scrollable: Bool = true, horizontalScroll: Bool = false) {
        let multi_select: Binding<Bool> = Binding {
            false
        } set: { _ in
            
        }
        self._idealGridItemSize=idealGridItemSize
        self._multi_select=multi_select
        self.minGridItemSize=minGridItemSize
        self.limit=limit
        self.filter=filter
        let mVmodel = MediaItemsViewModel(mongo_holder: mongo_holder, moc: PersistenceController.shared.container.viewContext, appDelegate: appDelegate)
        self._mediaVModel=StateObject(wrappedValue: mVmodel)
        self.scrollable=scrollable
        self.horizontalScroll=horizontalScroll
        self._gridViewModel=StateObject(wrappedValue: PhotoGridViewModel(minGridItemSize: minGridItemSize, mediaViewModel: mVmodel))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let grid = ZStack(alignment: .topLeading) {
                Rectangle()
                    .frame(width: horizontalScroll ? CGFloat(mediaVModel.item_order.count)*idealGridItemSize : geometry.size.width, height: horizontalScroll ? idealGridItemSize : gridViewModel.zstack_height)
                    .opacity(0)
                ForEach(mediaVModel.item_order, id: \.hex) { object in
                    if let item = mediaVModel.items[object] {
                        let dimensions = item.item.getDisplayDimensions()
                        ZStack {
                            mediaVModel.items[object]?.view
                            if self.multi_select {
                                Button {
                                    if(NSEvent.modifierFlags.contains(.shift) && self.selected.count>0) {
                                        let index = mediaVModel.item_order.firstIndex(of: item.item._id)!
                                        var i = index-1
                                        var closest_left_index = -1
                                        while i >= 0 {
                                            if self.selected[mediaVModel.item_order[i]] != nil {
                                                closest_left_index = i
                                                break
                                            }
                                            i -= 1
                                        }
                                        i = index + 1
                                        var closest_right_index = -1
                                        while i<mediaVModel.item_order.count {
                                            if self.selected[mediaVModel.item_order[i]] != nil {
                                                closest_right_index = i
                                                break
                                            }
                                            i += 1
                                        }
                                        
                                        if closest_left_index == -1 || (closest_right_index != -1 && closest_right_index-index < index-closest_left_index) {
                                            for k in (index+1)...closest_right_index {
                                                self.selected[mediaVModel.item_order[k]] = true
                                            }
                                        } else {
                                            for k in closest_left_index...(index-1) {
                                                self.selected[mediaVModel.item_order[k]] = true
                                            }
                                        }
                                        self.selected[item.item._id] = true
                                    } else {
                                        if(self.selected[item.item._id] == nil) {
                                            self.selected[item.item._id] = true
                                        } else {
                                            self.selected.removeValue(forKey: item.item._id)
                                        }
                                    }
                                    
                                } label: {
                                    Image(systemName: selected[item.item._id] ?? false ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 180 < gridViewModel.photo_width ? 60 : gridViewModel.photo_width/3.0))
                                        .padding()
                                        .frame(
                                            width: dimensions.width >= dimensions.height ?
                                            gridViewModel.photo_width : gridViewModel.photo_width * Double(dimensions.width)/Double(dimensions.height),
                                            height: dimensions.width >= dimensions.height ?
                                            gridViewModel.photo_width * Double(dimensions.height)/Double(dimensions.width) : gridViewModel.photo_width
                                        )
                                }
                                .buttonStyle(ImageSelectButton(selected: selected[item.item._id] ?? false))
                                .foregroundColor(Color.white)
                            }
                        }
                        .frame(width: gridViewModel.photo_width, height: gridViewModel.photo_width)
                        .offset(gridViewModel.offsets[object] ?? CGSize())
                        .contextMenu {
                            if self.selected[item.item._id] == true {
                                Button("Download \(self.selected.count) items") {
                                    for (key,value) in self.selected {
                                        if value {
                                            DownloadManager.shared.download(self.mediaVModel.items[key]!.item)
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
                        .offset(x: self.dragEnd.x > self.dragStart.x ? self.dragStart.x : self.dragEnd.x , y: self.dragEnd.y > self.dragStart.y ? self.dragStart.y : self.dragEnd.y)
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
                        .onEnded({ value in
                            let rectangle = (x1: self.dragEnd.x > self.dragStart.x ? self.dragStart.x : self.dragEnd.x, y1: self.dragEnd.y > self.dragStart.y ? self.dragStart.y : self.dragEnd.y, x2: self.dragEnd.x > self.dragStart.x ? self.dragEnd.x : self.dragStart.x, y2: self.dragEnd.y > self.dragStart.y ? self.dragEnd.y : self.dragStart.y)
                            if !(rectangle.x1 == 0 && rectangle.y1==0 && rectangle.x2==0 && rectangle.y2==0) {
                                if !NSEvent.modifierFlags.contains(.command) {
                                    self.selected = [:]
                                }
                                self.multi_select = true
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
                if(scrollable) {
                    ScrollView(horizontalScroll ? .horizontal : .vertical, showsIndicators: true) {
                            grid
                                .onFrameChange { (frame) in
                                    if !horizontalScroll {
                                        mediaVModel.onScrollFrameUpdate(frame, width: geometry.size.width, height: geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photo_width)
                                    }
                                }
                    }
                } else /*if(!mediaVModel.isFetching)*/ {
                    grid
                }
            }
            .onChange(of: multi_select, perform: { newValue in
                if !newValue {
                    selected = [:]
                }
            })
            .onChange(of: geometry.size) { newValue in
                if(!mediaVModel.isFetching && mediaVModel.items.count>0 && !horizontalScroll) {
                    DispatchQueue.main.async {
                        gridViewModel.setOffsets(width: newValue.width, idealGridItemSize: idealGridItemSize)
                    }
                    mediaVModel.updateRangeValuesForResize(width: newValue.width, height: newValue.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photo_width)
                }
            }
            .onChange(of: idealGridItemSize, perform: { newValue in
                if(!mediaVModel.isFetching && mediaVModel.items.count>0) {
                    DispatchQueue.main.async {
                        withAnimation {
                            gridViewModel.setOffsets(width: horizontalScroll ? CGFloat(mediaVModel.item_order.count)*idealGridItemSize : geometry.size.width, idealGridItemSize: newValue)
                        }
                        mediaVModel.updateRangeValuesForResize(width: horizontalScroll ? CGFloat(mediaVModel.item_order.count)*idealGridItemSize : geometry.size.width, height: horizontalScroll ? idealGridItemSize : geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photo_width)
                    }
                }
            })
            .onAppear {
                Task {
                    do {
                        try await mediaVModel.fetchRows(limit: self.limit, filter: self.filter)
                        gridViewModel.setOffsets(width: horizontalScroll ? CGFloat(mediaVModel.item_order.count)*idealGridItemSize : geometry.size.width, idealGridItemSize: idealGridItemSize)

                        mediaVModel.setRangeValues(zstack_origin_y: 0, width: horizontalScroll ? CGFloat(mediaVModel.item_order.count)*idealGridItemSize : geometry.size.width, height: horizontalScroll ? idealGridItemSize : geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photo_width)
                    } catch {}
                }
            }
            .onDisappear {
                do {
                    try moc.save()
                } catch {}
            }
        }
        .frame(minWidth: 300, minHeight: scrollable ? 0 : gridViewModel.zstack_height)
    }
}

struct PhotoGridView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoGridView(idealGridItemSize: Binding(get: { return 100.0}, set: {_ in }), minGridItemSize: 50.0, mongo_holder: MongoClientHolder(), appDelegate: AppDelegate(), filter: [:], limit: 10, scrollable: true)
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
