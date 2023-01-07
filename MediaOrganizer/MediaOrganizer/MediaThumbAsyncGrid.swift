//
//  MediaThumbAsyncGrid.swift
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

struct MediaThumbAsyncGrid: View {
    @Environment(\.managedObjectContext) private var moc
    
    @Binding var idealGridItemSize: Double
    let minGridItemSize: Double
    let scrollable: Bool
    let limit: Int
    let filter: BSONDocument
    
    @StateObject var mediaVModel: MediaItemsViewModel
    @StateObject var gridViewModel: GridViewModel

    init(idealGridItemSize: Binding<Double>, minGridItemSize: Double, mongo_holder: MongoClientHolder, appDelegate: AppDelegate, filter: BSONDocument, limit: Int=0, scrollable: Bool = true) {
        self._idealGridItemSize=idealGridItemSize
        self.minGridItemSize=minGridItemSize
        self.limit=limit
        self.filter=filter
        let mVmodel = MediaItemsViewModel(mongo_holder: mongo_holder, moc: PersistenceController.shared.container.viewContext, appDelegate: appDelegate)
        self._mediaVModel=StateObject(wrappedValue: mVmodel)
        self.scrollable=scrollable
        self._gridViewModel=StateObject(wrappedValue: GridViewModel(minGridItemSize: minGridItemSize, mediaViewModel: mVmodel))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let grid = ZStack(alignment: .topLeading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: gridViewModel.zstack_height)
                    .opacity(0)
                
                ForEach(mediaVModel.items.indices, id: \.self) { i in
                    if(i<gridViewModel.offsets.count) {
                        mediaVModel.items[i].view
                            .frame(width: gridViewModel.photo_width, height: gridViewModel.photo_width)
                            .offset(gridViewModel.offsets[i])
                    }
                }
            }
            VStack {
                if(scrollable) {
                    ScrollView(.vertical) {
                        if(!mediaVModel.isFetching) {
                            grid
                                .onFrameChange { (frame) in
                                    mediaVModel.onScrollFrameUpdate(frame, width: geometry.size.width, height: geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photo_width)
                                }
                        }
                    }
                } else if(!mediaVModel.isFetching) {
                    grid
                }
            }
            .onChange(of: geometry.size) { newValue in
                if(!mediaVModel.isFetching && mediaVModel.items.count>0) {
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
                            gridViewModel.setOffsets(width: geometry.size.width, idealGridItemSize: newValue)
                        }
                        mediaVModel.updateRangeValuesForResize(width: geometry.size.width, height: geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photo_width)
                    }
                }
            })
            .onAppear {
                Task {
                    do {
                        try await mediaVModel.fetchRows(limit: self.limit, filter: self.filter)
                        gridViewModel.setOffsets(width: geometry.size.width, idealGridItemSize: idealGridItemSize)

                        mediaVModel.setRangeValues(zstack_origin_y: 0, width: geometry.size.width, height: geometry.size.height, numColumns: gridViewModel.numCols, colWidth: gridViewModel.photo_width)
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

struct MediaThumbAsyncGrid_Previews: PreviewProvider {
    static var previews: some View {
        MediaThumbAsyncGrid(idealGridItemSize: Binding(get: { return 100.0}, set: {_ in }), minGridItemSize: 50.0, mongo_holder: MongoClientHolder(), appDelegate: AppDelegate(), filter: [:], limit: 10, scrollable: true)
    }
}
