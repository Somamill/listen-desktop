import Foundation

/// Edition-specific credits require both a matching identity and compatible running time.
struct AppleBookEdition {
  static func duration(_ value: String) -> Double? {
    guard let expression = try? NSRegularExpression(pattern: #"^PT(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?$"#),
      let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else { return nil }
    let factors = [3600.0, 60.0, 1.0]
    let seconds = (1...3).reduce(0.0) { result, index in
      guard let range = Range(match.range(at: index), in: value), let amount = Double(value[range]) else { return result }
      return result + amount * factors[index - 1]
    }
    return seconds > 0 && seconds.isFinite ? seconds : nil
  }
  static func apply(_ object: [String: Any], to original: AudioBook, source: URL) -> AudioBook {
    guard object["@type"] as? String == "Audiobook", let title = object["name"] as? String,
      let author = object["author"] as? String,
      MetadataService.bestMatch([.init(title: title, author: author, cover: nil)], for: original) != nil,
      let length = (object["duration"] as? String).flatMap(duration), original.duration > 0,
      abs(length - original.duration) <= max(60, original.duration * 0.02) else { return original }
    var book = original
    func text(_ key: String, limit: Int = 500) -> String? {
      guard let value = object[key] as? String else { return nil }
      let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
      return !clean.isEmpty && clean.count <= limit ? clean : nil
    }
    if book.narrator.isEmpty { book.narrator = text("readBy") ?? "" }
    if book.publisher == nil { book.publisher = text("provider") }
    if book.language == nil { book.language = text("inLanguage", limit: 80) }
    if book.summary == nil { book.summary = text("description", limit: 20_000).map(MetadataService.plainText) }
    if book.releaseYear == nil, let date = text("datePublished"), let year = Int(date.prefix(4)), (1000...3000).contains(year) { book.releaseYear = year }
    book.metadataSource = source.absoluteString
    return book
  }
  static func enrich(_ original: AudioBook, from source: URL, session: URLSession) async -> AudioBook {
    guard source.scheme == "https", source.host?.lowercased() == "books.apple.com",
      source.path.contains("/audiobook/"), source.user == nil, source.password == nil else { return original }
    do {
      var request = URLRequest(url: source); request.timeoutInterval = 15
      let (data, response) = try await session.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200, response.url?.host == "books.apple.com",
        data.count <= 3_000_000, let html = String(data: data, encoding: .utf8) else { return original }
      let pattern = #"<script\b[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script\s*>"#
      let expression = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
      for match in expression.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
        guard let range = Range(match.range(at: 1), in: html),
          let object = try? JSONSerialization.jsonObject(with: Data(html[range].utf8)) as? [String: Any] else { continue }
        var book = apply(object, to: original, source: source)
        if book != original, book.language == nil,
          let languageRegex = try? NSRegularExpression(pattern: #"book-badge__eyebrow["']>\s*LANGUAGE\s*</div>[\s\S]*?book-badge__caption["']>([\s\S]*?)</div>"#),
          let languageMatch = languageRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
          let range = Range(languageMatch.range(at: 1), in: html) {
          let language = MetadataService.plainText(String(html[range]))
          if !language.isEmpty, language.count <= 80 { book.language = language }
        }
        if book != original { return book }
      }
    } catch { /* Public edition details are optional; original audio and tags remain usable. */ }
    return original
  }
}
