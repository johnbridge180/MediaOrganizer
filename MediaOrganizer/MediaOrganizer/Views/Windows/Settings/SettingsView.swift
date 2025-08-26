//
//  SettingsView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/24/22.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var activeTab: UInt8 = 0

    var body: some View {
        ZStack {
            TabView {
                GeneralSettingsView()
                    .tabItem {
                        Label("General", systemImage: "gearshape")
                    }
                ServerSettingsView()
                    .tabItem {
                        Label("Server", systemImage: "server.rack")
                    }
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .fixedSize(horizontal: false, vertical: true)
                    .truncationMode(SwiftUI.Text.TruncationMode.tail)
            }
        }
        .frame(width: 624, height: 412, alignment: .center)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
