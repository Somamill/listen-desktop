import Foundation
import WebKit
import Combine

@MainActor final class GoodreadsConnection: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var books: [GoodreadsBook] = []
    @Published var status = "Connect Goodreads to bring your reading shelves here."
    @Published var refreshing = false
    @Published var showSignIn = false
    @Published private(set) var needsSignIn = false
    @Published var profileID: String?
    @Published var syncEnabled: Bool {
        didSet { UserDefaults.standard.set(syncEnabled, forKey: "goodreadsCloudSync"); onChange?() }
    }
    var onChange: (() -> Void)?
    @Published private(set) var snapshotDate = Date.distantPast
    private var snapshotDeviceID: String
    let deviceID: String
    let webView: WKWebView
    private let file: URL
    private var timer: Timer?
    private var refreshTimeout: Task<Void, Never>?
    private var collecting: [String:GoodreadsBook] = [:]
    private var page = 1
    private var privacyReady = false
    private var preparingPrivacy = false
    private var pendingConnect = false
    private var pendingRefresh = false
    private func preparePrivacy() {
        guard !preparingPrivacy, !privacyReady else { return }
        preparingPrivacy = true
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "listen-goodreads-privacy-v1", encodedContentRuleList: GoodreadsPrivacy.rules
        ) { [weak self] rules, error in
            Task { @MainActor in
                guard let self else { return }
                self.preparingPrivacy = false
                guard let rules, error == nil else {
                    self.status = "Goodreads privacy controls could not start. Try connecting again, or import a CSV."
                    return
                }
                self.webView.configuration.userContentController.add(rules)
                self.privacyReady = true
                let connect = self.pendingConnect, refresh = self.pendingRefresh
                self.pendingConnect = false; self.pendingRefresh = false
                if connect { self.connect() } else if refresh { self.refresh() }
            }
        }
    }
    init(root: URL? = nil) {
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        webView = WKWebView(frame: .zero, configuration: configuration)
        let root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = root.appendingPathComponent("goodreads-shelves.json")
        syncEnabled = UserDefaults.standard.object(forKey: "goodreadsCloudSync") as? Bool ?? true
        deviceID = UserDefaults.standard.string(forKey: "deviceID") ?? UUID().uuidString
        snapshotDeviceID = deviceID
        profileID = UserDefaults.standard.string(forKey: "goodreadsProfileID")
        super.init(); webView.navigationDelegate = self; webView.uiDelegate = self
        preparePrivacy()
        if let data = try? Data(contentsOf: file) {
            if let snapshot = try? JSONDecoder().decode(GoodreadsCloudSnapshot.self, from: data), snapshot.valid {
                books = snapshot.books; profileID = snapshot.profileID; snapshotDate = snapshot.updatedAt; snapshotDeviceID = snapshot.deviceID
            } else if let rows = try? JSONDecoder().decode([GoodreadsBook].self, from: data) {
                books = rows
                snapshotDate = (try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date) ?? .distantPast
            }
            status = "Saved Goodreads shelves · refresh to check for changes"
        }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
    }
    func connect() {
        refreshTimeout?.cancel()
        showSignIn = true
        guard privacyReady else {
            pendingConnect = true; status = "Preparing Goodreads privacy controls…"; preparePrivacy(); return
        }
        refreshing = false
        webView.stopLoading()
        let path = profileID.map { "https://www.goodreads.com/review/list/\($0)?shelf=all" }
          ?? "https://www.goodreads.com/user/sign_in"
        webView.load(URLRequest(url: URL(string: path)!))
    }
    func setProfile(_ value: String) {
        guard let url = URL(string: value), url.scheme == "https", ["goodreads.com","www.goodreads.com"].contains(url.host ?? "") else { status = "Use your Goodreads profile or My Books HTTPS link."; return }
        let parts = url.pathComponents
        guard let key = parts.firstIndex(where: { $0 == "show" || $0 == "list" }), parts.indices.contains(key+1), let id = parts[key+1].split(separator: "-").first, !id.isEmpty, id.allSatisfy(\.isNumber) else { status = "The Goodreads profile number could not be read."; return }
        guard id.count <= 30 else { status = "The Goodreads profile number is not valid."; return }
        if profileID != String(id) {
            refreshTimeout?.cancel(); webView.stopLoading(); refreshing = false
            profileID = String(id); books = []; snapshotDate = .distantPast; snapshotDeviceID = deviceID
            UserDefaults.standard.set(profileID, forKey: "goodreadsProfileID"); writeSnapshot()
        }
        refresh()
    }
    func refresh() {
        guard !refreshing, !showSignIn else { return }
        guard let profileID else { status = "Connect Goodreads, paste your profile link, or import its library CSV."; return }
        guard privacyReady else { pendingRefresh = true; preparePrivacy(); return }
        collecting = [:]; page = 1; refreshing = true; status = "Refreshing Goodreads shelves…"
        loadPage(profileID)
    }
    private func loadPage(_ id: String) {
        refreshTimeout?.cancel()
        refreshTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled, let self, self.refreshing else { return }
            self.webView.stopLoading()
            self.failRefresh("Goodreads took too long to respond. Saved shelves are retained; try again or reconnect.")
        }
        webView.load(URLRequest(url: URL(string: "https://www.goodreads.com/review/list/\(id)?shelf=all&per_page=100&page=\(page)")!))
    }
    private func failRefresh(_ message: String, signIn: Bool = false) {
        refreshTimeout?.cancel(); refreshing = false; collecting = [:]
        needsSignIn = signIn; status = message
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        guard ["goodreads.com","www.goodreads.com"].contains(url.host ?? "") else {
            if refreshing { failRefresh("Goodreads needs you to reconnect. Saved shelves are retained.", signIn: true) }
            return
        }
        if url.path.contains("sign_in") || url.path.contains("sign_up") {
            if refreshing { failRefresh("Goodreads needs you to sign in again. Saved shelves are retained.", signIn: true) }
            return
        }
        if !url.path.hasPrefix("/review/list/") {
            webView.evaluateJavaScript("Array.from(document.querySelectorAll('a[href*=\"/review/list/\"]')).find(a => /my books/i.test(a.textContent))?.href || null") { [weak self] result, _ in
                guard let link = result as? String else { return }
                self?.setProfile(link)
            }; return
        }
        if showSignIn {
            setProfile(url.absoluteString)
            status = "Goodreads is open in sovo. Tap Done to import your shelves."
            return
        }
        guard refreshing else { return }
        guard url.pathComponents.last == profileID else {
            failRefresh("Goodreads opened a different profile. Reconnect to choose your shelves."); return
        }
        webView.evaluateJavaScript(Self.shelfScript) { [weak self] result, error in
            guard let self, self.refreshing else { return }
            if let object = result as? [String: Any], object["signedOut"] as? Bool == true {
                self.failRefresh("Sign in to Goodreads on this device to refresh your shelves. Your saved books are kept.", signIn: true); return
            }
            guard error == nil, let object = result as? [String:Any], object["valid"] as? Bool == true,
                  let rows = object["books"] as? [[String:Any]], let data = try? JSONSerialization.data(withJSONObject: rows),
                  let decoded = try? JSONDecoder().decode([GoodreadsBook].self, from: data) else {
                self.failRefresh("Goodreads did not return a readable shelf. Open the connection to check your sign-in, then try again. Your saved books are kept.", signIn: true); return
            }
            self.acceptPage(decoded, hasNext: object["next"] as? Bool == true)
        }
    }
    func acceptPage(_ decoded: [GoodreadsBook], hasNext: Bool) {
        guard refreshing else { return }
        let candidate = GoodreadsCloudSnapshot(profileID: profileID, books: decoded, updatedAt: Date(), deviceID: deviceID)
        guard candidate.valid else { failRefresh("Goodreads returned invalid book data. Saved shelves are retained."); return }
        for book in decoded { collecting[book.id] = book }
        guard collecting.count <= 5000, !(hasNext && page >= 50) else {
            failRefresh("Goodreads library is too large for a complete refresh. Saved shelves are retained; use a CSV export."); return
        }
        if hasNext, let id = profileID { page += 1; loadPage(id); return }
        books = Array(collecting.values).sorted { $0.title < $1.title }
        refreshTimeout?.cancel(); refreshing = false; needsSignIn = false
        persist(); status = "Goodreads shelves refreshed · \(books.count) books"; showSignIn = false
    }
    nonisolated static let shelfScript = #"""
        (() => {
          const rows = Array.from(document.querySelectorAll('tr.bookalike'));
          const shelfTable = document.querySelector('#books #booksBody, #booksBody');
          const visible = element => !!element && element.getClientRects().length > 0;
          const signIn = Array.from(document.querySelectorAll('form[action*="sign_in"],form[action*="signin"],input[type="password"]')).some(visible);
          const challenge = Array.from(document.querySelectorAll('iframe[src*="recaptcha"]')).some(visible);
          const signedOut = !shelfTable && (signIn || /sign in to see|private profile|private library/i.test(document.body.innerText));
          const blocked = challenge || signedOut || (signIn && rows.length === 0);
          const empty = /no books|haven.t added any books|0 books/i.test(document.querySelector('#books, #booksBody')?.textContent || '');
          return {books: rows.map(row => {
            const title = row.querySelector('td.title a.bookTitle,td.title a');
            const author = row.querySelector('td.author a');
            const shelf = Array.from(row.querySelectorAll('td.shelves .shelf,td.shelves a')).find(a => ['to-read','currently-reading','read','did-not-finish'].includes(a.textContent.trim()));
            const image = row.querySelector('td.cover img');
            const id = title?.href.match(/\/book\/show\/(\d+)/)?.[1];
            return {id:id || row.id,title:(title?.textContent || '').trim(),author:(author?.textContent || '').trim(),shelf:(shelf?.textContent || 'to-read').trim(),cover:image?.src || null,url:title?.href || ''};
          }).filter(b => b.id && b.title),next:!!document.querySelector('a.next_page:not(.disabled)'),signedOut,valid:!blocked && !!shelfTable && (rows.length > 0 || empty)};
        })()
        """#
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        failRefresh("Goodreads is unavailable. Your saved shelves are still here.")
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
    }
    func openBook(_ url: URL) {
        guard privacyReady, GoodreadsPrivacy.allowsNavigation(url, mainFrame: true),
          ["goodreads.com", "www.goodreads.com"].contains(url.host?.lowercased() ?? "") else { return }
        refreshing = false
        showSignIn = true
        webView.stopLoading()
        webView.load(URLRequest(url: url))
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil, privacyReady, let url = action.request.url,
          GoodreadsPrivacy.allowsNavigation(url, mainFrame: true) {
            webView.load(action.request)
        }
        return nil
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel, preferences); return }
        let mainFrame = action.targetFrame?.isMainFrame ?? true
        preferences.allowsContentJavaScript = GoodreadsPrivacy.needsWebsiteScripts(url, interactive: showSignIn)
        preferences.preferredContentMode = showSignIn ? .recommended : .desktop
        decisionHandler(privacyReady && GoodreadsPrivacy.allowsNavigation(url, mainFrame: mainFrame) ? .allow : .cancel, preferences)
    }
    func disconnect() {
        refreshTimeout?.cancel(); needsSignIn = false
        syncEnabled = false
        pendingConnect = false; pendingRefresh = false
        profileID = nil; books = []; collecting = [:]; refreshing = false; webView.stopLoading()
        UserDefaults.standard.removeObject(forKey: "goodreadsProfileID"); try? FileManager.default.removeItem(at: file)
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { }
        status = "Goodreads disconnected on this device."
    }
    var cloudSnapshot: GoodreadsCloudSnapshot {
        GoodreadsCloudSnapshot(profileID: profileID, books: books, updatedAt: snapshotDate, deviceID: snapshotDeviceID)
    }
    func applyCloud(_ snapshot: GoodreadsCloudSnapshot) {
        guard syncEnabled, !showSignIn, !refreshing, snapshot.valid, snapshot.newer(than: cloudSnapshot) else { return }
        profileID = snapshot.profileID; books = snapshot.books; snapshotDate = snapshot.updatedAt; snapshotDeviceID = snapshot.deviceID
        UserDefaults.standard.set(profileID, forKey: "goodreadsProfileID")
        writeSnapshot()
        status = "Goodreads shelves received from iCloud. Website sign-in stays on this device."
    }
    private func writeSnapshot() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
            try encoder.encode(cloudSnapshot).write(to: file, options: .atomic)
        } catch { status = "Goodreads shelves could not be saved: \(error.localizedDescription)" }
    }
    private func persist() {
        snapshotDate = Date(); snapshotDeviceID = deviceID; writeSnapshot(); onChange?()
    }
    func importCSV(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        do { books = try Self.parseCSV(String(contentsOf: url, encoding: .utf8)); persist(); status = "Imported \(books.count) Goodreads books from CSV. This is a snapshot; connect for refresh." }
        catch { status = "Could not import Goodreads CSV: \(error.localizedDescription)" }
    }
    nonisolated static func parseCSV(_ text: String) throws -> [GoodreadsBook] {
        var rows: [[String]] = [], row: [String] = [], cell = "", quoted = false
        let chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\u{feff}", with: "")); var index = 0
        while index < chars.count {
            let c = chars[index]
            if c == "\"" { if quoted && index+1 < chars.count && chars[index+1] == "\"" { cell.append("\""); index += 1 } else { quoted.toggle() } }
            else if c == "," && !quoted { row.append(cell); cell = "" }
            else if c == "\n" && !quoted { row.append(cell); rows.append(row); row = []; cell = "" }
            else { cell.append(c) }; index += 1
        }
        guard !quoted else { throw ListenError.message("An unclosed quote was found.") }
        if !cell.isEmpty || !row.isEmpty { row.append(cell); rows.append(row) }
        guard let header = rows.first, let title = header.firstIndex(of: "Title"), let author = header.firstIndex(of: "Author"), let id = header.firstIndex(of: "Book Id") else { throw ListenError.message("Use a Goodreads library export with Book Id, Title, and Author columns.") }
        let shelf = header.firstIndex(of: "Exclusive Shelf")
        return rows.dropFirst().compactMap { row in
            guard row.count > max(title,author,id), !row[id].isEmpty else { return nil }
            return GoodreadsBook(id: row[id], title: row[title], author: row[author], shelf: shelf.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? "to-read", cover: nil, url: "https://www.goodreads.com/book/show/" + row[id])
        }
    }
}


/// Persistent authentication stays separate from Safari. Shelf pages need no website scripts;
/// the app's own DOM extraction remains available through evaluateJavaScript.
enum GoodreadsPrivacy {
    static func provider(_ host: String) -> Bool {
        ["goodreads.com", "amazon.com"].contains { host == $0 || host.hasSuffix("." + $0) }
    }
    static func captcha(_ url: URL) -> Bool {
        ["www.google.com", "www.gstatic.com"].contains(url.host?.lowercased() ?? "") && url.path.hasPrefix("/recaptcha/")
    }
    static func allowsNavigation(_ url: URL, mainFrame: Bool) -> Bool {
        url.scheme == "https" && (provider(url.host?.lowercased() ?? "") || (!mainFrame && captcha(url)))
    }
    static func needsWebsiteScripts(_ url: URL, interactive: Bool = false) -> Bool {
        guard url.scheme == "https" else { return false }
        if captcha(url) { return true }
        guard provider(url.host?.lowercased() ?? "") else { return false }
        if interactive, ["goodreads.com", "www.goodreads.com"].contains(url.host?.lowercased() ?? ""),
           ["/book/show/", "/review/edit/", "/review/new/", "/review/list/"].contains(where: { url.path.hasPrefix($0) }) { return true }
        return ["/ap/", "/user/sign_in", "/user/sign_up", "/user/password"].contains { url.path.hasPrefix($0) }
    }
    static let rules: String = {
        var rules: [[String: Any]] = [
            ["trigger": ["url-filter": ".*", "load-type": ["third-party"]], "action": ["type": "block"]]
        ]
        for domain in ["goodreads.com", "gr-assets.com", "amazon.com", "media-amazon.com", "ssl-images-amazon.com"] {
            let escaped = domain.replacingOccurrences(of: ".", with: #"\."#)
            for pattern in ["^https://" + escaped + "/", "^https://[^/]+\\." + escaped + "/"] {
                rules.append(["trigger": ["url-filter": pattern], "action": ["type": "ignore-previous-rules"]])
            }
        }
        for domain in ["www.google.com", "www.gstatic.com"] {
            let escaped = domain.replacingOccurrences(of: ".", with: #"\."#)
            rules.append(["trigger": ["url-filter": "^https://" + escaped + "/recaptcha/"], "action": ["type": "ignore-previous-rules"]])
        }
        for path in ["ads", "adclick", "adsystem", "analytics"] {
            rules.append(["trigger": ["url-filter": "^https://[^/]+/" + path + "/"], "action": ["type": "block"]])
        }
        return String(data: try! JSONSerialization.data(withJSONObject: rules), encoding: .utf8)!
    }()
}

struct GoodreadsCloudSnapshot: Codable, Equatable {
  let profileID: String?
  let books: [GoodreadsBook]
  let updatedAt: Date
  let deviceID: String
  var valid: Bool {
    func numeric(_ value: String) -> Bool { !value.isEmpty && value.count <= 30 && value.allSatisfy(\.isNumber) }
    return UUID(uuidString: deviceID) != nil && updatedAt.timeIntervalSinceReferenceDate.isFinite
      && (profileID.map(numeric) ?? true) && books.count <= 5000
      && books.allSatisfy { book in
        guard numeric(book.id), !book.title.isEmpty, book.title.count <= 1000, book.author.count <= 500,
          let url = URL(string: book.url), url.scheme == "https",
          ["goodreads.com", "www.goodreads.com"].contains(url.host?.lowercased() ?? ""),
          url.user == nil, url.password == nil else { return false }
        return true
      }
  }
  func newer(than other: Self) -> Bool {
    updatedAt > other.updatedAt || (updatedAt == other.updatedAt && deviceID > other.deviceID)
  }
}
