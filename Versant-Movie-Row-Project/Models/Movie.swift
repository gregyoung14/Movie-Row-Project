//
//  Movie.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import Foundation

/// Represents a single movie with title and poster image URL.
///
/// **Design Decisions:**
/// - Decodable: JSON deserialization with defensive defaults
/// - Identifiable: enables SwiftUI ForEach without manual id specification
/// - Equatable/Hashable: enables efficient diffing and Set operations
///
/// **Defensive Decoding Philosophy:**
/// - Backend data may be unreliable (missing fields, wrong types, malformed URLs)
/// - App should never crash due to bad data
/// - Decode with sensible defaults instead of throwing errors
///
/// **Sendable Conformance:**
/// - Pure value type (struct with let properties)
/// - Safe to pass across concurrency domains
/// - Enables concurrent decoding and processing
struct Movie: Decodable, Identifiable, Equatable, Hashable, Sendable {
	let title: String
	let imageURL: String

	/// **ID Strategy: Composite Key**
	/// - Combines title + imageURL for uniqueness
	/// - Why not UUID?
	///   * Unstable across decodes (would break SwiftUI animations)
	///   * Can't compare Movies decoded at different times
	/// - Why not title alone?
	///   * Same movie could theoretically have different poster URLs
	///   * Expanded dataset has duplicate titles with same URLs
	/// - Pipe separator chosen for human readability in debugging
	var id: String { "\(title)|\(imageURL)" }

	/// **JSON Key Mapping**
	/// - Backend uses snake_case (image_url)
	/// - Swift convention is camelCase (imageURL)
	/// - CodingKeys bridges the gap
	enum CodingKeys: String, CodingKey {
		case title
		case imageURL = "image_url"
	}

	/// **Custom Decoder: Defensive Defaults**
	///
	/// **Why custom init(from:) instead of automatic synthesis?**
	/// - Automatic Decodable throws if field is missing/null
	/// - We want graceful fallback to default values
	/// - decodeIfPresent returns nil instead of throwing
	///
	/// **Defaults:**
	/// - title: "Movie Title" (visible placeholder in UI)
	/// - imageURL: "" (empty string triggers placeholder image)
	///
	/// **URL Cleaning:**
	/// - Some URLs in provided JSON had < > wrappers
	/// - cleanURLString strips these and whitespace
	/// - Prevents URL(string:) from returning nil
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Movie Title"

		let rawURL = try container.decodeIfPresent(String.self, forKey: .imageURL) ?? ""
		imageURL = Self.cleanURLString(rawURL)
	}

	/// **Memberwise Initializer: Testing/Previews**
	/// - SwiftUI previews need to construct Movies manually
	/// - Tests need to create fixtures without JSON
	/// - Also applies cleanURLString for consistency
	init(title: String, imageURL: String) {
		self.title = title
		self.imageURL = Self.cleanURLString(imageURL)
	}

	/// **URL Sanitization**
	/// - Strips < > characters (found in some backend data)
	/// - Trims leading/trailing whitespace
	/// - Static method: can be called from both initializers
	static func cleanURLString(_ value: String) -> String {
		value.trimmingCharacters(in: CharacterSet(charactersIn: "<>").union(.whitespacesAndNewlines))
	}
}

