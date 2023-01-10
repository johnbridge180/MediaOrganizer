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
    
    let min_slider_value: Double = 50.0
    let max_slider_value: Double = 400.0
    
    @State var photo_size_slider_value: Double = 300.0
    
    @State var selected_tab: Int? = 1
    
    var mongo_holder: MongoClientHolder = MongoClientHolder()
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some View {
        NavigationView {
            List {
                NavigationLink(tag: 1, selection: $selected_tab) {
                    MediaThumbAsyncGrid(idealGridItemSize: $photo_size_slider_value, minGridItemSize: min_slider_value, mongo_holder: mongo_holder, appDelegate: appDelegate, filter: [:])
                } label: {
                    if #available(iOS 14.0, *) {
                        Image(systemName: "photo.on.rectangle.angled")
                    } else {
                        Image(systemName: "photo.on.rectangle")
                    }
                    Text("Photos")
                }
                NavigationLink(tag: 2, selection: $selected_tab) {
                    UploadsView(idealGridItemSize: $photo_size_slider_value, minGridItemSize: min_slider_value, mongo_holder: mongo_holder, appDelegate: appDelegate)
                        .onAppear {
                            photo_size_slider_value=99.0
                        }
                } label: {
                    Image(systemName: "sdcard")
                    Text("Uploads")
                }
                NavigationLink(tag: 3, selection: $selected_tab) {
                    Text("Events")
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
            .listStyle(.sidebar)
        }
        .frame(minWidth: 400, minHeight: 200)
        .toolbar {
            ToolbarItem {
                Slider(value: $photo_size_slider_value, in: min_slider_value...max_slider_value) {
                    
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
            }
            ToolbarItem {
                Button {
                    appDelegate.openDownloadsPanel()
                } label: {
                    VStack {
                        Image(systemName: "arrow.down.circle")
                    }
                }
            }
            ToolbarItem {
                Button(action: {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }, label: {
                    Label("Settings", systemImage: "gearshape")
                })
            }
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil,from: nil)
                }, label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                })
            }
        }
        .onDisappear {
            mongo_holder.close()
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
