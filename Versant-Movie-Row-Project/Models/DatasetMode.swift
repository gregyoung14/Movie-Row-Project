//
//  DatasetMode.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

/// Defines available dataset configurations for the application.
///
/// **Purpose:**
/// - Enables switching between original and expanded datasets at compile-time
/// - Provides type-safe filename mapping
/// - Currently set to .expanded for stress testing (450 movies)
///
/// **Why enum instead of String constant?**
/// - Type safety: compiler prevents typos
/// - Exhaustive switching: ensures all cases handled
/// - Easy to add new datasets (e.g., .small, .huge)
///
/// **Datasets:**
/// - original: 3 rows × 6 movies = 18 total
///   * Provided by client as initial test data
///   * File: ios_movie_rows_data.json
/// - expanded: 15 rows × 30 movies = 450 total
///   * Stress test for performance/memory
///   * Tests LazyVStack/LazyHStack efficiency
///   * File: ios_movie_rows_data_expanded.json
///
/// **Note on Expanded Dataset:**
/// - Contains duplicate movies/rows (repeated 5x)
/// - Caused duplicate ForEach ID warnings until we switched to index-based IDs
/// - Mimics real-world scenario where backend repeats content
enum DatasetMode {
	case original
	case expanded

	/// **Filename Mapping**
	/// - Centralizes JSON filename logic
	/// - Bundle.main.path(forResource:) requires filename without extension
	/// - Single source of truth for dataset → file mapping
	var filename: String {
		switch self {
		case .original:
			return "ios_movie_rows_data"
		case .expanded:
			return "ios_movie_rows_data_expanded"
		}
	}
}

