import AVFoundation
import UIKit
import XCTest

@testable import Listen

@MainActor final class ListenTests: XCTestCase {
  var root: URL!
  override func setUp() {
    super.setUp()
    root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }
  override func tearDown() {
    try? FileManager.default.removeItem(at: root)
    super.tearDown()
  }
  func testSpokenAudioSessionUsesValidPlaybackOptions() throws {
    try AudioController.configureSessionCategory()
    let session = AVAudioSession.sharedInstance()
    XCTAssertEqual(session.category, .playback)
    XCTAssertEqual(session.mode, .spokenAudio)
    XCTAssertFalse(session.categoryOptions.contains(.allowAirPlay))
    XCTAssertFalse(session.categoryOptions.contains(.allowBluetoothA2DP))
  }
  func testCorruptLibraryIndexRetainsImportedMedia() throws {
    let library = root.appendingPathComponent("library")
    try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
    let media = library.appendingPathComponent("original.mp3")
    let original = Data("user media must survive a corrupt index".utf8)
    try original.write(to: media)
    let index = library.appendingPathComponent("index.json")
    try Data("{interrupted index".utf8).write(to: index)
    let store = LibraryStore(root: library)
    XCTAssertNotNil(store.error)
    XCTAssertTrue(store.books.isEmpty)
    XCTAssertEqual(try Data(contentsOf: media), original)
    XCTAssertEqual(try String(contentsOf: index, encoding: .utf8), "{interrupted index")
  }
  func testProgressConflictResolutionAndTrackBoundaries() {
    var book = AudioBook(
      title: "Test",
      tracks: [
        AudioTrack(filename: "1.mp3", duration: 10), AudioTrack(filename: "2.mp3", duration: 20),
      ])
    XCTAssertEqual(book.trackPosition(at: 15).index, 1)
    XCTAssertEqual(book.trackPosition(at: 15).offset, 5)
    XCTAssertEqual(book.trackPosition(at: 10).index, 1)
    XCTAssertEqual(book.trackPosition(at: 100).offset, 20)
    book.state = ListeningState(
      position: 4, updatedAt: Date(timeIntervalSince1970: 10), deviceID: "a")
    book.state.merge(
      ListeningState(position: 2, updatedAt: Date(timeIntervalSince1970: 9), deviceID: "b"))
    XCTAssertEqual(book.state.position, 4)
    book.state.merge(
      ListeningState(position: 8, updatedAt: Date(timeIntervalSince1970: 11), deviceID: "b"))
    XCTAssertEqual(book.state.position, 8)
  }
  func testGoodreadsCSVPreservesShelvesQuotesAndCommas() throws {
    let csv =
      "Book Id,Title,Author,Exclusive Shelf\n1,\"A book, with commas\",An Author,to-read\n2,\"A \"\"quoted\"\" title\",Another Author,read\n3,Third,Third Author,currently-reading\n"
    let books = try GoodreadsConnection.parseCSV(csv)
    XCTAssertEqual(books.count, 3)
    XCTAssertEqual(books[0].title, "A book, with commas")
    XCTAssertEqual(books[1].title, "A \"quoted\" title")
    XCTAssertEqual(books.map(\.shelf), ["to-read", "read", "currently-reading"])
    XCTAssertThrowsError(try GoodreadsConnection.parseCSV("Book Id,Title,Author\n1,\"unfinished,A"))
  }
  func testMetadataConfidenceAndCloudPaths() {
    XCTAssertGreaterThan(
      MetadataService.confidence(
        "A Short History of Nearly Everything", "A Short History of Nearly Everything"), 0.99)
    XCTAssertLessThan(
      MetadataService.confidence(
        "A Short History of Nearly Everything", "A Completely Different Novel"), 0.4)
    XCTAssertTrue(CloudLibrary.safeFilename("book.m4b"))
    XCTAssertFalse(CloudLibrary.safeFilename("../book.mp3"))
    XCTAssertFalse(CloudLibrary.safeFilename("a/b.mp3"))
  }
  func testGoodreadsRefreshDoesNotInterruptVisibleConnection() {
    let connection = GoodreadsConnection()
    connection.profileID = "123"
    connection.showSignIn = true
    let status = connection.status
    connection.refresh()
    XCTAssertFalse(connection.refreshing)
    XCTAssertEqual(connection.status, status)
  }
  func testMetadataPrefersMatchingAuthorAndRejectsAmbiguousTitles() {
    let wrong = MetadataService.Candidate(title: "Home", author: "Other Writer", cover: nil)
    let correct = MetadataService.Candidate(title: "Home (Unabridged)", author: "Toni Morrison", cover: nil)
    var book = AudioBook(title: "Home", author: "Toni Morrison")
    XCTAssertEqual(MetadataService.bestMatch([wrong, correct], for: book)?.author, "Toni Morrison")
    book.author = "Unknown author"
    XCTAssertNil(MetadataService.bestMatch([wrong, correct], for: book))
    XCTAssertNil(MetadataService.bestMatch([.init(title: "Home", author: "", cover: nil)], for: book))
    XCTAssertEqual(MetadataService.confidence("Der Vorleser – Hörbuch, ungekürzt", "Der Vorleser"), 1)
  }
  func testMetadataFallsBackToOpenLibraryAndStoresLargeCover() async throws {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 316, height: 500)).jpegData(withCompressionQuality: 0.9) { context in
      UIColor.green.setFill(); context.fill(CGRect(x: 0, y: 0, width: 316, height: 500))
    }
    MetadataURLProtocol.responses = [
      "itunes.apple.com": Data(#"{"results":[{"collectionName":"Home","artistName":"Wrong Writer"}]}"#.utf8),
      "openlibrary.org": Data(#"{"docs":[{"title":"Home","author_name":["Toni Morrison"],"cover_i":123,"subject":["Fiction"]}]}"#.utf8),
      "covers.openlibrary.org": image
    ]
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [MetadataURLProtocol.self]
    let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
    let book = AudioBook(title: "Home", author: "Toni Morrison")
    let enriched = try await MetadataService.enrich(book, directory: root, session: session)
    XCTAssertEqual(enriched.author, "Toni Morrison")
    XCTAssertEqual(enriched.coverFilename, "cover.jpg")
    let cover = try XCTUnwrap(UIImage(contentsOfFile: root.appendingPathComponent("cover.jpg").path))
    XCTAssertGreaterThanOrEqual(cover.size.width, 316)
    // Existing tags and artwork are authoritative; no lookup should be needed.
    MetadataURLProtocol.responses = [:]
    let preserved = try await MetadataService.enrich(enriched, directory: root, session: session)
    XCTAssertEqual(preserved, enriched)
  }
  func testReadingWeekAndStreakUseRecordedTimeWithoutInventedDays() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    let earlier = calendar.date(byAdding: .day, value: -2, to: today)!
    var snapshot = ActivitySnapshot()
    snapshot.secondsByDay = [ListeningActivity.dayKey(yesterday): 120, ListeningActivity.dayKey(earlier): 60]
    XCTAssertEqual(snapshot.currentStreak(ending: today), 2)
    XCTAssertEqual(snapshot.recentDays(ending: today).count, 7)
    XCTAssertEqual(snapshot.recentDays(ending: today).reduce(0) { $0 + $1.seconds }, 180)
    snapshot.secondsByDay[ListeningActivity.dayKey(today)] = 30
    XCTAssertEqual(snapshot.currentStreak(ending: today), 3)
    XCTAssertEqual(ActivitySnapshot().currentStreak(ending: today), 0)
  }
  func testExistingLibraryDecodesWithoutMetadataLookupDate() throws {
    let data = try JSONEncoder().encode(AudioBook(title: "Existing book"))
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object.removeValue(forKey: "metadataLookupAt")
    let decoded = try JSONDecoder().decode(AudioBook.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertNil(decoded.metadataLookupAt)
    XCTAssertEqual(decoded.title, "Existing book")
  }
  func testEveryRecordHasBasicMetadataWithoutInventingBibliographicFacts() {
    var book = AudioBook(title: " ", author: "", tracks: [.init(filename: "0001-My Book.mp3", duration: 10)])
    book.ensureBasicMetadata()
    XCTAssertEqual(book.title, "My Book")
    XCTAssertEqual(book.author, "Unknown author")
    XCTAssertEqual(book.genre, "Uncategorized")
    var empty = AudioBook(title: "")
    empty.ensureBasicMetadata()
    XCTAssertEqual(empty.title, "Untitled audiobook")
  }
  func testLegacyCloudMetadataKeepsGenreAndNewestProgress() {
    var book = AudioBook(title: "Known book", author: "An Author", genre: "Fantasy")
    book.metadataUpdatedAt = Date(timeIntervalSince1970: 10)
    book.metadataLookupAt = Date(timeIntervalSince1970: 9)
    var legacy = book
    legacy.genre = nil; legacy.metadataLookupAt = nil
    legacy.metadataUpdatedAt = Date(timeIntervalSince1970: 11)
    legacy.state = ListeningState(position: 20, updatedAt: Date(timeIntervalSince1970: 12))
    book.merge(legacy)
    XCTAssertEqual(book.genre, "Fantasy")
    XCTAssertEqual(book.state.position, 20)
    XCTAssertEqual(book.metadataLookupAt, Date(timeIntervalSince1970: 9))
  }
  func testServerMetadataPrecedesAutomaticConversion() async throws {
    let store = LibraryStore(root: root.appendingPathComponent("server-metadata"))
    await store.importFiles([try sample()], enrich: false, title: "Server book title", author: "A Known Writer")
    let book = try XCTUnwrap(store.books.first)
    XCTAssertEqual(book.title, "Server book title")
    XCTAssertEqual(book.author, "A Known Writer")
    let asset = AVURLAsset(url: store.file(book, try XCTUnwrap(book.tracks.first)))
    let metadata = try await asset.load(.commonMetadata)
    let title = try await AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierTitle).first?.load(.stringValue)
    XCTAssertEqual(title, "Server book title")
  }
  func testGenreClassificationAndInitialledAuthors() {
    XCTAssertEqual(BookGenre.classify(["Fiction", "Fantasy fiction"]), .fantasy)
    XCTAssertEqual(BookGenre.classify(["Non Fiction", "Sachbücher"]), .nonfiction)
    XCTAssertEqual(BookGenre.classify(["Science Fiction"]), .scienceFiction)
    XCTAssertEqual(BookGenre.classify(["Biographies & Memoirs"]), .biography)
    XCTAssertEqual(BookGenre.classify(["Kriminalroman"]), .crime)
    XCTAssertEqual(BookGenre.classify(["Audiobooks", "Books"]), .uncategorized)
    XCTAssertTrue(MetadataService.authorMatches("JRR Tolkien", "J. R. R. Tolkien"))
    XCTAssertFalse(MetadataService.authorMatches("John Smith", "Jane Smith"))
    XCTAssertEqual(AudioBook(title: "A book").genreLabel, "Uncategorized")
  }
  func testGoodreadsSnapshotValidationAndConflictOrder() throws {
    let a = GoodreadsCloudSnapshot(profileID: "123", books: [], updatedAt: Date(timeIntervalSince1970: 10), deviceID: "00000000-0000-0000-0000-000000000001")
    let b = GoodreadsCloudSnapshot(profileID: "123", books: [], updatedAt: a.updatedAt, deviceID: "00000000-0000-0000-0000-000000000002")
    XCTAssertTrue(a.valid); XCTAssertTrue(b.newer(than: a)); XCTAssertFalse(a.newer(than: b))
    let invalid = GoodreadsCloudSnapshot(profileID: "../private", books: [], updatedAt: Date(), deviceID: a.deviceID)
    XCTAssertFalse(invalid.valid)
    let restored = try JSONDecoder().decode(GoodreadsCloudSnapshot.self, from: JSONEncoder().encode(a))
    XCTAssertEqual(restored, a)
  }
  func testGoodreadsCloudRoundTripPreservesRevisionAndLocalDisconnect() async throws {
    let defaults = UserDefaults.standard
    let oldDevice = defaults.object(forKey: "deviceID"), oldSync = defaults.object(forKey: "goodreadsCloudSync"), oldProfile = defaults.object(forKey: "goodreadsProfileID")
    defer {
      defaults.set(oldDevice, forKey: "deviceID"); defaults.set(oldSync, forKey: "goodreadsCloudSync"); defaults.set(oldProfile, forKey: "goodreadsProfileID")
    }
    defaults.set(true, forKey: "goodreadsCloudSync")
    defaults.set(UUID().uuidString, forKey: "deviceID")
    let a = GoodreadsConnection(root: root.appendingPathComponent("reader-a"))
    let csv = root.appendingPathComponent("shelves.csv")
    try "Book Id,Title,Author,Exclusive Shelf\n1,Original tutorial,An Author,to-read\n".write(to: csv, atomically: true, encoding: .utf8)
    a.importCSV(csv)
    let cloudA = CloudLibrary(store: LibraryStore(root: root.appendingPathComponent("library-a"))); cloudA.enabled = false; cloudA.goodreads = a
    let shared = root.appendingPathComponent("fake-private-cloud")
    try await cloudA.syncGoodreads(at: shared)
    defaults.set(UUID().uuidString, forKey: "deviceID")
    let b = GoodreadsConnection(root: root.appendingPathComponent("reader-b"))
    let cloudB = CloudLibrary(store: LibraryStore(root: root.appendingPathComponent("library-b"))); cloudB.enabled = false; cloudB.goodreads = b
    try await cloudB.syncGoodreads(at: shared)
    XCTAssertEqual(b.books, a.books)
    XCTAssertEqual(b.cloudSnapshot.deviceID, a.cloudSnapshot.deviceID)
    let data = try Data(contentsOf: shared.appendingPathComponent(b.deviceID + ".json"))
    let keys = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys
    XCTAssertTrue(Set(keys).isSubset(of: ["profileID", "books", "updatedAt", "deviceID"]))
    b.disconnect()
    try await cloudB.syncGoodreads(at: shared)
    try await cloudA.syncGoodreads(at: shared)
    XCTAssertEqual(a.books.count, 1)
    XCTAssertTrue(b.books.isEmpty)
    XCTAssertFalse(b.syncEnabled)
  }
  func testSystemPauseDoesNotRestartQueuedBookOnLateCompletion() async throws {
    let store = LibraryStore(root: root.appendingPathComponent("sleep-pause"))
    await store.importFiles([try sample(), try sample()], combine: false, enrich: false, convert: false)
    let first = try XCTUnwrap(store.books.first)
    let second = try XCTUnwrap(store.books.last)
    let cloud = CloudLibrary(store: store); cloud.enabled = false
    let player = AudioController(store: store, cloud: cloud)
    await player.open(first)
    player.enqueue(second.id)
    let item = try XCTUnwrap(player.player?.currentItem)
    player.pause()
    NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: item)
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertFalse(player.playing)
    XCTAssertEqual(player.bookID, first.id)
    XCTAssertEqual(player.queue, [second.id])
  }
  func testChapterAtomPatchesFastStartChunkOffsets() throws {
    let entry = MP4Chapters.bytes(4, count: 4) + Data([0, 0, 0, 0])
    let stco = try MP4Chapters.atom(
      "stco",
      Data(repeating: 0, count: 4) + MP4Chapters.bytes(1, count: 4)
        + MP4Chapters.bytes(1000, count: 4))
    let patched = try MP4Chapters.patchOffsets(stco, threshold: 100, delta: 50)
    XCTAssertEqual(try MP4Chapters.number(patched, 16..<20), 1050)
    let atom = try MP4Chapters.chapterAtom([
      Chapter(title: "Start", start: 0), Chapter(title: "Second", start: 12.5),
    ])
    XCTAssertEqual(String(data: atom[4..<8], encoding: .ascii), "chpl")
    XCTAssertEqual(atom[16], 2)
    XCTAssertThrowsError(try MP4Chapters.boxes(entry))
  }
  func sample() throws -> URL {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "Sample", withExtension: "mp3"))
    guard try Data(contentsOf: url).count > 90_000 else {
      throw ListenError.message(
        "The packaged sample audio is missing or empty. Hydrate source resources and rebuild.")
    }
    return url
  }
  func testImportAndRealAACConversionRetainSourcesAndChapters() async throws {
    let source = try sample()
    let first = root.appendingPathComponent("01.mp3")
    let second = root.appendingPathComponent("02.mp3")
    try FileManager.default.copyItem(at: source, to: first)
    try FileManager.default.copyItem(at: source, to: second)
    var book = try await Importer.copy([first, second], into: root)
    book.genre = "Fantasy"
    XCTAssertEqual(book.tracks.count, 2)
    XCTAssertEqual(book.chapters.count, 2)
    XCTAssertGreaterThan(book.duration, 23)
    let directory = root.appendingPathComponent(book.id.uuidString)
    let result = try await M4BConverter.convert(book, directory: directory)
    let secondConversion = try await M4BConverter.convert(result, directory: directory)
    XCTAssertEqual(secondConversion, result)
    XCTAssertEqual(result.tracks.count, 1)
    XCTAssertTrue(result.tracks[0].filename.hasSuffix(".m4b"))
    XCTAssertEqual(result.chapters.count, 2)
    let output = directory.appendingPathComponent(result.tracks[0].filename)
    let asset = AVURLAsset(url: output)
    let playable = try await asset.load(.isPlayable)
    XCTAssertTrue(playable)
    let convertedDuration = try await asset.load(.duration).seconds
    XCTAssertEqual(convertedDuration, book.duration, accuracy: 1)
    let audio = try await asset.loadTracks(withMediaType: .audio)
    let descriptions = try await audio[0].load(.formatDescriptions)
    XCTAssertEqual(CMFormatDescriptionGetMediaSubType(descriptions[0]), kAudioFormatMPEG4AAC)
    XCTAssertTrue(try Data(contentsOf: output).range(of: Data("chpl".utf8)) != nil)
    let readChapters = try MP4Chapters.read(from: output)
    XCTAssertEqual(readChapters.count, 2)
    XCTAssertEqual(readChapters[1].start, book.chapters[1].start, accuracy: 0.01)
    let reimported = try await Importer.copy([output], into: root)
    XCTAssertEqual(reimported.chapters.count, 2)
    XCTAssertEqual(reimported.genreLabel, "Fantasy")
    let evidence = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("verified-conversion.m4b")
    try? FileManager.default.removeItem(at: evidence)
    try FileManager.default.copyItem(at: output, to: evidence)
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent(book.tracks[0].filename).path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
  }
  func testFolderImportKeepsBookSubfoldersSeparate() async throws {
    let inbox = root.appendingPathComponent("Inbox")
    let one = inbox.appendingPathComponent("Book One")
    let two = inbox.appendingPathComponent("Book Two")
    try FileManager.default.createDirectory(at: one, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: two, withIntermediateDirectories: true)
    for path in [
      one.appendingPathComponent("01.mp3"), one.appendingPathComponent("02.mp3"),
      two.appendingPathComponent("01.mp3"),
    ] { try FileManager.default.copyItem(at: sample(), to: path) }
    let store = LibraryStore(root: root.appendingPathComponent("Books"))
    await store.importFiles([inbox], combine: true, enrich: false)
    XCTAssertEqual(store.books.count, 2)
    XCTAssertEqual(store.books.map { $0.chapters.count }.sorted(), [1, 2])
    XCTAssertTrue(store.books.allSatisfy { $0.tracks.count == 1 && $0.tracks[0].filename.hasSuffix(".m4b") }, store.notice ?? "No import notice")
    XCTAssertNil(store.error)
  }

  func testSeekingInFinishedBookReturnsItToListening() async throws {
    let store = LibraryStore(root: root.appendingPathComponent("replay"))
    await store.importFiles([try sample()], enrich: false)
    let imported = try XCTUnwrap(store.books.first)
    store.position(imported.id, seconds: imported.duration, finished: true)
    let cloud = CloudLibrary(store: store)
    cloud.enabled = false
    let player = AudioController(store: store, cloud: cloud)
    await player.open(try XCTUnwrap(store.books.first), autoplay: false)
    XCTAssertTrue(try XCTUnwrap(store.books.first).state.finished)
    player.seek(3)
    XCTAssertFalse(try XCTUnwrap(store.books.first).state.finished)
    XCTAssertEqual(try XCTUnwrap(store.books.first).state.position, 3, accuracy: 0.1)
    player.pause()
  }
  func testLibraryPersistenceAndPlayback() async throws {
    let store = LibraryStore(root: root.appendingPathComponent("library"))
    await store.importFiles([try sample()], enrich: false)
    XCTAssertEqual(store.books.count, 1)
    XCTAssertNil(store.error)
    let book = try XCTUnwrap(store.books.first)
    let cloud = CloudLibrary(store: store)
    cloud.enabled = false
    let player = AudioController(store: store, cloud: cloud)
    await player.open(book)
    XCTAssertTrue(player.playing)
    try await Task.sleep(for: .seconds(2))
    player.tick()
    XCTAssertGreaterThan(player.position, 0)
    player.bookmark()
    player.pause()
    XCTAssertFalse(player.playing)
    let reopened = LibraryStore(root: store.root)
    XCTAssertEqual(reopened.books.first?.bookmarks.filter { $0.kind == nil }.count, 1)
    XCTAssertGreaterThan(reopened.books.first?.state.position ?? 0, 0)
  }
}

private final class MetadataURLProtocol: URLProtocol {
  static var responses: [String: Data] = [:]
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    guard let url = request.url, let data = Self.responses[url.host ?? ""] else {
      client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable)); return
    }
    client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() { }
}
