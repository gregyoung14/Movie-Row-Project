#Movie Row Project

A SwiftUI implementation of a Netflix/Vudu-style movie carousel interface with optimized performance, defensive data handling, and comprehensive testing.

## Overview

This project demonstrates a production-ready movie browsing UI featuring:
- **Horizontal scrolling rows** of movie posters organized by category
- **Async image loading** with intelligent caching (50MB memory, 100MB disk)
- **Defensive JSON decoding** that never crashes on malformed data
- **Dynamic responsive sizing** that scales to any device
- **LazyVStack/LazyHStack** for efficient rendering of 450+ posters
- **Comprehensive unit tests** validating defensive strategies

## Architecture

### MVVM Pattern

```
┌─────────────────┐
│   ContentView   │  ← SwiftUI view layer (state-driven UI)
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│  MovieDataViewModel     │  ← @MainActor, manages state & async loading
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  MovieDataResponse      │  ← Decodable models with defensive defaults
│  MovieRow               │
│  Movie                  │
└─────────────────────────┘
```

**Design Rationale:**
- **Separation of concerns**: Views render, ViewModel manages state, Models hold data
- **Testability**: ViewModel uses dependency injection for deterministic testing
- **SwiftUI best practices**: @Published properties drive UI updates automatically

### Project Structure

```
Versant-Movie-Row-Project/
├── Models/
│   ├── Movie.swift                    # Individual movie with defensive decoding
│   ├── MovieRow.swift                 # Category row container
│   ├── MovieDataResponse.swift        # Root JSON structure
│   ├── DatasetMode.swift              # Dataset switching (original/expanded)
│   └── ManualMovieParser.swift        # Alternative JSONSerialization parser
├── ViewModels/
│   └── MovieDataViewModel.swift       # MVVM state management (@MainActor)
├── Views/
│   ├── ContentView.swift              # Root view with GeometryReader
│   ├── MovieRowView.swift             # Horizontal scrolling row
│   └── MoviePosterView.swift          # Individual poster with async loading
├── Services/
│   ├── ImageLoader.swift              # URLCache-backed image fetching
│   └── ImageCacheManager.swift        # URLCache wrapper for testing
└── Project-Info/
    ├── ios_movie_rows_data.json       # 3 rows × 6 movies = 18 total
    └── ios_movie_rows_data_expanded.json  # 15 rows × 30 movies = 450 total
```

## Key Features

### 1. Defensive JSON Decoding

**Problem:** Backend data is unreliable (missing fields, wrong types, malformed URLs).

**Solution:** Custom `init(from:)` with `decodeIfPresent` and sensible defaults.

```swift
struct Movie: Decodable, Identifiable, Sendable {
    let title: String
    let imageURL: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Never crash on null/missing fields - use defaults
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Movie Title"
        
        let rawURL = try container.decodeIfPresent(String.self, forKey: .imageURL) ?? ""
        imageURL = Self.cleanURLString(rawURL)  // Strip < > wrappers
    }
    
    // Stable composite ID for SwiftUI animations
    var id: String { "\(title)|\(imageURL)" }
}
```

**Benefits:**
- App never crashes from bad data
- Graceful degradation (shows placeholders instead of white screens)
- Stable IDs enable smooth SwiftUI animations

### 2. Off-Main-Thread JSON Decoding

**Problem:** Decoding 450 movies on main thread causes UI jank.

**Solution:** DispatchQueue-based background decoding with continuation.

```swift
@MainActor
final class MovieDataViewModel: ObservableObject {
    @Published var rows: [MovieRow] = []
    @Published var isLoading = false
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try resourceDataLoader(datasetMode.filename)
            
            // Decode off main thread for smooth UI
            let response = try await decodeResponseOffMain(data)
            rows = response.rows
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
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
```

**Why DispatchQueue instead of Task.detached?**
- Swift 6 requires `Sendable` conformance for `Task.detached`
- DispatchQueue + continuation pattern is more compatible
- Performance equivalent for this use case

### 3. Intelligent Image Caching

