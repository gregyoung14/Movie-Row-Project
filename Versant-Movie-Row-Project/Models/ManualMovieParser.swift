//
//  ManualMovieParser.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import Foundation

/// Alternative JSON parser using JSONSerialization instead of Decodable.
///
/// **Why Two Parsers?**
/// - Primary: Decodable (type-safe, modern, Swift-native)
/// - Backup: JSONSerialization (maximum defensive, handles truly malformed data)
/// - Demonstrates robustness to different parsing strategies
///
/// **Use Cases:**
/// - Backend sends values with unexpected types (e.g., number instead of string)
/// - JSON structure is unpredictable or loosely validated
/// - Need to extract partial data even if some fields are corrupt
///
/// **Trade-offs:**
/// - More verbose than Decodable
/// - Manual type casting (as? Dictionary, as? String)
/// - No automatic CodingKeys mapping (must use literal keys)
/// - More forgiving: returns empty response instead of throwing
///
/// **Safety Strategy:**
/// - as? casting returns nil on type mismatch (no crash)
/// - compactMap filters out nil values (bad movies/rows dropped)
/// - Default values for missing fields
/// - Returns MovieDataResponse (same type as Decodable parser)
enum ManualMovieParser {
	
	/// **Parse JSON Data → MovieDataResponse**
	///
	/// **Flow:**
	/// 1. JSONSerialization → Any (likely [String: Any] dictionary)
	/// 2. Extract "last-updated" (string) and "rows" (array)
	/// 3. Iterate rows, cast each to [String: Any]
	/// 4. Extract title + movies array from each row
	/// 5. Iterate movies, cast each to [String: Any]
	/// 6. Extract title + image_url, pass through Movie initializer (applies cleanURLString)
	/// 7. compactMap filters out any nil values (bad data dropped)
	/// 8. Return MovieDataResponse with defaults if parsing fails
	///
	/// **Error Handling:**
	/// - Catch JSONSerialization errors → return empty response
	/// - as? casts fail silently → return empty response
	/// - Bad movies/rows filtered by compactMap → keep valid data
	static func parse(data: Data) -> MovieDataResponse {
		let jsonObject: Any
		do {
			jsonObject = try JSONSerialization.jsonObject(with: data)
		} catch {
			// **JSONSerialization threw: data not valid JSON**
			// - Return empty response instead of crashing
			// - ViewModel handles empty rows as "No movies available"
			return MovieDataResponse(lastUpdated: "", rows: [])
		}

		guard let root = jsonObject as? [String: Any] else {
			return MovieDataResponse(lastUpdated: "", rows: [])
		}

		let lastUpdated = root["last-updated"] as? String ?? ""
		let rowsArray = root["rows"] as? [Any] ?? []

		// **compactMap: filter out nil values from failed parsing**
		// - If row is missing "title" or "movies", returns nil → dropped
		// - Only fully-formed MovieRows make it to final array
		let rows: [MovieRow] = rowsArray.compactMap { rowAny in
			guard let rowDict = rowAny as? [String: Any] else { return nil }
			let title = rowDict["title"] as? String ?? "Category"

			let moviesArray = rowDict["movies"] as? [Any] ?? []
			
			// **Nested compactMap: filter out bad movies**
			// - If movie missing title/image_url, returns nil → dropped
			// - Row succeeds even if some movies are bad
			let movies: [Movie] = moviesArray.compactMap { movieAny in
				guard let movieDict = movieAny as? [String: Any] else { return nil }
				let movieTitle = movieDict["title"] as? String ?? "Movie Title"
				let rawURL = movieDict["image_url"] as? String ?? ""
				// **Movie initializer applies cleanURLString**
				return Movie(title: movieTitle, imageURL: rawURL)
			}

			return MovieRow(title: title, movies: movies)
		}

		return MovieDataResponse(lastUpdated: lastUpdated, rows: rows)
	}
}

