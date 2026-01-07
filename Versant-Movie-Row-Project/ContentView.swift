//
//  ContentView.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import SwiftUI

/// Main view of the application displaying a Netflix/Vudu-style movie carousel interface.
///
/// **Architecture Decision: MVVM Pattern**
/// - Uses a dedicated ViewModel (MovieDataViewModel) to handle business logic and state management
/// - Keeps the View layer thin and focused on presentation
/// - Makes testing easier by separating concerns
///
/// **Key Features:**
/// - Vertically scrollable list of movie category rows
/// - Each row horizontally scrolls through movie posters
/// - Dynamic poster sizing based on device width
/// - Loading/error states with graceful fallbacks
/// - Lazy loading for performance optimization
struct ContentView: View {
    /// **State Management: @StateObject**
    /// - Using @StateObject ensures the ViewModel survives view recreation
    /// - Alternative @ObservedObject would recreate the ViewModel on each render
    /// - datasetMode: .expanded uses the stress-test dataset (15 rows × 30 movies = 450 total)
    ///   to demonstrate lazy rendering performance at scale
    @StateObject private var viewModel = MovieDataViewModel(datasetMode: .expanded)

    var body: some View {
        /// **Layout Strategy: GeometryReader for Dynamic Sizing**
        /// - Captures available screen width at the parent level
        /// - Passes width down to child views for responsive poster sizing
        /// - Enables consistent layout across different device sizes (iPhone SE to Pro Max, iPad)
        /// - Alternative approaches (hard-coded sizes) would break on different devices
        GeometryReader { geo in
            /// **State-Driven UI: Group for Clean Logic**
            /// - Wraps conditional views in Group to apply shared modifiers later
            /// - Prevents code duplication across different states
            Group {
                /// **Loading State: Progressive Disclosure**
                /// Shows ProgressView while async data loads from bundle
                if viewModel.isLoading {
                    ProgressView("Loading movies...")
                
                /// **Error State: Graceful Failure**
                /// Displays user-friendly error message instead of crashing
                } else if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .multilineTextAlignment(.center)
                        .padding()
                
                /// **Empty State: Edge Case Handling**
                /// Handles scenario where JSON decodes but contains no rows
                } else if viewModel.rows.isEmpty {
                    Text("No movies available")
                        .padding()
                
                /// **Success State: Main Content**
                } else {
                    /// **ScrollView vs List Decision**
                    /// - Plain ScrollView chosen over List for custom layout control
                    /// - Allows nested horizontal ScrollViews within each row
                    /// - List would interfere with gesture recognition on nested scrolls
                    ScrollView {
                        /// **Performance: LazyVStack for Efficient Rendering**
                        /// - Only renders visible rows + small buffer
                        /// - Critical for expanded dataset (450 posters total)
                        /// - Immediate rendering of all rows would cause UI lag on lower-end devices
                        LazyVStack(alignment: .leading, spacing: 20) {
                            /// **ID Strategy: Array Enumeration for Stability**
                            /// - enumerated() gives us (index, element) tuples
                            /// - id: \.offset uses array index as stable identifier
                            /// - Why not use row.id directly?
                            ///   * In expanded dataset, row titles repeat (same 3 titles × 5)
                            ///   * SwiftUI ForEach requires unique IDs
                            ///   * Using index prevents duplicate-ID warnings
                            ///   * Trade-off: if rows reorder, animation may be incorrect
                            ///     (acceptable for this use case where data is static)
                            ForEach(Array(viewModel.rows.enumerated()), id: \.offset) { index, row in
                                /// **Dependency Injection Pattern**
                                /// - Passes device width down to MovieRowView
                                /// - Enables responsive poster sizing without tight coupling
                                /// - Makes unit testing easier (can pass mock widths)
                                MovieRowView(row: row, availableWidth: geo.size.width)

                                /// Only show divider between rows, not after last one
                                if index < viewModel.rows.count - 1 {
                                    Divider()
                                        .overlay(Color.white.opacity(0.18))
                                        .padding(.top, 5)
                                        .padding(.bottom, 5)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        /// **Styling matching design spec**
        /// - preferredColorScheme: forces light mode (assignment requirement)
		.foregroundStyle(Constants.Colors.text)
		.tint(Constants.Colors.text)
		.background(Constants.Colors.background.ignoresSafeArea())
        /// **Data Loading: Swift Concurrency Integration**
        /// - .task modifier runs async code when view appears
        /// - Automatically cancelled when view disappears
        /// - Cleaner than onAppear + Task { } boilerplate
        .task { await viewModel.loadData() }
    }
}

#Preview {
    ContentView()
}
