//
//  PhotosView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/24/22.
//

import SwiftUI

struct MediaThumbGridView: View {
    @AppStorage("api_endpoint_url") private var api_endpoint_url: String = ""
    
    var mongo_holder:MongoClientHolder
    @StateObject var mediaVModel:MediaItemsViewModel = MediaItemsViewModel()
    
    @Binding var maxGridItemSize: Double
    
    @State var gridItems: [GridItem] = []
    
    var appDelegate:AppDelegate
    
    init(maxGridItemSize: Binding<Double>, mongo_holder: MongoClientHolder, appDelegate: AppDelegate) {
        self._maxGridItemSize=maxGridItemSize
        self.mongo_holder=mongo_holder
        self.appDelegate=appDelegate
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: gridItems) {
                    ForEach(mediaVModel.items, id: \.self) { item in
                        MediaThumbView(item,appDelegate: appDelegate)
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                .onChange(of: geometry.size) { newValue in
                    if gridItems.isEmpty {
                        gridItems = gridItems(for: newValue.width)
                    } else {
                        withAnimation(.easeOut(duration: 0.3)) {
                            gridItems = gridItems(for: newValue.width)
                        }
                    }
                }
                .onChange(of: maxGridItemSize, perform: { newValue in
                    withAnimation(.easeOut(duration: 0.3)) {
                        gridItems = gridItems(for: geometry.size.width)
                    }
                })
                .onAppear {
                    Task {
                        mediaVModel.linkMongoClientHolder(mongo_holder)
                        do {
                            try await mediaVModel.fetchRows(start: 0)
                        } catch {
                            //TODO: error catching
                        }
                    }
                    withAnimation {
                        gridItems = gridItems(for: geometry.size.width)
                    }
                }
            }
        }
        .frame(minWidth: 600.0)
    }
    func gridItems(for width: CGFloat) -> [GridItem] {
        var items: [GridItem] = []
        for _ in 0..<Int(width/maxGridItemSize) {
            items.append(GridItem(.flexible()))
        }
        return items
    }
}

struct MediaThumbGridView_Previews: PreviewProvider {
    static var previews: some View {
        MediaThumbGridView(maxGridItemSize: Binding(get: {
            return 300.0
        }, set: { value in
            
        }),mongo_holder: MongoClientHolder(), appDelegate: AppDelegate())
    }
}
