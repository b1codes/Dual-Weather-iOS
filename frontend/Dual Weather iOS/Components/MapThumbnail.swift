//
//  MapThumbnail.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 2/2/25.
//

import MapKit
import SwiftUI

struct MapThumbnailView: View {
    var coordinate: CLLocationCoordinate2D
    var size: CGSize

    @State private var snapshotImage: UIImage?
    @State private var didFail = false
    @State private var snapshotter: MKMapSnapshotter?

    var body: some View {
        Group {
            if let snapshotImage = snapshotImage {
                Image(uiImage: snapshotImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if didFail {
                Image(systemName: "map")
                    .foregroundStyle(.secondary)
                    .frame(width: size.width, height: size.height)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ProgressView()
                    .frame(width: size.width, height: size.height)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onAppear {
                        generateSnapshot()
                    }
            }
        }
        .accessibilityHidden(true)
        .onDisappear {
            snapshotter?.cancel()
        }
    }

    private func generateSnapshot() {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        options.size = size
        options.scale = UIScreen.main.scale

        let snapshotter = MKMapSnapshotter(options: options)
        self.snapshotter = snapshotter
        snapshotter.start { snapshot, _ in
            if let snapshot = snapshot {
                self.snapshotImage = snapshot.image
            } else {
                self.didFail = true
            }
        }
    }
}
