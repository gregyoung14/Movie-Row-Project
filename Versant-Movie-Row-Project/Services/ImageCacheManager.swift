//
//  ImageCacheManager.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import Foundation

/// Wrapper around URLCache for testing and inspection.
///
/// **Purpose:**
/// - Provides testable interface to URLCache
/// - Enables cache inspection in unit tests
/// - Allows cache pre-seeding for deterministic tests
///
/// **Why Wrapper Instead of Direct URLCache Access?**
/// - URLCache is global state (hard to isolate in tests)
/// - Tests need to verify caching behavior without side effects
/// - Can inject custom cache for testing without network calls
///
/// **Usage:**
/// - Production: ImageLoader gets URLCache via session configuration
/// - Tests: Create ImageCacheManager with custom URLCache
///   * Can pre-seed with CachedURLResponse objects
///   * Can verify cache hits/misses after operations
///
/// **Testing Strategies:**
/// 1. Pre-seed cache with known responses
/// 2. Load image via ImageLoader
/// 3. Assert cachedResponse(for:) returns expected data
/// 4. Assert no network calls made (all cache hits)
///
/// **Default Configuration:**
/// - 50MB memory capacity (~166 cached posters at 300KB each)
/// - 100MB disk capacity (~333 cached posters)
/// - Matches ImageLoader configuration for consistency
final class ImageCacheManager {
	let cache: URLCache

	/// **Dependency Injection Constructor**
	/// - Accepts any URLCache instance
	/// - Tests can pass custom cache with desired configuration
	/// - Enables isolated testing without affecting global cache
	/// - Default capacity matches ImageLoader's configuration
	init(cache: URLCache = URLCache(
		memoryCapacity: 50 * 1024 * 1024,
		diskCapacity: 100 * 1024 * 1024
	)) {
		self.cache = cache
	}

	/// **Retrieve Response from Cache**
	/// - Wraps URLCache.cachedResponse(for:)
	/// - Tests use this to verify caching behavior
	/// - Returns nil if no cached response exists
	func cachedResponse(for request: URLRequest) -> CachedURLResponse? {
		cache.cachedResponse(for: request)
	}

	/// **Store Response in Cache**
	/// - Wraps URLCache.storeCachedResponse(_:for:)
	/// - Tests use this to pre-seed known responses
	func store(_ cachedResponse: CachedURLResponse, for request: URLRequest) {
		cache.storeCachedResponse(cachedResponse, for: request)
	}

	/// **Clear All Cached Responses**
	/// - Wraps URLCache.removeAllCachedResponses()
	/// - Tests use this in setUp/tearDown for isolation
	func removeAll() {
		cache.removeAllCachedResponses()
	}
}

