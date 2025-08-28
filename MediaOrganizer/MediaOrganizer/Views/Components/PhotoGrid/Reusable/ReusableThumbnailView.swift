//
//  ReusableThumbnailView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 8/28/25.
//

import SwiftUI

struct ReusableThumbnailView: View {
    let item: PhotoGridItem
    let size: CGSize
    let onTap: (PhotoGridItem) -> Void
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        onTap(item)
                    }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Group {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            }
                        }
                    )
            }
        }
        .task {
            await loadImage()
        }
        .id(item.id + "\(size.width)x\(size.height)")
    }
    
    private func loadImage() async {
        guard image == nil else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        image = await PhotoGridThumbnailCache.shared.getThumbnail(for: item, size: size)
    }
}