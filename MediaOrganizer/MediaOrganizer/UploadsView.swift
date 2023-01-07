//
//  UploadsView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/29/22.
//

import SwiftUI

struct UploadsView: View {
    
    @StateObject var uploadsVModel: UploadsViewModel
    
    var mongo_holder: MongoClientHolder
    
    let minGridItemSize: Double
    
    var idealGridItemSize: Binding<Double>
    
    var appDelegate: AppDelegate
    
    var dateFormatter: DateFormatter
    
    @State var didLoadRows: Bool = false
    
    init(idealGridItemSize: Binding<Double>, minGridItemSize: Double, mongo_holder: MongoClientHolder, appDelegate: AppDelegate) {
        self.mongo_holder=mongo_holder
        self.minGridItemSize=minGridItemSize
        self._uploadsVModel = StateObject(wrappedValue: UploadsViewModel(mongo_holder: mongo_holder))
        self.idealGridItemSize=idealGridItemSize
        self.appDelegate=appDelegate
        self.dateFormatter=DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                VStack {
                    if(didLoadRows && !uploadsVModel.isFetching) {
                        ForEach(uploadsVModel.uploads) { upload in
                            VStack {
                                HStack {
                                    Text(dateFormatter.string(from: upload.time))
                                        .font(.system(size: 36))
                                        .bold()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(EdgeInsets(top: 5, leading: 15, bottom: -2, trailing: 0))
                                Rectangle()
                                    .fill(.separator)
                                    .frame(maxWidth: .infinity, maxHeight: 2)
                                    .padding(EdgeInsets(top: -5, leading: 15, bottom: 0, trailing: 0))
                                MediaThumbAsyncGrid(idealGridItemSize: idealGridItemSize, minGridItemSize: minGridItemSize, mongo_holder: mongo_holder, appDelegate: appDelegate, filter: ["upload_id":.objectID(upload._id)], limit: 40, scrollable: false)
                            }
                        }
                    }
                }
            }
            .onAppear {
                if(!didLoadRows) {
                    Task {
                        do {
                            try await uploadsVModel.fetchRows(start: 0)
                            didLoadRows=true
                        } catch {}
                    }
                }
            }
        }
    }
}

struct UploadsView_Previews: PreviewProvider {
    static var previews: some View {
        UploadsView(idealGridItemSize: Binding(get: { return 300.0 }, set: { _ in }), minGridItemSize: 50.0,
                    mongo_holder: MongoClientHolder(),
                    appDelegate: AppDelegate())
    }
}
