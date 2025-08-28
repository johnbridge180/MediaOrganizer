//
//  PhotoGridDataSource.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/28/25.
//

import Foundation

protocol PhotoGridDataSource: ObservableObject {
    var items: [PhotoGridItem] { get }
    var isLoading: Bool { get }
    
    func loadItems() async throws
    func loadMoreItems() async throws
}