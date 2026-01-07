//
//  Constants.swift
//  Versant-Movie-Row-Project
//
//  Created by Gregory Young on 1/6/26.
//

import SwiftUI

/// Centralized constants for colors, sizing, and configuration values.
///
/// **Why Constants File:**
/// - Single source of truth for magic numbers
/// - Easier to adjust values without hunting through codebase
/// - Self-documenting (names explain purpose)
/// - Type-safe (compile-time validation)
enum Constants {
	
	// MARK: - Colors
	
	enum Colors {
		/// Main background color: RGB(4, 28, 44) - dark blue-gray
		/// Source: Matched exact design comp via color picker
		static let background = Color(red: 4/255, green: 28/255, blue: 44/255)
		
		/// Text color for category titles and UI elements
		static let text = Color.white
	}
	
	// MARK: - Layout
	
	enum Layout {
		/// Vertical spacing between category rows
		static let rowSpacing: CGFloat = 20
		
		/// Horizontal spacing between movie posters within a row
		static let posterSpacing: CGFloat = 10
		
		/// Horizontal content padding
		static let contentPadding: CGFloat = 16
		
		/// Category title font size
		static let categoryTitleSize: CGFloat = 20
	}
	
	// MARK: - Poster Sizing
	
	enum Poster {
		/// Poster width as percentage of screen width (28%)
		static let widthFactor: CGFloat = 0.28
		
		/// Minimum poster width in points
		static let minWidth: CGFloat = 100
		
		/// Maximum poster width in points (prevents oversized posters on iPad)
		static let maxWidth: CGFloat = 200
		
		/// Standard movie poster aspect ratio (width:height = 390:550)
		static let aspectRatio: CGFloat = 390.0 / 550.0
		
		/// Calculate poster size based on available screen width
		static func size(availableWidth: CGFloat) -> CGSize {
			let targetWidth = availableWidth * widthFactor
			let clampedWidth = min(max(targetWidth, minWidth), maxWidth)
			let height = clampedWidth / aspectRatio
			return CGSize(width: clampedWidth, height: height)
		}
	}
	
	// MARK: - Image Caching
	
	enum Cache {
		/// Memory cache capacity in bytes (50MB)
		/// Holds ~166 posters at 300KB each
		static let memoryCapacity = 50 * 1024 * 1024
		
		/// Disk cache capacity in bytes (100MB)
		/// Holds ~333 posters at 300KB each
		/// Persists across app launches
		static let diskCapacity = 100 * 1024 * 1024
	}
	
	// MARK: - Network
	
	enum Network {
		/// Timeout for image loading requests (30 seconds)
		/// Prevents hanging on slow/broken connections
		static let timeout: TimeInterval = 30
	}
}
