import AVFoundation
import Combine
import Foundation

@MainActor final class LibraryStore: ObservableObject {
  @Published var books: [AudioBook] = []
  @Published var busy = false
  @Published var processingBookID: UUID?
  @Published var activity = ""
  @Published var waitingImports = 0
  @Published var error: String?
  @Published var notice: String?
  let root: URL
  let deviceID: String
  var onChange: (() -> Void)?
  init(root: URL? = nil) {
    self.root =
      root
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Library", isDirectory: true)
    self.deviceID = UserDefaults.standard.string(forKey: "deviceID") ?? UUID().uuidString
    UserDefaults.standard.set(deviceID, forKey: "deviceID")
    do {
      try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
      let data = try Data(contentsOf: self.root.appendingPathComponent("index.json"))
      books = try JSONDecoder().decode([AudioBook].self, from: data)
      for index in books.indices { books[index].ensureBasicMetadata() }
    } catch CocoaError.fileReadNoSuchFile {} catch {
      self.error =
        "The saved library could not be read. Files have been retained. \(error.localizedDescription)"
    }
  }
  func directory(_ book: AudioBook) -> URL {
    root.appendingPathComponent(book.id.uuidString, isDirectory: true)
  }
  func file(_ book: AudioBook, _ track: AudioTrack) -> URL {
    directory(book).appendingPathComponent(track.filename)
  }
  func save(notify: Bool = true) {
    do {
      try JSONEncoder().encode(books).write(
        to: root.appendingPathComponent("index.json"), options: .atomic)
      if notify { onChange?() }
    } catch { self.error = "Could not save the library: \(error.localizedDescription)" }
  }
  func update(_ book: AudioBook) {
    guard let i = books.firstIndex(where: { $0.id == book.id }) else { return }
    books[i] = book
    books[i].ensureBasicMetadata()
    save()
  }
  func position(_ id: UUID, seconds: Double, finished: Bool? = nil) {
    guard let i = books.firstIndex(where: { $0.id == id }) else { return }
    books[i].state.position = max(0, min(seconds, books[i].duration))
    if let finished { books[i].state.finished = finished }
    books[i].state.updatedAt = Date()
    books[i].state.deviceID = deviceID
    save()
  }
  @discardableResult func importFiles(
    _ urls: [URL], combine: Bool = true, enrich: Bool = true, convert: Bool = true,
    title: String? = nil, author: String? = nil
  ) async -> [UUID] {
    let scope = urls.map { ($0, $0.startAccessingSecurityScopedResource()) }
    defer { for (url, active) in scope where active { url.stopAccessingSecurityScopedResource() } }
    waitingImports += 1
    while busy {
      do { try await Task.sleep(for: .milliseconds(150)) } catch {
        waitingImports -= 1
        return []
      }
    }
    waitingImports -= 1
    busy = true
    defer {
      busy = false
      processingBookID = nil
      activity = ""
    }
    notice = nil
    var warnings: [String] = []
    var created: [UUID] = []
    var expandedRoots: [URL] = []
    defer { for root in expandedRoots { try? FileManager.default.removeItem(at: root) } }
    do {
      var imported: [AudioBook] = []
      // Scope remains open through inspection and copying of external-provider files.
      let scoped = urls.map { ($0, $0.startAccessingSecurityScopedResource()) }
      defer {
        for (url, active) in scoped where active { url.stopAccessingSecurityScopedResource() }
      }
      var sources: [URL] = []
      var inputRoots: [URL] = []
      for url in urls {
        if url.pathExtension.lowercased() == "zip" {
          activity = "Checking and extracting archive…"
          let expanded = try await Task.detached { try ArchiveImporter.expand(url) }.value
          expandedRoots.append(expanded)
          inputRoots.append(expanded)
        } else {
          inputRoots.append(url)
        }
      }
      for url in inputRoots {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
          let items = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants])
          while let child = items?.nextObject() as? URL {
            if Importer.supported(child) { sources.append(child) }
          }
        } else if Importer.supported(url) {
          sources.append(url)
        }
      }
      guard !sources.isEmpty else {
        throw ListenError.message(
          "Choose MP3, M4B, M4A, FLAC, WAV, AAC, or AIFF files, or a folder containing them.")
      }
      sources.sort {
        let a = $0.deletingLastPathComponent().path, b = $1.deletingLastPathComponent().path
        return a == b ? $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending : a.localizedStandardCompare(b) == .orderedAscending
      }
      let groups: [[URL]]
      if combine, inputRoots.count == 1,
        (try? inputRoots[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
      {
        let base = inputRoots[0].standardizedFileURL
        let grouped = Dictionary(grouping: sources) { source -> String in
          var folder = source.deletingLastPathComponent().standardizedFileURL
          while folder != base
            && folder.lastPathComponent.range(
              of: #"^(?:disc|disk|cd)\s*[-_ ]?\d+$"#,
              options: [.regularExpression, .caseInsensitive]) != nil
          { folder.deleteLastPathComponent() }
          return folder.path
        }
        groups = grouped.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map {
          grouped[$0]!
        }
      } else {
        groups = combine ? [sources] : sources.map({ [$0] })
      }
      for group in groups {
        activity = "Importing \(group.first!.deletingPathExtension().lastPathComponent)…"
        var book = try await Importer.copy(group, into: root)
        // Server catalogue identity must precede online lookup and M4B tagging.
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { book.title = title }
        if let author, !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { book.author = author }
        processingBookID = book.id
        // Persist originals before optional work so an interrupted import remains recoverable.
        books.insert(book, at: 0)
        save()
        if enrich {
          activity = "Looking up book details…"
          do {
            book = try await MetadataService.enrich(book, directory: directory(book))
          } catch {
            warnings.append(
              "Online metadata was unavailable for \(book.title); embedded details were kept.")
          }
        }
        if enrich { book.metadataLookupAt = Date(); book.metadataRevision = 2 }
        book.conversionPending = convert && book.needsM4BConversion
        commitPrepared(book)
        if convert && book.needsM4BConversion {
          activity = "Converting to M4B…"
          do {
            book = try await M4BConverter.convert(book, directory: directory(book), progress: { [weak self] progress in
              self?.activity = progress >= 1 ? "Finishing chapters and checking audio…" : "Converting to M4B · \(Int(progress * 100))%"
            }, didConvert: { [weak self] in self?.commitPrepared($0) })
          } catch {
            warnings.append(
              "Original audio is ready. M4B creation was interrupted; finish the import with sovo. open. \(error.localizedDescription)")
          }
        }
        commitPrepared(book)
        processingBookID = nil
        imported.append(book)
        created.append(book.id)
      }
      notice = (["Imported \(imported.count) audiobook\(imported.count == 1 ? "" : "s")."] + warnings).joined(separator: " ")
    } catch { self.error = error.localizedDescription }
    return created
  }
  func refreshMissingMetadata() async {
    guard !busy else { return }
    busy = true
    defer { busy = false; activity = "" }
    for original in books where (original.metadataRevision ?? 0) < 2 || (MetadataService.needsEnrichment(original, directory: directory(original))
      && Date().timeIntervalSince(original.metadataLookupAt ?? .distantPast) > 86_400) {
      guard !Task.isCancelled, waitingImports == 0 else { return }
      activity = "Completing book details and genres…"
      let enriched = try? await MetadataService.enrich(original, directory: directory(original))
      guard let index = books.firstIndex(where: { $0.id == original.id }) else { continue }
      // Playback or manual edits may have changed the book while the network request ran.
      if var enriched, books[index].metadataUpdatedAt == original.metadataUpdatedAt {
        enriched.state = books[index].state; enriched.bookmarks = books[index].bookmarks
        books[index] = enriched
        books[index].metadataUpdatedAt = Date()
      }
      books[index].metadataLookupAt = Date()
      books[index].metadataRevision = 2
      save()
    }
  }
  func finishImport(_ id: UUID) async {
    guard !busy, var book = books.first(where: { $0.id == id }), book.needsM4BConversion else { return }
    busy = true; processingBookID = id
    defer { busy = false; processingBookID = nil; activity = "" }
    book.sourceTitle = book.sourceTitle ?? book.chapters.first?.title
    book.conversionPending = true; update(book)
    do {
      book = try await M4BConverter.convert(book, directory: directory(book), progress: { [weak self] progress in
        self?.activity = progress >= 1 ? "Finishing chapters and checking audio…" : "Converting to M4B · \(Int(progress * 100))%"
      }, didConvert: { [weak self] in self?.commitPrepared($0) })
      if let latest = books.first(where: { $0.id == id }) { book.state = latest.state; book.bookmarks = latest.bookmarks }
      update(book); notice = "M4B ready. Original files are retained."
    } catch { notice = "Original audio is ready. M4B creation was interrupted. Keep sovo. open and try Finish import again. \(error.localizedDescription)" }
  }
  private func commitPrepared(_ converted: AudioBook) {
    guard let latest = books.first(where: { $0.id == converted.id }) else { return }
    var book = converted; book.state = latest.state; book.bookmarks = latest.bookmarks
    update(book)
  }
  func remove(_ book: AudioBook) {
    // Local removal only. No cloud deletion is implied, so another device can restore it.
    do {
      if FileManager.default.fileExists(atPath: directory(book).path) { try FileManager.default.removeItem(at: directory(book)) }
      books.removeAll { $0.id == book.id }
      save()
    } catch { self.error = error.localizedDescription }
  }
}