**Problem:** Loading 450 posters over network is slow and wasteful.

**Solution:** URLCache with aggressive memory/disk allocation.

```swift
final class ImageLoader {
    static let shared = ImageLoader()
    
    private let session: URLSession
    
    init(configuration: URLSessionConfiguration = .default, 
         cache: URLCache? = nil) {
        let urlCache = cache ?? URLCache(
            memoryCapacity: 50 * 1024 * 1024,   // 50MB (~166 posters @ 300KB each)
            diskCapacity: 100 * 1024 * 1024     // 100MB (~333 posters)
        )
        
        configuration.urlCache = urlCache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: configuration)
    }
    
    func loadImage(from url: URL) async throws -> UIImage {
        // URLCache automatically checks memory → disk → network
        let request = URLRequest(url: url, 
                                cachePolicy: .returnCacheDataElseLoad, 
                                timeoutInterval: 30)
        let (data, _) = try await session.data(for: request)
        
        guard let image = UIImage(data: data) else {
            throw URLError(.badServerResponse)
        }
        return image
    }
}
```

**Benefits:**
- Instant loads after first fetch (memory cache)
- Persistent across app launches (disk cache)
- Standard HTTP cache headers respected

### 4. Dynamic Responsive Poster Sizing

**Problem:** Fixed sizes don't adapt to different device widths.

**Solution:** GeometryReader + static factory method with aspect ratio.

```swift
struct ContentView: View {
    @StateObject private var viewModel = MovieDataViewModel(datasetMode: .expanded)
    
    var body: some View {
        GeometryReader { geometry in
            LazyVStack(spacing: 20) {
                ForEach(Array(viewModel.rows.enumerated()), id: \.offset) { index, row in
                    MovieRowView(
                        row: row,
                        availableWidth: geometry.size.width
                    )
                }
            }
        }
    }
}

struct MovieRowView: View {
    let row: MovieRow
    let availableWidth: CGFloat
    
    // Dynamic sizing based on device width
    private var posterSize: CGSize {
        MoviePosterView.posterSize(availableWidth: availableWidth)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(Array(row.movies.enumerated()), id: \.offset) { index, movie in
                    MoviePosterView(movie: movie, size: posterSize)
                }
            }
        }
    }
}

extension MoviePosterView {
    static func posterSize(availableWidth: CGFloat) -> CGSize {
        let targetWidth = availableWidth * 0.28  // 28% of screen width
        let clampedWidth = min(max(targetWidth, 100), 200)  // 100-200pt range
        let aspectRatio: CGFloat = 390.0 / 550.0  // Standard poster ratio
        
        return CGSize(width: clampedWidth, height: clampedWidth / aspectRatio)
    }
}
```

**Math:**
- iPhone SE: 375pt → 105pt posters
- iPhone Pro Max: 430pt → 120pt posters  
- iPad: 768pt → 200pt posters (clamped)

### 5. Index-Based ForEach IDs

**Problem:** Expanded dataset repeats movies/rows, causing duplicate ID warnings.

**Solution:** Use array indices as IDs instead of content-based IDs.

```swift
// ❌ BEFORE: Duplicate IDs when movies repeat
ForEach(row.movies, id: \.id) { movie in
    MoviePosterView(movie: movie)
}

// ✅ AFTER: Unique IDs even with repeated content
ForEach(Array(row.movies.enumerated()), id: \.offset) { index, movie in
    MoviePosterView(movie: movie)
}
```

**Trade-off:** Index-based IDs assume static data (no reordering). Acceptable for this use case where data loads once and doesn't change.

### 6. Dual Parsing Strategy

**Why Two Parsers?**

1. **Primary: Decodable** (type-safe, modern, Swift-native)
2. **Backup: JSONSerialization** (maximum defensive, handles truly malformed data)

