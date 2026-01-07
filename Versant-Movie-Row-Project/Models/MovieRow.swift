//
//  MovieRow.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import Foundation

/// Represents a category row containing a title and list of movies.
///
/// **Design Decisions:**
/// - Decodable: JSON deserialization with defensive defaults
/// - Identifiable: enables SwiftUI ForEach
/// - Equatable/Hashable: enables efficient diffing
///
/// **Structure:**
/// - title: Category name (e.g., "Big Time Movie Stars")
/// - movies: Array of Movie objects
///
/// **Sendable Conformance:**
/// - Pure value type (struct with let properties)
/// - Safe to pass across concurrency domains
struct MovieRow: Decodable, Identifiable, Equatable, Hashable, Sendable {
	let title: String
	let movies: [Movie]

	/// **ID Strategy: Use Title as Identifier**
	/// - Assumes category titles are unique within a dataset
	/// - Valid for original dataset (3 unique titles)
	/// - Breaks in expanded dataset (titles repeat 5x)
	///   * Workaround: parent ContentView uses array index instead
	///   * This id still useful for debugging/logging
	var id: String { title }

	enum CodingKeys: String, CodingKey {
		case title
		case movies
	}

	/// **Custom Decoder: Defensive Defaults**
	///
	/// **Defaults:**
	/// - title: "Category" if missing/null
	/// - movies: empty array if missing/null
	///
	/// **Why empty array instead of throwing?**
	/// - Backend could send malformed row
	/// - Better to show empty row than crash entire app
	/// - UI handles empty arrays gracefully (no posters shown)
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Category"
		movies = try container.decodeIfPresent([Movie].self, forKey: .movies) ?? []
	}

	/// **Memberwise Initializer: Testing/Previews**
	/// - SwiftUI previews construct MovieRows manually
	/// - Tests create fixtures without JSON
	init(title: String, movies: [Movie]) {
		self.title = title
		self.movies = movies
	}
}

