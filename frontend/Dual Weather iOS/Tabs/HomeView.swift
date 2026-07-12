//
//  HomeView.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 1/26/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = WeatherViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    if let location = viewModel.currentLocation {
                        WeatherDetailsView(locationName: location, coordinate: viewModel.currentCLLocation?.coordinate)
                    } else if let error = viewModel.locationError {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
                .safeAreaInset(edge: .top) {
                    EmptyView()
                }
            }
            .navigationTitle("Current Weather")
            .navigationBarTitleDisplayMode(.automatic)
            .refreshable {
                await viewModel.refreshCurrentWeather()
            }
        }
        .onAppear {
            viewModel.requestLocation()
        }
    }
}

#Preview {
    HomeView()
}