```swift
enum ManualMovieParser {
    static func parse(data: Data) -> MovieDataResponse {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] 
        else { return MovieDataResponse(lastUpdated: "", rows: []) }
        
        let lastUpdated = root["last-updated"] as? String ?? ""
        let rowsArray = root["rows"] as? [Any] ?? []
        
        let rows: [MovieRow] = rowsArray.compactMap { rowAny in
            guard let rowDict = rowAny as? [String: Any],
                  let title = rowDict["title"] as? String,
                  let moviesArray = rowDict["movies"] as? [Any] else { return nil }
            
            let movies: [Movie] = moviesArray.compactMap { movieAny in
                guard let movieDict = movieAny as? [String: Any] else { return nil }
                let title = movieDict["title"] as? String ?? "Movie Title"
                let imageURL = movieDict["image_url"] as? String ?? ""
                return Movie(title: title, imageURL: imageURL)
            }
            
            return MovieRow(title: title, movies: movies)
        }
        
        return MovieDataResponse(lastUpdated: lastUpdated, rows: rows)
    }
}
```

**Use Case:** Backend sends number instead of string (e.g., `"title": 123`). Decodable throws, ManualMovieParser survives with defaults.

## Testing Strategy

### Test Coverage (11 tests, 100% pass rate)

**MovieDecodingTests (4 tests)**
```swift
✓ testDecodeOriginalDataset_countsMatch()        // 18 movies decoded correctly
✓ testDecodeExpandedDataset_countsMatch()        // 450 movies stress test
✓ testDefensiveDefaults_missingFieldsDoNotCrash() // null/missing fields use defaults
✓ testStableIDs_decodeTwiceIDsMatch()            // Deterministic IDs
```

**ManualParserTests (3 tests)**
```swift
✓ testManualParser_validParse()                  // Same output as Decodable
✓ testManualParser_defaultsForMissingOrWrongTypes() // NSNull, wrong types handled
✓ testManualParser_malformedRootDoesNotCrash_returnsEmpty() // Array root doesn't crash
```

**MovieDataViewModelTests (4 tests)**
```swift
✓ testLoadOriginalDataset_populatesRows()        // State machine: loading → loaded
✓ testLoadExpandedDataset_populatesRows()        // Large payload handling
✓ testLoadData_missingFile_setsErrorMessage()    // File-not-found error handling
✓ testLoadData_decodeFailure_setsErrorMessage()  // Invalid JSON error handling
```

### Dependency Injection Pattern

```swift
// Production: loads from bundle
let viewModel = MovieDataViewModel(datasetMode: .original)

// Testing: inject mock data loader
let viewModel = MovieDataViewModel(
    datasetMode: .original,
    resourceDataLoader: { _ in
        Data("""
        {
            "last-updated": "2024-01-01",
            "rows": []
        }
        """.utf8)
    }
)
```

**Benefits:**
- No file I/O in tests (fast)
- Deterministic (no flaky failures)
- Can simulate errors (file missing, invalid JSON)

## Swift 6 Concurrency

### Sendable Models

All data models conform to `Sendable` for safe concurrent usage:

```swift
struct Movie: Decodable, Identifiable, Sendable { }
struct MovieRow: Decodable, Identifiable, Sendable { }
struct MovieDataResponse: Decodable, Sendable { }
```

**Why Sendable?**
- Prevents data races in concurrent code
- Enables off-main-thread decoding
- Satisfies Swift 6 strict concurrency checking

### @MainActor Isolation

```swift
@MainActor
final class MovieDataViewModel: ObservableObject {
    @Published var rows: [MovieRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // All property access automatically on main thread
    func loadData() async {
        isLoading = true  // ← Guaranteed main thread
        // ... async work ...
        isLoading = false // ← Guaranteed main thread
    }
}
```

**Benefits:**
- UI updates always on main thread (prevents crashes)
- Compiler enforces thread safety
- Tests must use `@MainActor` or `await` to access properties

## Performance Optimizations

### 1. LazyVStack/LazyHStack

```swift
LazyVStack(spacing: 20) {
    ForEach(viewModel.rows) { row in
        LazyHStack(spacing: 10) {
            ForEach(row.movies) { movie in
                MoviePosterView(movie: movie)
            }
        }
    }
}
```

