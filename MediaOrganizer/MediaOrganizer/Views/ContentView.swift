//
//  ContentView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/17/22.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let minSliderValue: Double = 50.0
    let maxSliderValue: Double = 400.0
    @State var photoSizeSliderValue: Double = 300.0
    @State var sliderDisabled: Bool = false

    @State var selectedTab: Int? = 1

    @State var multiSelect: Bool = false

    @StateObject var downloadManager = DownloadManager.shared

    var mongoHolder: MongoClientHolder

    var placement: ToolbarItemPlacement

    init() {
        let mongoHolder = MongoClientHolder()
        self.mongoHolder = mongoHolder

        if #available(macOS 13.0, *) {
            self.placement = .destructiveAction
        } else {
            self.placement = .automatic
        }
    }

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some View {
        NavigationView {
            List {
                NavigationLink(tag: 1, selection: $selectedTab) {
                    PhotosView(idealGridItemSize: $photoSizeSliderValue, multiSelect: $multiSelect, sliderDisabled: $sliderDisabled, minGridItemSize: minSliderValue, mongoHolder: mongoHolder, appDelegate: appDelegate)
                } label: {
                    if #available(iOS 14.0, *) {
                        Image(systemName: "photo.on.rectangle.angled")
                    } else {
                        Image(systemName: "photo.on.rectangle")
                    }
                    Text("Photos")
                }
                NavigationLink(tag: 2, selection: $selectedTab) {
                    UploadsView(idealGridItemSize: $photoSizeSliderValue, sliderDisabled: $sliderDisabled, minGridItemSize: minSliderValue, mongoHolder: mongoHolder, appDelegate: appDelegate)
                        .onAppear {
                            photoSizeSliderValue=99.0
                            sliderDisabled=true
                        }
                } label: {
                    Image(systemName: "sdcard")
                    Text("Uploads")
                }
                NavigationLink(tag: 3, selection: $selectedTab) {
                    EventsView()
                } label: {
                    if #available(iOS 16.0, macOS 13.0, *) {
                        Image(systemName: "figure.track.and.field")
                    } else if #available(iOS 15.0, macOS 12.0, *) {
                        Image(systemName: "person.2.crop.square.stack")
                    } else {
                        Image(systemName: "calendar")
                    }
                    Text("Events")
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: {
                        NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                    }, label: {
                        Label("Toggle Sidebar", systemImage: "sidebar.left")
                    })
                }
                ToolbarItemGroup(placement: .navigation) {
                    HStack {
                        Slider(value: $photoSizeSliderValue, in: minSliderValue...maxSliderValue) {

                        } minimumValueLabel: {
                            Label {
                                Text("-")
                            } icon: {
                                Image(systemName: "minus")
                            }
                        } maximumValueLabel: {
                            Label {
                                Text("+")
                            } icon: {
                                Image(systemName: "plus")
                            }

                        }
                        .focusable(false)
                        .frame(minWidth: 150.0)
                        .disabled(sliderDisabled)

                        Spacer()
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 400, minHeight: 200)
        .onDisappear {
            mongoHolder.close()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    multiSelect.toggle()
                } label: {
                    Label("Select Multiple Photos", systemImage: multiSelect ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                        .foregroundColor(multiSelect ? Color.blue : Color.secondary)
                }
                Button {
                    appDelegate.openDownloadsPanel()
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                if #available(macOS 13, *) {
                    Button(action: {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }, label: {
                        Label("Settings", systemImage: "gearshape")
                    })
                } else {
                    Button(action: {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }, label: {
                        Label("Settings", systemImage: "gearshape")
                    })
                }
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
