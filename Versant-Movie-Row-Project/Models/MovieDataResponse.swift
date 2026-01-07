//
//  MovieDataResponse.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import Foundation

/// Root structure representing the entire JSON response.
///
/// **Design Decisions:**
/// - Decodable: JSON deserialization with defensive defaults
/// - Equatable: enables testing (compare decoded results)
/// - Not Identifiable: root object doesn't need SwiftUI ForEach
///
/// **Structure:**
/// - lastUpdated: metadata timestamp from JSON (not currently displayed in UI)
/// - rows: array of category rows (main data payload)
///
/// **Sendable Conformance:**
/// - Pure value type (struct with let properties)
/// - Safe to pass across concurrency domains
/// - Prevents Swift 6 main actor isolation inference
struct MovieDataResponse: Decodable, Equatable, Sendable {
	let lastUpdated: String
	let rows: [MovieRow]

	/// **JSON Key Mapping**
	/// - Backend uses hyphenated key (last-updated)
	/// - Swift convention is camelCase (lastUpdated)
	/// - CodingKeys bridges the naming difference
	enum CodingKeys: String, CodingKey {
		case lastUpdated = "last-updated"
		case rows
	}

	/// **Custom Decoder: Defensive Defaults**
	///
	/// **Defaults:**
	/// - lastUpdated: "" if missing/null (metadata not critical)
	/// - rows: empty array if missing/null
	///
	/// **Why decodeIfPresent instead of decode?**
	/// - Backend data could have missing/null fields
	/// - App should degrade gracefully, not crash
	/// - Empty rows triggers "No movies available" UI state
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		lastUpdated = try container.decodeIfPresent(String.self, forKey: .lastUpdated) ?? ""
		rows = try container.decodeIfPresent([MovieRow].self, forKey: .rows) ?? []
	}

	/// **Memberwise Initializer: Testing**
	/// - Tests construct responses without JSON
	/// - ViewModel tests inject mock responses
	init(lastUpdated: String, rows: [MovieRow]) {
		self.lastUpdated = lastUpdated
		self.rows = rows
	}
}