**Impact:** Only renders visible posters. 450-poster dataset renders ~20 views initially instead of 450.

### 2. .task(id:) for Efficient Async Loading

```swift
MoviePosterView(movie: movie)
    .task(id: movie.imageURL) {
        // Only loads if URL changes
        // Automatically cancelled if view disappears
        loadedImage = try? await imageLoader.loadImage(from: url)
    }
```

**Benefits:**
- Automatic cancellation (no memory leaks)
- Debouncing via `id:` parameter
- Clean async/await syntax

### 3. URLCache Policy

```swift
URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
```

**Behavior:**
1. Check memory cache (instant)
2. Check disk cache (fast)
3. Hit network (slow, only if necessary)

## Design Decisions

### Color Scheme

```swift
Color(red: 4/255, green: 28/255, blue: 44/255)  // RGB(4, 28, 44) - dark blue-gray
```

**Source:** Matched exact design comp via color picker.

### Font Styling

```swift
.font(.system(size: 20, weight: .semibold))  // Category titles
.foregroundColor(.white)                     // White text on dark background
```

### Spacing/Padding

- Row spacing: 20pt vertical
- Poster spacing: 10pt horizontal
- Content padding: 16pt horizontal
- Divider: 1pt below each row

**Philosophy:** Match design comp exactly, no guessing.

## Build & Run

### Requirements

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

### Steps

1. **Open project:**
   ```bash
   open Versant-Movie-Row-Project.xcodeproj
   ```

2. **Select scheme:**
   - Product → Scheme → Versant-Movie-Row-Project

3. **Run tests:**
   ```bash
   ⌘ + U
   ```

4. **Run app:**
   ```bash
   ⌘ + R
   ```

### Dataset Switching

Change dataset in `ContentView.swift`:

```swift
// Original dataset (3 rows, 18 movies)
@StateObject private var viewModel = MovieDataViewModel(datasetMode: .original)

// Expanded dataset (15 rows, 450 movies) - stress test
@StateObject private var viewModel = MovieDataViewModel(datasetMode: .expanded)
```

## Code Documentation

Every file includes comprehensive technical comments explaining:
- **Architectural decisions** (why MVVM? why @MainActor?)
- **Trade-offs** (DispatchQueue vs Task.detached)
- **Performance implications** (LazyVStack, URLCache sizing)
- **Testing strategies** (dependency injection, mocks)

Example comment structure:
```swift
/// **Design Decision: Off-Main Decoding**
///
/// **Problem:**
/// - JSONDecoder blocks main thread for ~50ms on 450-movie dataset
/// - Causes UI jank during scroll
///
/// **Solution:**
/// - Decode on background queue (DispatchQueue.global)
/// - Use withCheckedThrowingContinuation for async bridging
///
/// **Trade-off:**
/// - Adds complexity (continuation boilerplate)
/// - Benefit: smoother UI during load
```

## Future Enhancements

**Potential additions:**
- Pull-to-refresh
- Search/filtering
- Detail view navigation
- Video playback
- Favorites/watchlist
- Analytics tracking

**Current scope:** Core carousel UI with production-ready data handling and caching.

---

## Technical Highlights Summary

✅ **MVVM architecture** with clean separation of concerns  
✅ **Defensive decoding** that never crashes  
✅ **Off-main-thread JSON parsing** for smooth UI  
✅ **Intelligent URLCache** (50MB memory, 100MB disk)  
✅ **Dynamic responsive sizing** for all devices  
✅ **LazyVStack/LazyHStack** rendering optimization  
✅ **Comprehensive unit tests** (11 tests, 100% pass)  
✅ **Swift 6 concurrency** (@MainActor, Sendable)  
✅ **Dual parsing strategies** (Decodable + JSONSerialization)  
✅ **Index-based IDs** for duplicate content handling  
✅ **Complete technical documentation** in every file  

---

**Author:** Gregory Young  
**Date:** January 6, 2026  
**Purpose:** Technical demonstration of production-ready SwiftUI development practices
