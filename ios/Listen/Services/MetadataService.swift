import Foundation
import UIKit

struct MetadataService {
  static let secureSession = URLSession(configuration: .default, delegate: SecureDownloadRedirectPolicy(), delegateQueue: nil)
  struct Candidate { let title: String; let author: String; let cover: URL?; var genres: [String] = []; var source: URL? = nil; var year: Int? = nil }
  struct Response: Decodable { let results: [Result] }
  struct Result: Decodable {
    let collectionName: String?
    let artistName: String?
    let artworkUrl100: String?
    let primaryGenreName: String?
    let genres: [String]?
    let collectionViewUrl: String?
  }
  struct LibraryResponse: Decodable {
    struct Work: Decodable { let title: String; let author_name: [String]?; let cover_i: Int?; let subject: [String]?; let first_publish_year: Int? }
    let docs: [Work]
  }
  static func normalized(_ value: String) -> Set<String> {
    let formats: Set<String> = ["audiobook", "audiobooks", "unabridged", "ungekurzt", "horbuch", "mp3", "m4b"]
    return Set(value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty && !formats.contains($0) })
  }
  static func plainText(_ value: String) -> String {
    var text = value
    for _ in 0..<2 {
      for (entity, character) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&apos;", "'"), ("&nbsp;", " "), ("&amp;", "&")] {
        text = text.replacingOccurrences(of: entity, with: character)
      }
    }
    if let regex = try? NSRegularExpression(pattern: #"&#(x[0-9a-fA-F]+|\d+);"#) {
      for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
        guard let range = Range(match.range(at: 1), in: text), let whole = Range(match.range, in: text) else { continue }
        let number = String(text[range]); let hex = number.hasPrefix("x")
        if let code = UInt32(hex ? String(number.dropFirst()) : number, radix: hex ? 16 : 10), let scalar = UnicodeScalar(code) {
          text.replaceSubrange(whole, with: String(scalar))
        }
      }
    }
    return text.replacingOccurrences(of: #"(?i)<br\s*/?>|</p>"#, with: "\n", options: .regularExpression)
      .replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
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
  static func lookupTitle(_ book: AudioBook) -> String {
    let hint = (book.sourceTitle ?? book.chapters.first?.title ?? "").replacingOccurrences(of: #"\s*[-_ ]\s*\d+\s*$"#, with: "", options: .regularExpression)
    let informativeHint = normalized(book.title).isSubset(of: normalized(hint)) && normalized(hint).count > normalized(book.title).count
    return (informativeHint ? hint : book.title).replacingOccurrences(of: #"(?i)\s*[\[(](?:unabridged|abridged|ungekürzt|ungekurzt|audiobook|hörbuch)[\])]"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
  }
  static func bestMatch(_ candidates: [Candidate], for book: AudioBook) -> Candidate? {
    let knownAuthor = !book.author.isEmpty && book.author != "Unknown author"
    func score(_ candidate: Candidate) -> Double {
      confidence(lookupTitle(book), candidate.title)
    }
    let ranked = candidates.filter {
      !normalized($0.author).isEmpty && score($0) >= (knownAuthor ? 0.65 : 0.9)
        && (!knownAuthor || authorMatches(book.author, $0.author))
    }.sorted {
      let a = score($0) + (knownAuthor ? confidence(book.author, $0.author) : 0)
      let b = score($1) + (knownAuthor ? confidence(book.author, $1.author) : 0)
      return a == b ? $0.cover != nil && $1.cover == nil : a > b
    }
    guard let first = ranked.first else { return nil }
    // A title alone cannot distinguish different authors' books with the same name.
    if !knownAuthor, ranked.contains(where: {
      score($0) == score(first)
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
    let needsCore = needsEnrichment(original, directory: directory)
    let needsGenre = BookGenre.classify([original.genre ?? ""]) == .uncategorized
    var apple = URLComponents(string: "https://itunes.apple.com/search")!
    apple.queryItems = [
      URLQueryItem(name: "term", value: lookupTitle(original) + (original.author == "Unknown author" ? "" : " " + original.author)),
      URLQueryItem(name: "entity", value: "audiobook"), URLQueryItem(name: "limit", value: "12"),
      URLQueryItem(name: "country", value: Locale.current.region?.identifier.lowercased() ?? "us")
    ]
    var appleCandidates: [Candidate] = []
    let region = Locale.current.region?.identifier.lowercased() ?? "us"
    for country in region == "us" ? ["us"] : ["us", region] {
      apple.queryItems?.removeAll { $0.name == "country" }
      apple.queryItems?.append(URLQueryItem(name: "country", value: country))
      if let response = try? await fetch(Response.self, url: apple.url!, session: session) {
        appleCandidates += response.results.compactMap { item in
        guard let title = item.collectionName, let author = item.artistName else { return nil }
        return Candidate(title: title, author: author, cover: item.artworkUrl100.flatMap {
          URL(string: $0.replacingOccurrences(of: "100x100", with: "1200x1200"))
        }, genres: (item.genres ?? []) + (item.primaryGenreName.map { [$0] } ?? []), source: item.collectionViewUrl.flatMap(URL.init(string:)))
        }
      }
      if bestMatch(appleCandidates, for: original) != nil { break }
    }
    if let match = bestMatch(appleCandidates, for: original) {
      if needsGenre { book.genre = BookGenre.classify(match.genres).rawValue }
      if book.author == "Unknown author" || book.author.isEmpty { book.author = match.author }
      if !hasCover { book = await cover(match.cover, for: book, directory: directory, session: session) }
      if let source = match.source { book = await AppleBookEdition.enrich(book, from: source, session: session) }
    }
    if !needsCore && book == original { return original }
    try Task.checkCancellation()
    // Open Library requests are sequential and spaced to respect its public API limit.
    try await Task.sleep(for: .seconds(1.1))
    var library = URLComponents(string: "https://openlibrary.org/search.json")!
    library.queryItems = [URLQueryItem(name: "title", value: lookupTitle(original)),
      URLQueryItem(name: "fields", value: "title,author_name,cover_i,subject,first_publish_year"), URLQueryItem(name: "limit", value: "12")]
    if original.author != "Unknown author" && !original.author.isEmpty {
      library.queryItems?.append(URLQueryItem(name: "author", value: original.author))
    }
    if let response = try? await fetch(LibraryResponse.self, url: library.url!, session: session),
      let match = bestMatch(response.docs.map { work in
        Candidate(title: work.title, author: work.author_name?.first ?? "", cover: work.cover_i.flatMap {
          $0 > 0 ? URL(string: "https://covers.openlibrary.org/b/id/\($0)-L.jpg?default=false") : nil
        }, genres: work.subject ?? [], year: work.first_publish_year)
      }, for: book)
    {
      let genre = BookGenre.classify(match.genres)
      if book.genreLabel == BookGenre.uncategorized.rawValue, genre != .uncategorized { book.genre = genre.rawValue }
      if book.publicationYear == nil { book.publicationYear = match.year }
      if book.author == "Unknown author" || book.author.isEmpty { book.author = match.author }
      if !hasGoodCover(book, directory: directory) { book = await cover(match.cover, for: book, directory: directory, session: session) }
    }
    guard book != original || (!hasCover && hasGoodCover(book, directory: directory)) else {
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
