//
//  MovieRowView.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import SwiftUI

/// Displays a single horizontal row of movie posters with a category title.
///
/// **Component Responsibility:**
/// - Renders category title (e.g., "Big Time Movie Stars")
/// - Horizontal scrollable list of movie posters
/// - Calculates dynamic poster size based on device width
///
/// **Design Pattern: Presentational Component**
/// - Receives all data via props (no direct data fetching)
/// - Reusable across different contexts
/// - Easy to preview in isolation
struct MovieRowView: View {
	/// Passed down from parent ContentView
	/// Immutable (let) since view doesn't mutate data
	let row: MovieRow
	
	/// **Responsive Design: Device Width for Poster Sizing**
	/// - Passed from ContentView's GeometryReader
	/// - Enables responsive poster sizing across iPhone/iPad
	/// - Could alternatively use @Environment(\.horizontalSizeClass) but explicit passing
	///   gives more control and makes testing easier
	let availableWidth: CGFloat

	/// **Computed Property: Dynamic Poster Sizing**
	/// - Calculates poster dimensions based on available screen width
	/// - Private because it's an implementation detail
	/// - Called once per render, result used by all posters in this row
	private var posterSize: CGSize {
		MoviePosterView.posterSize(availableWidth: availableWidth)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(row.title)
				.font(.headline.weight(.light))
				.foregroundStyle(.white)
				.padding(.bottom, 20)

			ScrollView(.horizontal, showsIndicators: false) {
				/// **Performance: LazyHStack for Efficient Rendering**
				/// - Only renders visible posters + small buffer
				/// - Critical when rows have 30 posters (expanded dataset)
				/// - Alternative HStack would render all 30 immediately (wasteful)
				LazyHStack(alignment: .top, spacing: 12) {
					/// **ID Strategy: Index-Based for Duplicate Movies**
					/// - enumerated() provides (offset, element) tuples
					/// - id: \.offset uses array index as unique identifier
					/// - Why not use movie.id?
					///   * Same movie appears multiple times in expanded dataset
					///   * movie.id = "title|url" would create duplicates
					///   * Using index prevents SwiftUI duplicate-ID warnings
					///   * Trade-off: if movies reorder, animation may glitch
					///     (acceptable since data is static in this app)
					ForEach(Array(row.movies.enumerated()), id: \.offset) { _, movie in
						/// Pass calculated size down; all posters in row are same size
						MoviePosterView(movie: movie, size: posterSize)
					}
				}
			}
		}
	}
}

#Preview {
	MovieRowView(
		row: MovieRow(
			title: "Preview Row",
			movies: [
				Movie(title: "Movie 1", imageURL: "https://images2.vudu.com/poster2/176763-168"),
				Movie(title: "Movie 2", imageURL: "https://images2.vudu.com/poster2/739772-168")
			]
		),
		availableWidth: 430
	)
}

