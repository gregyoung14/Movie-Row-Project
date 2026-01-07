//
//  MovieDecodingTests.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import XCTest
@preconcurrency @testable import Versant_Movie_Row_Project

/// Tests for JSON decoding of Movie/MovieRow/MovieDataResponse models.
///
/// **Testing Strategy:**
/// - Verify both datasets decode correctly (original: 18 movies, expanded: 450)
/// - Test defensive defaults (missing/null fields don't crash)
/// - Test URL cleaning (< > wrappers stripped)
/// - Test stable IDs (same data decoded twice produces same IDs)
///
/// **Why These Tests Matter:**
/// - Backend data may be unreliable (missing fields, malformed URLs)
/// - App must never crash from bad data
/// - IDs must be stable for SwiftUI animations and diffing
/// - Demonstrates defensive decoding strategy works in practice
final class MovieDecodingTests: XCTestCase {
	/// **Test: Original Dataset Decoding**
	/// - Validates correct structure: 3 rows, 18 total movies
	/// - Verifies metadata: lastUpdated timestamp parsed correctly
	/// - Uses real JSON file from bundle (integration-level test)
	func testDecodeOriginalDataset_countsMatch() throws {
		let data = try TestFixtures.loadProjectInfoJSON(named: "ios_movie_rows_data")
		let decoded = try JSONDecoder().decode(MovieDataResponse.self, from: data)

		XCTAssertEqual(decoded.lastUpdated, "2022-08-19 15:10")
		XCTAssertEqual(decoded.rows.count, 3)
		XCTAssertEqual(decoded.rows.reduce(0) { $0 + $1.movies.count }, 18)
	}

	/// **Test: Expanded Dataset Decoding**
	/// - Validates stress-test dataset: 15 rows, 450 total movies
	/// - Verifies uniform structure: all rows have exactly 30 movies
	/// - Tests performance: can decode large payloads without timeout/crash
	/// - Uses Set to verify all rows have same count (Set([30]) means one unique value)
	func testDecodeExpandedDataset_countsMatch() throws {
		let data = try TestFixtures.loadProjectInfoJSON(named: "ios_movie_rows_data_expanded")
		let decoded = try JSONDecoder().decode(MovieDataResponse.self, from: data)

		XCTAssertEqual(decoded.rows.count, 15)
		XCTAssertEqual(decoded.rows.reduce(0) { $0 + $1.movies.count }, 450)
		XCTAssertEqual(Set(decoded.rows.map { $0.movies.count }), [30])
	}

	/// **Test: Defensive Decoding with Missing/Null Fields**
	/// - last-updated: null → defaults to ""
	/// - row title: missing → defaults to "Category"
	/// - movie title: null → defaults to "Movie Title"
	/// - movie image_url: null → defaults to ""
	/// - URL cleaning: strips < > and whitespace
	///
	/// **Why This Matters:**
	/// - Backend may send incomplete data
	/// - decodeIfPresent prevents crashes from null/missing fields
	/// - App degrades gracefully (shows placeholders instead of crashing)
	func testDefensiveDefaults_missingFieldsDoNotCrash() throws {
		let json = """
		{
		  "last-updated": null,
		  "rows": [
			{
			  "movies": [
				{"image_url": null},
				{"title": null, "image_url": "   <https://example.com/poster>  "}
			  ]
			}
		  ]
		}
		""".data(using: .utf8)!

		let decoded = try JSONDecoder().decode(MovieDataResponse.self, from: json)
		XCTAssertEqual(decoded.lastUpdated, "")
		XCTAssertEqual(decoded.rows.count, 1)
		XCTAssertEqual(decoded.rows[0].title, "Category")
		XCTAssertEqual(decoded.rows[0].movies.count, 2)

		XCTAssertEqual(decoded.rows[0].movies[0].title, "Movie Title")
		XCTAssertEqual(decoded.rows[0].movies[0].imageURL, "")

		XCTAssertEqual(decoded.rows[0].movies[1].title, "Movie Title")
		XCTAssertEqual(decoded.rows[0].movies[1].imageURL, "https://example.com/poster")
	}

	/// **Test: Stable IDs Across Multiple Decodes**
	/// - Same data decoded twice produces identical IDs
	/// - Critical for SwiftUI: stable IDs enable proper animations/diffing
	/// - ID = "\(title)|\(imageURL)" (composite key, deterministic)
	///
	/// **Why This Matters:**
	/// - UUID-based IDs would differ each time (breaks animations)
	/// - Content-based IDs are stable and comparable
	/// - Enables testing equality of decoded objects
	func testStableIDs_decodeTwiceIDsMatch() throws {
		let data = try TestFixtures.loadProjectInfoJSON(named: "ios_movie_rows_data")
		let decoded1 = try JSONDecoder().decode(MovieDataResponse.self, from: data)
		let decoded2 = try JSONDecoder().decode(MovieDataResponse.self, from: data)

		let ids1 = decoded1.rows.flatMap { $0.movies.map(\.id) }
		let ids2 = decoded2.rows.flatMap { $0.movies.map(\.id) }
		XCTAssertEqual(ids1, ids2)
	}
}

/// **Test Fixture Utilities**
///
/// **JSON Loading Strategy:**
/// 1. Try Bundle.main (if JSON files copied to test bundle)
/// 2. Fallback to file system path derived from #filePath
///    * Climbs up from test file location
///    * Navigates to Project-Info folder
///    * Works even if bundle resources not configured
///
/// **Why Two Approaches?**
/// - Xcode test bundle configuration can be inconsistent
/// - #filePath provides reliable fallback (compile-time guarantee)
/// - Tests always work regardless of bundle setup
private enum TestFixtures {
	static func loadProjectInfoJSON(named name: String) throws -> Data {
		if let url = Bundle(for: BundleProbe.self).url(forResource: name, withExtension: "json") {
			return try Data(contentsOf: url)
		}

		// Fallback for when the JSON isn't embedded in the test bundle.
		// Derive the repo-relative location from this test file's path.
		let testsDir = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()

		let url = testsDir
			.appendingPathComponent("Versant-Movie-Row-Project")
			.appendingPathComponent("Project-Info")
			.appendingPathComponent("\(name).json")

		return try Data(contentsOf: url)
	}

	private final class BundleProbe {}
}

