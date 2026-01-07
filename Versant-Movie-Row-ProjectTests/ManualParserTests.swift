//
//  ManualParserTests.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import XCTest
@preconcurrency @testable import Versant_Movie_Row_Project

/// Tests for ManualMovieParser (JSONSerialization-based alternative parser).
///
/// **Testing Strategy:**
/// - Verify successful parsing of valid JSON (same output as Decodable)
/// - Test robustness to wrong types (number instead of string)
/// - Test handling of NSNull, missing fields, malformed structures
/// - Verify compactMap filters out bad data without crashing
///
/// **Why ManualMovieParser Exists:**
/// - Demonstrates maximum defensive parsing
/// - Handles truly malformed data that Decodable would reject
/// - Shows alternative approach: as? casting vs decode throwing
/// - Useful for backends with inconsistent type discipline
final class ManualParserTests: XCTestCase {
	/// **Test: Valid JSON Parsing**
	/// - ManualMovieParser should produce same output as Decodable
	/// - 3 rows, 18 movies, correct timestamp
	/// - Validates that JSONSerialization approach works for well-formed data
	func testManualParser_validParse() throws {
		let data = try TestFixtures.loadProjectInfoJSON(named: "ios_movie_rows_data")
		let parsed = ManualMovieParser.parse(data: data)

		XCTAssertEqual(parsed.rows.count, 3)
		XCTAssertEqual(parsed.rows.reduce(0) { $0 + $1.movies.count }, 18)
		XCTAssertEqual(parsed.lastUpdated, "2022-08-19 15:10")
	}

	/// **Test: Wrong Types and Missing Fields**
	/// - last-updated: 123 (number, not string) → as? String fails → default ""
	/// - row title: NSNull() → as? String fails → default "Category"
	/// - movie title: 99 (number) → as? String fails → default "Movie Title"
	/// - movie image_url: NSNull() → as? String fails → default ""
	/// - movie 2: missing title key → uses default "Movie Title"
	/// - movie 3: "not a movie" (string, not dict) → as? [String: Any] fails → compactMap filters out
	/// - row 2: "not a row" (string) → as? [String: Any] fails → compactMap filters out
	///
	/// **Result:**
	/// - 1 valid row with 2 valid movies (movie 3 dropped, row 2 dropped)
	/// - URL cleaning applied: "< https://example.com/a >" → "https://example.com/a"
	func testManualParser_defaultsForMissingOrWrongTypes() {
		let json: [String: Any] = [
			"last-updated": 123,
			"rows": [
				[
					"title": NSNull(),
					"movies": [
						["title": 99, "image_url": NSNull()],
						["image_url": " <https://example.com/a>  "],
						"not a movie"
					]
				],
				"not a row"
			]
		]

		let data = try! JSONSerialization.data(withJSONObject: json)
		let parsed = ManualMovieParser.parse(data: data)

		XCTAssertEqual(parsed.lastUpdated, "")
		XCTAssertEqual(parsed.rows.count, 1)

		let row = parsed.rows[0]
		XCTAssertEqual(row.title, "Category")
		XCTAssertEqual(row.movies.count, 2)

		XCTAssertEqual(row.movies[0].title, "Movie Title")
		XCTAssertEqual(row.movies[0].imageURL, "")

		XCTAssertEqual(row.movies[1].title, "Movie Title")
		XCTAssertEqual(row.movies[1].imageURL, "https://example.com/a")
	}

	/// **Test: Malformed Root Structure**
	/// - JSON is valid but root is array instead of dictionary
	/// - as? [String: Any] fails
	/// - Returns empty response instead of crashing
	/// - Demonstrates maximum defensive strategy: always succeed, return empty
	func testManualParser_malformedRootDoesNotCrash_returnsEmpty() {
		let data = Data("[1,2,3]".utf8)
		let parsed = ManualMovieParser.parse(data: data)
		XCTAssertEqual(parsed.lastUpdated, "")
		XCTAssertTrue(parsed.rows.isEmpty)
	}
}

private enum TestFixtures {
	static func loadProjectInfoJSON(named name: String) throws -> Data {
		if let url = Bundle(for: BundleProbe.self).url(forResource: name, withExtension: "json") {
			return try Data(contentsOf: url)
		}

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

