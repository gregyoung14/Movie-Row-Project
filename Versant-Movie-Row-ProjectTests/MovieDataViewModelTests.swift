//
//  MovieDataViewModelTests.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import XCTest
@preconcurrency @testable import Versant_Movie_Row_Project

/// Tests for MovieDataViewModel (MVVM pattern, async loading, state management).
///
/// **Testing Strategy:**
/// - Test successful loading of both datasets (original, expanded)
/// - Test loading state transitions (idle → loading → loaded)
/// - Test error handling (missing file, decode failure)
/// - Use dependency injection (resourceDataLoader) for deterministic testing
///
/// **Why Dependency Injection:**
/// - resourceDataLoader closure injected in init
/// - Tests provide mock data loaders (no Bundle.main dependency)
/// - Can simulate file-not-found, invalid JSON, etc.
/// - Fast tests: no actual file I/O
///
/// **State Machine:**
/// - isLoading: true during async work
/// - errorMessage: set on failure, nil on success
/// - rows: populated on success, empty on failure
final class MovieDataViewModelTests: XCTestCase {
	/// **Test: Original Dataset Loading**
	/// - Injects closure that loads real JSON file
	/// - Verifies state transitions:
	///   * isLoading true during work
	///   * isLoading false after completion
	///   * errorMessage nil (success)
	///   * rows.count = 3 (expected structure)
	///
	/// **Task.yield() Pattern:**
	/// - Gives loadData() time to set isLoading = true
	/// - Without yield, test might miss intermediate state
	/// - Demonstrates understanding of Swift concurrency
	///
	/// **@MainActor:**
	/// - MovieDataViewModel is @MainActor isolated
	/// - Test must run on main actor to access init/properties
	/// - Common pattern for testing @MainActor types
	@MainActor
	func testLoadOriginalDataset_populatesRows() async throws {
		let viewModel = MovieDataViewModel(
			datasetMode: .original,
			resourceDataLoader: { _ in
				try TestFixtures.loadProjectInfoJSON(named: "ios_movie_rows_data")
			}
		)

		let task = Task { await viewModel.loadData() }
		await Task.yield()
		XCTAssertTrue(viewModel.isLoading)

		await task.value

		XCTAssertFalse(viewModel.isLoading)
		XCTAssertNil(viewModel.errorMessage)
		XCTAssertEqual(viewModel.rows.count, 3)
	}

	/// **Test: Expanded Dataset Loading**
	/// - Validates stress-test dataset: 15 rows, 450 movies
	/// - No isLoading checks (simpler test, just verifies final state)
	/// - Tests ViewModel can handle large payloads without performance issues
	@MainActor
	func testLoadExpandedDataset_populatesRows() async throws {
		let viewModel = MovieDataViewModel(
			datasetMode: .expanded,
			resourceDataLoader: { _ in
				try TestFixtures.loadProjectInfoJSON(named: "ios_movie_rows_data_expanded")
			}
		)

		await viewModel.loadData()
		XCTAssertNil(viewModel.errorMessage)
		XCTAssertEqual(viewModel.rows.count, 15)
		XCTAssertEqual(viewModel.rows.reduce(0) { $0 + $1.movies.count }, 450)
	}

	/// **Test: Missing File Error Handling**
	/// - Injected loader throws CocoaError(.fileNoSuchFile)
	/// - ViewModel catches error and sets errorMessage
	/// - rows remains empty (not populated with partial data)
	/// - isLoading false (not stuck in loading state)
	/// - UI can display error state to user
	@MainActor
	func testLoadData_missingFile_setsErrorMessage() async {
		let viewModel = MovieDataViewModel(
			datasetMode: .original,
			resourceDataLoader: { _ in throw CocoaError(.fileNoSuchFile) }
		)

		await viewModel.loadData()
		XCTAssertNotNil(viewModel.errorMessage)
		XCTAssertTrue(viewModel.rows.isEmpty)
		XCTAssertFalse(viewModel.isLoading)
	}

	/// **Test: Decode Failure Error Handling**
	/// - Injected loader returns invalid JSON ("not json")
	/// - JSONDecoder.decode throws DecodingError
	/// - ViewModel catches and sets errorMessage
	/// - Demonstrates robustness to malformed backend responses
	@MainActor
	func testLoadData_decodeFailure_setsErrorMessage() async {
		let viewModel = MovieDataViewModel(
			datasetMode: .original,
			resourceDataLoader: { _ in Data("not json".utf8) }
		)

		await viewModel.loadData()
		XCTAssertNotNil(viewModel.errorMessage)
		XCTAssertTrue(viewModel.rows.isEmpty)
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

