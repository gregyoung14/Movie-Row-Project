//
//  MovieDataViewModel.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import Foundation
import Combine

/// ViewModel responsible for loading and managing movie data from JSON bundles.
///
/// **Architecture: MVVM Pattern**
/// - Separates business logic from UI
/// - Publishes state changes via Combine (@Published)
/// - Testable: can inject mock data loaders
///
/// **Concurrency Model:**
/// - @MainActor: ensures all mutations happen on main thread
/// - Required for @Published properties that drive UI updates
/// - Prevents race conditions and threading bugs
@MainActor
final class MovieDataViewModel: ObservableObject {
	/// **Published State: UI Bindings**
	/// - rows: successfully loaded movie categories
	/// - isLoading: triggers progress indicator in UI
	/// - errorMessage: drives error display, nil when successful
	/// - @Published automatically notifies SwiftUI views of changes
	@Published var rows: [MovieRow] = []
	@Published var isLoading: Bool = false
	@Published var errorMessage: String? = nil

	private let datasetMode: DatasetMode
	private let bundle: Bundle
	
	/// **Testability: Injected Resource Loader**
	/// - Default implementation searches bundle for JSON files
	/// - Tests can inject mock data without touching file system
	/// - Enables deterministic testing of success/failure paths
	private let resourceDataLoader: (String) throws -> Data

	/// **Initialization: Dependency Injection**
	/// - datasetMode: switches between original (18 movies) and expanded (450 movies)
	/// - bundle: usually .main, but tests can inject custom bundles
	/// - resourceDataLoader: optional override for testing
	///
	/// **Default Resource Loader Strategy:**
	/// 1. Try provided bundle first
	/// 2. Fall back to Bundle.main (handles different bundle structures)
	/// 3. Fall back to Bundle(for: Class) (handles test bundle edge cases)
	/// 4. Throw if file not found in any candidate
	init(
		datasetMode: DatasetMode,
		bundle: Bundle = .main,
		resourceDataLoader: ((String) throws -> Data)? = nil
	) {
		self.datasetMode = datasetMode
		self.bundle = bundle
		self.resourceDataLoader = resourceDataLoader ?? { filename in
			let candidates: [Bundle] = [bundle, Bundle.main, Bundle(for: MovieDataViewModel.self)]
			for candidate in candidates {
				if let url = candidate.url(forResource: filename, withExtension: "json") {
					return try Data(contentsOf: url)
				}
			}
			throw CocoaError(.fileNoSuchFile)
		}
	}

	/// **Async Data Loading**
	/// - Called from ContentView's .task modifier
	/// - Updates published properties to drive UI state
	///
	/// **State Machine:**
	/// 1. Set isLoading = true (shows ProgressView)
	/// 2. Clear previous state (rows, errorMessage)
	/// 3. Attempt to load & decode JSON
	/// 4. Set success/error state based on outcome
	/// 5. Set isLoading = false (hides ProgressView)
	func loadData() async {
		isLoading = true
		errorMessage = nil
		rows = []

		do {
			let data = try resourceDataLoader(datasetMode.filename)
			let response = try await decodeResponseOffMain(data)

			if response.rows.isEmpty {
				errorMessage = "No movies available"
				rows = []
			} else {
				rows = response.rows
			}
		} catch {
			errorMessage = "Failed to load movies"
			rows = []
		}

		isLoading = false
	}

	/// **Off-Main Decoding: Performance Optimization**
	///
	/// **Problem:** JSONDecoder.decode() is CPU-intensive
	/// - Expanded dataset (450 movies) can take 10-50ms to decode
	/// - Running on main thread would block UI rendering
	/// - User would see frame drops during initial load
	///
	/// **Solution:** Decode on background queue via DispatchQueue
	/// - withCheckedThrowingContinuation: bridges callback-based DispatchQueue to async/await
	/// - DispatchQueue.global(qos: .userInitiated): background thread with appropriate priority
	/// - Result/error passed back to main actor automatically via continuation
	///
	/// **Why not Task.detached?**
	/// - Swift 6 concurrency restrictions around Sendable
	/// - MovieDataResponse is Decodable, not explicitly Sendable
	/// - DispatchQueue approach is more compatible with current Swift version
	///
	/// **Trade-off:**
	/// - Adds complexity (continuation boilerplate)
	/// - Benefit: smoother UI during load (no jank)
	/// - For tiny datasets, overhead not worth it, but doesn't hurt
	///
	/// **nonisolated:**
	/// - Explicitly declares this runs off main actor
	/// - MovieDataResponse is Sendable (safe to decode anywhere)
	/// - Prevents Swift 6 actor isolation inference issues
	private nonisolated func decodeResponseOffMain(_ data: Data) async throws -> MovieDataResponse {
		try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				do {
					let response = try JSONDecoder().decode(MovieDataResponse.self, from: data)
					continuation.resume(returning: response)
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}
}
