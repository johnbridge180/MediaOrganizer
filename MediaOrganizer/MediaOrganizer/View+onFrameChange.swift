//
//  View+onFrameChange.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/3/23.
//

import SwiftUI

//credit: https://stackoverflow.com/a/58875884/949695
extension View {
    func onFrameChange(_ frameHandler: @escaping (CGRect)->(), enabled isEnabled: Bool = true) -> some View {
        guard isEnabled else { return AnyView(self) }

        return AnyView(self.background(GeometryReader { (geometry: GeometryProxy) in
            Color.clear.beforeReturn {
                frameHandler(geometry.frame(in: .global))
            }
        }))
    }

    private func beforeReturn(_ onBeforeReturn: ()->()) -> Self {
        onBeforeReturn()
        return self
    }
}
