//
//  MoviePosterView.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import SwiftUI

/// Individual movie poster view with async image loading and placeholder fallback.
///
/// **Component Responsibility:**
/// - Displays a single movie poster image
/// - Handles async loading with graceful failure
/// - Shows placeholder for broken/missing URLs
/// - Maintains aspect ratio via dynamic sizing
///
/// **Design Pattern: Stateful Component**
/// - Manages local state for image loading (loadedImage, didFail)
/// - Self-contained loading logic (doesn't pollute parent views)
struct MoviePosterView: View {
	let movie: Movie
	let size: CGSize
	
	/// **Dependency Injection: ImageLoader**
	/// - Uses shared singleton by default for production
	/// - Can be overridden in tests with mock loader
	/// - Enables deterministic testing of cache behavior
	var imageLoader: ImageLoader = .shared

	/// **Local State: Image Loading**
	/// - loadedImage: cached UIImage after successful fetch
	/// - didFail: prevents retry loops on permanent failures
	/// - @State ensures SwiftUI re-renders when values change
	@State private var loadedImage: UIImage? = nil
	@State private var didFail: Bool = false

	/// **Custom Initializer: Flexible Sizing**
	/// - Default size (120×180) for backward compatibility
	/// - Allows parent views to override with dynamic sizing
	/// - imageLoader injection enables testing
	init(movie: Movie, size: CGSize = CGSize(width: 120, height: 180), imageLoader: ImageLoader = .shared) {
		self.movie = movie
		self.size = size
		self.imageLoader = imageLoader
	}

	var body: some View {
		ZStack {
			if let loadedImage {
				/// **Success State: Display Loaded Image**
				Image(uiImage: loadedImage)
					.resizable()
					/// aspectRatio(.fill): scales image to fill frame while maintaining aspect
					/// - Prevents distortion
					/// - May crop edges if aspect doesn't match frame exactly
					.aspectRatio(contentMode: .fill)
			} else {
				/// **Fallback State: Placeholder Image**
				/// - Shows when URL is invalid, empty, or loading failed
				/// - Asset must exist in Assets.xcassets
				Image("movie-poster-placeholder")
					.resizable()
					.aspectRatio(contentMode: .fill)
			}
		}
		.frame(width: size.width, height: size.height)
		/// **Clipping: Prevent Overflow**
		/// - .clipped() prevents image from rendering outside frame bounds
		/// - Critical when using .fill aspect mode (which can overflow)
		.clipped()
		.accessibilityLabel(Text(movie.title))
		
		/// **Async Loading: .task Modifier**
		/// - Runs async closure when view appears
		/// - id: movie.imageURL: re-runs if URL changes (same view, different movie)
		/// - Automatically cancelled if view disappears
		.task(id: movie.imageURL) {
			/// **Guard Clauses: Prevent Redundant Work**
			/// - Don't reload if image already loaded
			/// - Don't retry if previous attempt failed
			/// - Short-circuit on invalid URLs
			guard loadedImage == nil, !didFail else { return }
			guard let url = URL(string: movie.imageURL), !movie.imageURL.isEmpty else {
				didFail = true
				return
			}

			do {
				/// **Async/Await: Clean Concurrency**
				/// - No completion handlers, no pyramid of doom
				/// - Automatic thread management via URLSession
				loadedImage = try await imageLoader.loadImage(from: url)
			} catch {
				/// **Error Handling: Silent Failure**
				/// - Sets didFail to prevent retry loop
				/// - Placeholder remains visible (graceful degradation)
				/// - Could log error in production for debugging
				didFail = true
			}
		}
	}

	/// **Static Factory: Responsive Poster Sizing**
	/// - Moved to Constants.Poster.size(availableWidth:)
	/// - See Constants.swift for sizing logic and rationale
	static func posterSize(availableWidth: CGFloat) -> CGSize {
		Constants.Poster.size(availableWidth: availableWidth)
	}
}

#Preview {
	MoviePosterView(
		movie: Movie(
			title: "Preview Movie",
			imageURL: "https://images2.vudu.com/poster2/176763-168"
		)
	)
}

