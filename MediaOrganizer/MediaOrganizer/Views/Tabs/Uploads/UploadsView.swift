//
//  UploadsView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/29/22.
//

import SwiftUI
import SwiftBSON
import MongoSwift

struct UploadsView: View {

    @StateObject var uploadsVModel: UploadsViewModel

    var mongoHolder: MongoClientHolder

    let minGridItemSize: Double

    @Binding var idealGridItemSize: Double

    var appDelegate: AppDelegate

    var dateFormatter: DateFormatter

    @State var didLoadRows: Bool = false

    @Binding var sliderDisabled: Bool

    @State var expandedUpload: Upload?

    init(idealGridItemSize: Binding<Double>, sliderDisabled: Binding<Bool>, minGridItemSize: Double, mongoHolder: MongoClientHolder, appDelegate: AppDelegate) {
        self.mongoHolder=mongoHolder
        self.minGridItemSize=minGridItemSize
        self._uploadsVModel = StateObject(wrappedValue: UploadsViewModel(mongoHolder: mongoHolder))
        self._idealGridItemSize=idealGridItemSize
        self._sliderDisabled=sliderDisabled
        self.appDelegate=appDelegate
        self.dateFormatter=DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
    }

    var body: some View {
        GeometryReader { geometry in
            if let upload: Upload = expandedUpload {
                VStack {
                    HStack {
                        Button {
                            withAnimation {
                                self.sliderDisabled = true
                                self.idealGridItemSize = 99.0
                                self.expandedUpload = nil
                            }
                        } label: {
                            Image(systemName: "chevron.backward.circle")
                                .controlSize(.large)
                        }
                        .buttonStyle(.plain)

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
                    PhotoGridView(idealGridItemSize: $idealGridItemSize, minGridItemSize: minGridItemSize, mongoHolder: mongoHolder, appDelegate: appDelegate, filter: ["upload_id": .objectID(upload._id)], horizontalScroll: false)
                        .frame(width: geometry.size.width)
                }
            } else {
                ScrollView(.vertical) {
                    VStack {
                        if didLoadRows && !uploadsVModel.isFetching {
                            ForEach(uploadsVModel.uploads) { upload in
                                VStack {
                                    HStack {
                                        Text(dateFormatter.string(from: upload.time))
                                            .font(.system(size: 36))
                                            .bold()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Spacer()
                                        Menu {
                                            Button("Download") {
                                                Task {
                                                    for try await doc in try await mongoHolder.client!.db("media_organizer").collection("files").find(["upload_id": BSON.objectID(upload._id)], options: FindOptions(sort: ["time": -1])) {
                                                        if let item: MediaItem = try? BSONDecoder().decode(MediaItem.self, from: doc) {
                                                            DownloadManager.shared.download(item)
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .font(.system(size: 20))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 10))
                                    .onTapGesture {
                                        withAnimation {
                                            self.expandedUpload = upload
                                            self.sliderDisabled = false
                                        }
                                    }
                                    .padding(EdgeInsets(top: 5, leading: 15, bottom: -2, trailing: 0))
                                    Rectangle()
                                        .fill(.separator)
                                        .frame(maxWidth: .infinity, maxHeight: 2)
                                        .padding(EdgeInsets(top: -5, leading: 15, bottom: 0, trailing: 0))
                                    PhotoGridView(idealGridItemSize: $idealGridItemSize, minGridItemSize: minGridItemSize, mongoHolder: mongoHolder, appDelegate: appDelegate, filter: ["upload_id": .objectID(upload._id)], horizontalScroll: true)
                                        .frame(width: geometry.size.width, height: CGFloat(idealGridItemSize))
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    if !didLoadRows {
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
}

struct UploadsView_Previews: PreviewProvider {
    static var previews: some View {
        UploadsView(idealGridItemSize: Binding(get: { return 300.0 }, set: { _ in }), sliderDisabled: Binding(get: { return true }, set: { _ in }), minGridItemSize: 50.0,
                    mongoHolder: MongoClientHolder(),
                    appDelegate: AppDelegate())
    }
}
