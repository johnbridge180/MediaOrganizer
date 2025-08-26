//
//  ServerSettingsView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 12/25/22.
//

import SwiftUI

struct ServerSettingsView: View {

    @AppStorage("mongodb_url") private var mongodbUrl: String = ""
    @AppStorage("api_endpoint_url") private var apiEndpointUrl: String = ""

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer(minLength: 20)
                Form {
                    TextField("MongoDB URL: ", text: $mongodbUrl)
                    TextField("Api Endpoint URL: ", text: $apiEndpointUrl)
                }
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 20)
            }
            Spacer()
        }
    }
}

struct ServerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ServerSettingsView()
    }
}
