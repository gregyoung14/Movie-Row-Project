//
//  ImageLoader.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import Foundation
import UIKit

/// Async image loader with native URLCache-backed caching.
///
/// **Design Pattern: Singleton + Dependency Injection**
/// - .shared singleton for production use (convenient, efficient)
/// - Custom instances for testing (injectable cache/session)
///
/// **Caching Strategy:**
/// - Uses URLCache (native iOS caching mechanism)
/// - Respects HTTP cache headers from server
/// - Fallback: .returnCacheDataElseLoad policy ensures caching even without headers
/// - Memory + disk cache for performance across app launches
final class ImageLoader {
	/// **Shared Singleton**
	/// - Single instance shared across all MoviePosterViews
	/// - Prevents duplicate URLSession instances (memory efficient)
	/// - Shares cache across all image requests (bandwidth efficient)
	static let shared = ImageLoader()

	/// **Exposed for Testing**
	/// - Tests can inspect cache contents
	/// - Tests can pre-seed cache for deterministic behavior
	let cache: URLCache
	
	private let session: URLSession

	/// **Initialization: Configurable Caching**
	/// - configuration: URLSessionConfiguration (ephemeral for tests, default for production)
	/// - cache: optional override for testing (can inject memory-only cache)
	///
	/// **Cache Sizing:**
	/// - Memory: 50MB (fast, but cleared on app termination)
	/// - Disk: 100MB (persistent across launches)
	/// - Sized for ~200-300 poster images (typical usage)
	///
	/// **Cache Policy: .returnCacheDataElseLoad**
	/// - Check cache first, network only if not found
	/// - Respects cache expiration headers if present
	/// - Graceful degradation: works even with broken network
	init(configuration: URLSessionConfiguration = .default, cache: URLCache? = nil) {
		let cacheToUse = cache ?? URLCache(
			memoryCapacity: 50 * 1024 * 1024,
			diskCapacity: 100 * 1024 * 1024
		)

		configuration.urlCache = cacheToUse
		configuration.requestCachePolicy = .returnCacheDataElseLoad

		self.cache = cacheToUse
		self.session = URLSession(configuration: configuration)
	}

	/// **Async Image Loading**
	/// - Returns UIImage on success, throws on failure
	/// - Automatically uses cache if available
	///
	/// **Flow:**
	/// 1. Check URLCache (memory → disk → network)
	/// 2. Download if not cached
	/// 3. Validate HTTP response (200-299 status codes)
	/// 4. Decode data into UIImage
	/// 5. Throw if any step fails
	///
	/// **Error Handling:**
	/// - Invalid URL: caller handles before calling this
	/// - Network failure: URLError propagates up
	/// - Invalid image data: throws .badServerResponse
	/// - Non-2xx status: throws .badServerResponse
	///
	/// **Why URLRequest instead of session.data(from: URL)?**
	/// - Explicit cache policy per request
	/// - Timeout control (30s prevents hanging on slow connections)
	/// - Could add custom headers if needed (authorization, etc.)
	func loadImage(from url: URL) async throws -> UIImage {
		let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: Constants.Network.timeout)
		let (data, response) = try await session.data(for: request)

		guard
			let http = response as? HTTPURLResponse,
			(200...299).contains(http.statusCode),
			let image = UIImage(data: data)
		else {
			throw URLError(.badServerResponse)
		}

		return image
	}
}

