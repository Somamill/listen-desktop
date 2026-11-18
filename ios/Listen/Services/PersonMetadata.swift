import Foundation

struct PersonProfile: Decodable {
  struct Picture: Decodable { let source: URL }
  struct Links: Decodable { struct Page: Decodable { let page: URL }; let desktop: Page }
  let type: String
  let title: String
  let description: String?
  let extract: String?
  var thumbnail: Picture?
  let content_urls: Links
  var photoCredit: String? = nil
  var photoSource: URL? = nil
  var photoLicense: URL? = nil
  func matches(name: String, narrator: Bool) -> Bool {
    let cleanTitle = title.replacingOccurrences(of: #"\s*\([^)]*\)\s*$"#, with: "", options: .regularExpression)
    let detail = (description ?? "").lowercased()
    let roles = narrator ? ["narrator", "voice actor", "actor", "actress", "voice artist"] : ["writer", "author", "novelist", "historian", "poet", "journalist"]
    return type == "standard" && MetadataService.normalized(name) == MetadataService.normalized(cleanTitle)
      && roles.contains(where: detail.contains)
      && content_urls.desktop.page.scheme == "https" && content_urls.desktop.page.host == "en.wikipedia.org"
      && (thumbnail == nil || (thumbnail?.source.scheme == "https" && ["upload.wikimedia.org", "thumb.wikimedia.org"].contains(thumbnail?.source.host ?? "")))
  }
}

actor PersonMetadata {
  static let shared = PersonMetadata()
  private var cache: [String: PersonProfile] = [:]
  private var missing: Set<String> = []
  func profile(name: String, narrator: Bool) async -> PersonProfile? {
    let key = "\(narrator):\(name)"
    if let saved = cache[key] { return saved }
    guard !missing.contains(key), !name.isEmpty, name.count <= 200, !["Unknown author", "Not credited"].contains(name) else { return nil }
    var url = URLComponents(string: "https://en.wikipedia.org/api/rest_v1/page/summary/")!
    url.path += name.replacingOccurrences(of: " ", with: "_")
    if let url = url.url, var result = try? await MetadataService.fetch(PersonProfile.self, url: url, session: MetadataService.secureSession), result.matches(name: name, narrator: narrator) {
      if let picture = result.thumbnail {
        result.thumbnail = nil
        let parts = picture.source.pathComponents
        if parts.contains("commons"), let file = parts.dropLast().last, parts.contains("thumb") {
          var query = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
          query.queryItems = [URLQueryItem(name: "action", value: "query"), URLQueryItem(name: "prop", value: "imageinfo"), URLQueryItem(name: "iiprop", value: "extmetadata"), URLQueryItem(name: "titles", value: "File:" + file), URLQueryItem(name: "format", value: "json"), URLQueryItem(name: "formatversion", value: "2")]
          if let source = query.url, let metadata = try? await MetadataService.fetch(PhotoResponse.self, url: source, session: MetadataService.secureSession),
            let details = metadata.query.pages.first?.imageinfo?.first?.extmetadata,
            let license = details["LicenseShortName"]?.value,
            license.hasPrefix("CC BY") || license == "CC0" || license == "Public domain",
            let artist = details["Artist"]?.value {
            let credit = artist.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
              .replacingOccurrences(of: "&amp;", with: "&").trimmingCharacters(in: .whitespacesAndNewlines)
            if !credit.isEmpty, credit.count <= 1000 {
              var clean = URLComponents(url: picture.source, resolvingAgainstBaseURL: false); clean?.query = nil
              result.thumbnail = clean?.url.map(PersonProfile.Picture.init(source:))
              result.photoCredit = credit + " · " + license
              var page = URLComponents(string: "https://commons.wikimedia.org/wiki/")!; page.path += "File:" + file
              result.photoSource = page.url
              if let value = details["LicenseUrl"]?.value, let link = URL(string: value), link.scheme == "https", link.host == "creativecommons.org" { result.photoLicense = link }
            }
          }
        }
      }
      cache[key] = result; return result
    }
    missing.insert(key); return nil
  }
  private struct PhotoResponse: Decodable {
    struct Query: Decodable {
      struct Page: Decodable {
        struct Info: Decodable { struct Value: Decodable { let value: String }; let extmetadata: [String: Value] }
        let imageinfo: [Info]?
      }
      let pages: [Page]
    }
    let query: Query
  }
}
