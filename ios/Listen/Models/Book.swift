import Foundation

struct Chapter: Codable, Identifiable, Equatable {
  var id = UUID()
  var title: String
  var start: Double
}
struct AudioTrack: Codable, Identifiable, Equatable {
  var id = UUID()
  var filename: String
  var duration: Double
}
struct Bookmark: Codable, Identifiable, Equatable {
  var id = UUID()
  var position: Double
  var note: String
  var kind: String? = nil
}
struct ListeningState: Codable, Equatable {
  var position: Double = 0
  var finished = false
  var updatedAt = Date.distantPast
  var deviceID = ""
  mutating func merge(_ other: Self) {
    if other.updatedAt > updatedAt || (other.updatedAt == updatedAt && other.deviceID > deviceID) {
      self = other
    }
  }
}
struct AudioBook: Codable, Identifiable, Equatable {
  var id: UUID = UUID()
  var title: String
  var author: String = "Unknown author"
  var narrator: String = ""
  var genre: String? = nil
  var genreLabel: String { BookGenre.classify([genre ?? ""]).rawValue }
  var folder: String = ""
  var tracks: [AudioTrack] = []
  var chapters: [Chapter] = []
  var bookmarks: [Bookmark] = []
  var coverFilename: String? = nil
  var state = ListeningState()
  var createdAt = Date()
  var metadataUpdatedAt = Date()
  var metadataLookupAt: Date? = nil
  var needsM4BConversion: Bool {
    !tracks.isEmpty && (tracks.count > 1 || !tracks[0].filename.lowercased().hasSuffix(".m4b"))
  }
  var duration: Double { tracks.reduce(0) { $0 + $1.duration } }
  var progress: Double { duration > 0 ? min(1, max(0, state.position / duration)) : 0 }
  mutating func merge(_ remote: Self) {
    guard remote.id == id else { return }
    var progress = state; progress.merge(remote.state)
    let local = self
    self = metadataUpdatedAt > remote.metadataUpdatedAt ? local : remote
    // Older app versions do not know these optional metadata fields.
    if genre == nil { genre = local.genre ?? remote.genre }
    metadataLookupAt = [local.metadataLookupAt, remote.metadataLookupAt].compactMap { $0 }.max()
    state = progress
    ensureBasicMetadata()
  }
  mutating func ensureBasicMetadata(fallbackTitle: String? = nil) {
    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      let filename = tracks.first?.filename.replacingOccurrences(of: #"^\d{4}-"#, with: "", options: .regularExpression)
      let fallback = fallbackTitle ?? filename.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent } ?? ""
      title = fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled audiobook" : fallback
    }
    if author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { author = "Unknown author" }
    if genre?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { genre = BookGenre.uncategorized.rawValue }
  }
  func trackPosition(at position: Double) -> (index: Int, offset: Double) {
    var remaining = max(0, position)
    for (index, track) in tracks.enumerated() {
      if remaining < track.duration || index == tracks.count - 1 {
        return (index, min(remaining, track.duration))
      }
      remaining -= track.duration
    }
    return (0, 0)
  }
  func offset(for index: Int) -> Double { tracks.prefix(index).reduce(0) { $0 + $1.duration } }
}
struct GoodreadsBook: Codable, Identifiable, Equatable {
  var id: String
  var title: String
  var author: String
  var shelf: String
  var cover: String?
  var url: String
}

enum ListenError: LocalizedError {
  case message(String)
  var errorDescription: String? {
    if case .message(let value) = self { return value }
    return nil
  }
}
func timeLabel(_ seconds: Double) -> String {
  guard seconds.isFinite else { return "0:00" }
  let total = max(0, Int(seconds))
  let hours = total / 3600
  return hours > 0
    ? String(format: "%d:%02d:%02d", hours, (total / 60) % 60, total % 60)
    : String(format: "%d:%02d", total / 60, total % 60)
}

enum BookGenre: String, CaseIterable, Identifiable {
  case fantasy = "Fantasy", scienceFiction = "Science Fiction", speculative = "Sci-Fi & Fantasy"
  case crime = "Mystery & Crime", romance = "Romance", biography = "Biography & Memoir"
  case history = "History", children = "Children & Young Adult"
  case nonfiction = "Nonfiction", fiction = "Fiction", uncategorized = "Uncategorized"
  var id: String { rawValue }
  static func classify(_ values: [String]) -> Self {
    let tags = values.map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
    let rules: [(Self, [String])] = [
      (.speculative, ["sci-fi & fantasy", "science fiction & fantasy"]),
      (.scienceFiction, ["science fiction", "sci-fi", "science-fiction"]),
      (.fantasy, ["fantasy", "fantastik"]), (.crime, ["mystery", "crime", "thriller", "krimi", "detektiv"]),
      (.romance, ["romance", "liebesroman"]), (.biography, ["biograph", "memoir", "autobiograph"]),
      (.history, ["history", "geschichte", "historical nonfiction"]),
      (.children, ["children", "young adult", "kids", "kinder", "jugend"]),
      (.nonfiction, ["nonfiction", "non-fiction", "non fiction", "sachbuch", "self-help", "self help", "business", "psychology", "science", "philosophy", "health", "religion", "politics", "ratgeber"]),
      (.fiction, ["fiction", "belletristik", "novel", "roman"])
    ]
    for (genre, words) in rules where tags.contains(where: { tag in words.contains(where: { word in
      tag.contains(word)
    }) }) { return genre }
    return .uncategorized
  }
}
