import Foundation
import UIKit

struct MetadataService {
  static let secureSession = URLSession(configuration: .default, delegate: SecureDownloadRedirectPolicy(), delegateQueue: nil)
  struct Candidate { let title: String; let author: String; let cover: URL?; var genres: [String] = [] }
  struct Response: Decodable { let results: [Result] }
  struct Result: Decodable {
    let collectionName: String?
    let artistName: String?
    let artworkUrl100: String?
    let primaryGenreName: String?
    let genres: [String]?
  }
  struct LibraryResponse: Decodable {
    struct Work: Decodable { let title: String; let author_name: [String]?; let cover_i: Int?; let subject: [String]? }
    let docs: [Work]
  }
  static func normalized(_ value: String) -> Set<String> {
    let formats: Set<String> = ["audiobook", "audiobooks", "unabridged", "ungekurzt", "horbuch", "mp3", "m4b"]
    return Set(value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty && !formats.contains($0) })
  }
  static func confidence(_ query: String, _ candidate: String) -> Double {
    let wanted = normalized(query), actual = normalized(candidate)
    guard !wanted.isEmpty else { return 0 }
    return Double(wanted.intersection(actual).count) / Double(wanted.union(actual).count)
  }
  static func authorMatches(_ a: String, _ b: String) -> Bool {
    func key(_ name: String) -> String {
      name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).filter { $0.isLetter || $0.isNumber }
    }
    return confidence(a, b) >= 0.5 || (!key(a).isEmpty && key(a) == key(b))
  }
  static func needsEnrichment(_ book: AudioBook, directory: URL) -> Bool {
    book.author.isEmpty || book.author == "Unknown author" || !hasGoodCover(book, directory: directory)
      || BookGenre.classify([book.genre ?? ""]) == .uncategorized
  }
  static func bestMatch(_ candidates: [Candidate], for book: AudioBook) -> Candidate? {
    let knownAuthor = !book.author.isEmpty && book.author != "Unknown author"
    let ranked = candidates.filter {
      !normalized($0.author).isEmpty && confidence(book.title, $0.title) >= (knownAuthor ? 0.65 : 0.9)
        && (!knownAuthor || authorMatches(book.author, $0.author))
    }.sorted {
      let a = confidence(book.title, $0.title) + (knownAuthor ? confidence(book.author, $0.author) : 0)
      let b = confidence(book.title, $1.title) + (knownAuthor ? confidence(book.author, $1.author) : 0)
      return a == b ? $0.cover != nil && $1.cover == nil : a > b
    }
    guard let first = ranked.first else { return nil }
    // A title alone cannot distinguish different authors' books with the same name.
    if !knownAuthor, ranked.contains(where: {
      confidence(book.title, $0.title) == confidence(book.title, first.title)
        && normalized($0.author) != normalized(first.author)
    }) { return nil }
    return first
  }
  static func hasGoodCover(_ book: AudioBook, directory: URL) -> Bool {
    guard let file = book.coverFilename,
      let image = UIImage(contentsOfFile: directory.appendingPathComponent(file).path) else { return false }
    return min(image.size.width, image.size.height) >= 200 && max(image.size.width, image.size.height) >= 400
  }
  static func fetch<T: Decodable>(_ type: T.Type, url: URL, session: URLSession) async throws -> T {
    var request = URLRequest(url: url)
    request.timeoutInterval = 12
    request.setValue("sovo./1.0.1 (https://github.com/Somamill/listen)", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await session.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200, response.url?.scheme == "https",
      data.count <= 2_000_000 else { throw ListenError.message("Book metadata is unavailable.") }
    return try JSONDecoder().decode(type, from: data)
  }
  static func enrich(_ original: AudioBook, directory: URL, session: URLSession = secureSession) async throws -> AudioBook {
    var book = original
    let hasCover = hasGoodCover(original, directory: directory)
    if !needsEnrichment(original, directory: directory) { return book }
    let needsGenre = BookGenre.classify([original.genre ?? ""]) == .uncategorized
    var apple = URLComponents(string: "https://itunes.apple.com/search")!
    apple.queryItems = [
      URLQueryItem(name: "term", value: original.title + (original.author == "Unknown author" ? "" : " " + original.author)),
      URLQueryItem(name: "entity", value: "audiobook"), URLQueryItem(name: "limit", value: "12"),
      URLQueryItem(name: "country", value: Locale.current.region?.identifier.lowercased() ?? "us")
    ]
    if let response = try? await fetch(Response.self, url: apple.url!, session: session),
      let match = bestMatch(response.results.compactMap { item in
        guard let title = item.collectionName, let author = item.artistName else { return nil }
        return Candidate(title: title, author: author, cover: item.artworkUrl100.flatMap {
          URL(string: $0.replacingOccurrences(of: "100x100", with: "1200x1200"))
        }, genres: (item.genres ?? []) + (item.primaryGenreName.map { [$0] } ?? []))
      }, for: original)
    {
      if needsGenre { book.genre = BookGenre.classify(match.genres).rawValue }
      if book.author == "Unknown author" || book.author.isEmpty { book.author = match.author }
      if !hasCover { book = await cover(match.cover, for: book, directory: directory, session: session) }
      if hasGoodCover(book, directory: directory) && !needsGenre { book.metadataUpdatedAt = Date(); return book }
    }
    try Task.checkCancellation()
    // Open Library requests are sequential and spaced to respect its public API limit.
    try await Task.sleep(for: .seconds(1.1))
    var library = URLComponents(string: "https://openlibrary.org/search.json")!
    library.queryItems = [URLQueryItem(name: "title", value: original.title),
      URLQueryItem(name: "fields", value: "title,author_name,cover_i,subject"), URLQueryItem(name: "limit", value: "12")]
    if original.author != "Unknown author" && !original.author.isEmpty {
      library.queryItems?.append(URLQueryItem(name: "author", value: original.author))
    }
    if let response = try? await fetch(LibraryResponse.self, url: library.url!, session: session),
      let match = bestMatch(response.docs.map { work in
        Candidate(title: work.title, author: work.author_name?.first ?? "", cover: work.cover_i.flatMap {
          $0 > 0 ? URL(string: "https://covers.openlibrary.org/b/id/\($0)-L.jpg?default=false") : nil
        }, genres: work.subject ?? [])
      }, for: book)
    {
      let genre = BookGenre.classify(match.genres)
      if needsGenre, genre != .uncategorized { book.genre = genre.rawValue }
      if book.author == "Unknown author" || book.author.isEmpty { book.author = match.author }
      if !hasGoodCover(book, directory: directory) { book = await cover(match.cover, for: book, directory: directory, session: session) }
    }
    guard book.author != original.author || book.genre != original.genre || book.coverFilename != original.coverFilename || (!hasCover && hasGoodCover(book, directory: directory)) else {
      throw ListenError.message("No confident metadata match. Embedded details were kept.")
    }
    book.metadataUpdatedAt = Date()
    return book
  }
  private static func cover(_ url: URL?, for original: AudioBook, directory: URL, session: URLSession) async -> AudioBook {
    guard let url, url.scheme == "https", let host = url.host?.lowercased(),
      host == "covers.openlibrary.org" || host == "mzstatic.com" || host.hasSuffix(".mzstatic.com") else { return original }
    var book = original
    do {
      var request = URLRequest(url: url); request.timeoutInterval = 15
      let (data, response) = try await session.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200, response.url?.scheme == "https",
        data.count <= 8_000_000, let decoded = UIImage(data: data),
        min(decoded.size.width, decoded.size.height) >= 200,
        max(decoded.size.width, decoded.size.height) >= 400,
        decoded.size.width * decoded.size.height <= 36_000_000,
        let jpeg = decoded.jpegData(compressionQuality: 0.95) else { return book }
      try jpeg.write(to: directory.appendingPathComponent("cover.jpg"), options: .atomic)
      book.coverFilename = "cover.jpg"
    } catch { /* Unavailable artwork must not prevent importing audio. */ }
    return book
  }
}
