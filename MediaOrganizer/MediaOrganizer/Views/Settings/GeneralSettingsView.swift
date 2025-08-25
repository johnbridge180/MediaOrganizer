//
//  GeneralSettingsView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/25/22.
//

import SwiftUI

struct GeneralSettingsView: View {
    
    @AppStorage("downloads_folder") private var downloads_folder: String = "~/Downloads"
    @AppStorage("api_endpoint_url") private var api_endpoint_url: String = ""
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer(minLength: 20)
                Form {
                    TextField("Downloads Folder: ", text: $downloads_folder)
                }
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 20)
            }
            Spacer()
        }
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
    }
}
