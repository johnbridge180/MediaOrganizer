//
//  PhotoGridAction.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/28/25.
//

import Foundation

struct PhotoGridAction {
    let title: String
    let handler: ([PhotoGridItem]) -> Void
    
    init(title: String, handler: @escaping ([PhotoGridItem]) -> Void) {
        self.title = title
        self.handler = handler
    }
}