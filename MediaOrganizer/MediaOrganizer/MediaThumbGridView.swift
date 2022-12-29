//
//  PhotosView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/24/22.
//

import SwiftUI
import CoreData

struct MediaThumbGridView: View {
    @Environment(\.managedObjectContext) private var moc
    
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
                        if let cache_row: PreviewCache = item.cache_row {
                            MediaThumbView(item.item, appDelegate: appDelegate, entry: cache_row)
                        } else {
                            MediaThumbView(item.item, appDelegate: appDelegate)
                        }
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
                    if(numberGridItems(for: geometry.size.width) != gridItems.count) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            gridItems = gridItems(for: geometry.size.width)
                        }
                    }
                })
                .onAppear {
                    Task {
                        mediaVModel.linkMOC(moc)
                        mediaVModel.linkMongoClientHolder(mongo_holder)
                        do {
                            try await mediaVModel.fetchRows(start: 0)
                        } catch {
                            //TODO: error catching
                        }
                    }
                    withAnimation(.easeOut(duration: 0.3)) {
                        gridItems = gridItems(for: geometry.size.width)
                    }
                }
                .onDisappear {
                    do {
                        try PersistenceController.shared.container.viewContext.save()
                    } catch {
                        print("Error saving viewContext\n")
                    }
                }
            }
        }
        .frame(minWidth: 600.0)
    }
    
    func numberGridItems(for width: CGFloat) -> Int {
        return Int(width/maxGridItemSize)
    }
    
    func gridItems(for width: CGFloat) -> [GridItem] {
        var items: [GridItem] = []
        for _ in 0..<numberGridItems(for: width) {
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
