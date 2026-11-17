import Foundation
import Combine

@MainActor final class CloudLibrary: ObservableObject {
    @Published var status = "Checking iCloud…"
    @Published var syncing = false
    @Published var accountNeedsConfirmation = false
    @Published private(set) var lastChecked: Date?
    @Published var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: "cloudEnabled") } }
    private var container: URL?
    private let store: LibraryStore
    private var timer: Timer?
    private var pending: Task<Void,Never>?
    private var observers: [NSObjectProtocol] = []
    private var accountGeneration = 0
    private var quotaExceeded = false
    var activeBookID: UUID?
    weak var goodreads: GoodreadsConnection?
    init(store: LibraryStore) {
        self.store = store
        enabled = UserDefaults.standard.object(forKey: "cloudEnabled") as? Bool ?? true
        store.onChange = { [weak self] in self?.schedule() }
        observers.append(NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil, queue: .main) { [weak self] notification in
            let quota = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int == NSUbiquitousKeyValueStoreQuotaViolationChange
            Task { @MainActor in
                if quota { self?.quotaExceeded = true; self?.status = "iCloud progress storage is full. Book manifests retain progress; try syncing again later." }
                else { await self?.sync() }
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .NSUbiquityIdentityDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.accountChanged() }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in Task { @MainActor in await self?.sync() } }
    }
    deinit { timer?.invalidate(); pending?.cancel(); observers.forEach(NotificationCenter.default.removeObserver) }
    func accountChanged() {
        accountGeneration += 1; container = nil; pending?.cancel()
        accountNeedsConfirmation = true
        status = "iCloud account changed. Sync is paused; local books are retained. Confirm the current account in Settings before uploading."
    }
    func confirmCurrentAccount() {
        guard let token = FileManager.default.ubiquityIdentityToken,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: false) else {
            status = "Sign in to iCloud Drive before choosing an account."; return
        }
        UserDefaults.standard.set(data, forKey: "cloudAccountIdentity")
        accountNeedsConfirmation = false; container = nil; schedule()
    }
    private func verifyAccount() -> Bool {
        guard let current = FileManager.default.ubiquityIdentityToken else { return false }
        if let data = UserDefaults.standard.data(forKey: "cloudAccountIdentity") {
            guard Self.accountMatches(current, archived: data) else { accountChanged(); return false }
        } else if let data = try? NSKeyedArchiver.archivedData(withRootObject: current, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: "cloudAccountIdentity")
        }
        return true
    }
    nonisolated static func accountMatches(_ current: NSObjectProtocol, archived data: Data) -> Bool {
        guard data.count <= 65_536 else { return false }
        do {
            let reader = try NSKeyedUnarchiver(forReadingFrom: data)
            // Apple's opaque identity token guarantees NSCoding, not NSSecureCoding.
            reader.requiresSecureCoding = false
            reader.decodingFailurePolicy = .setErrorAndReturn
            let previous = reader.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
            reader.finishDecoding()
            return reader.error == nil && previous.map { current.isEqual($0) } == true
        } catch { return false }
    }
    func schedule() {
        pending?.cancel()
        pending = Task { try? await Task.sleep(for: .seconds(3)); guard !Task.isCancelled else { return }; await sync() }
    }
    func cloudRoot() async -> URL? {
        guard !accountNeedsConfirmation, verifyAccount() else { return nil }
        if let container { return container }
        let generation = accountGeneration
        let url = await Task.detached { FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.io.github.somamill.listen.mobile") }.value
        guard generation == accountGeneration else { return nil }
        container = url?.appendingPathComponent("Documents/Books", isDirectory: true)
        return container
    }
    static func hydrate(_ url: URL) async throws {
        let values = try url.resourceValues(forKeys: [.isUbiquitousItemKey,.ubiquitousItemDownloadingStatusKey])
        if values.isUbiquitousItem != true { return }
        if values.ubiquitousItemDownloadingStatus == .current || values.ubiquitousItemDownloadingStatus == .downloaded { return }
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        for _ in 0..<120 {
            try Task.checkCancellation()
            let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
            if status == .current || status == .downloaded { return }
            try await Task.sleep(for: .milliseconds(500))
        }
        throw ListenError.message("iCloud is still downloading. Keep the app open and try again when your connection is ready.")
    }
    nonisolated static func coordinatedCopy(_ source: URL, _ target: URL) throws {
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordinationError: NSError?; var operationError: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: .withoutChanges, writingItemAt: target, options: .forReplacing, error: &coordinationError) { from, to in
            do {
                let sourceValues = try from.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard sourceValues.isRegularFile == true, sourceValues.isSymbolicLink != true else { throw ListenError.message("iCloud audio must be a regular file.") }
                let temp = to.deletingLastPathComponent().appendingPathComponent(".incoming-\(UUID().uuidString)")
                defer { try? FileManager.default.removeItem(at: temp) }
                try FileManager.default.copyItem(at: from, to: temp)
                if FileManager.default.fileExists(atPath: to.path) { _ = try FileManager.default.replaceItemAt(to, withItemAt: temp) }
                else { try FileManager.default.moveItem(at: temp, to: to) }
            } catch { operationError = error }
        }
        if let error = coordinationError ?? operationError as NSError? { throw error }
    }
    nonisolated static func coordinatedRead(_ url: URL, limit: Int = 8_000_000) throws -> Data {
        var coordinationError: NSError?
        var result: Result<Data, Error> = .failure(ListenError.message("iCloud file could not be read."))
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { file in
            result = Result {
                let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
                guard values.isSymbolicLink != true, let size = values.fileSize, size <= limit else { throw ListenError.message("iCloud metadata is too large or is not a regular file.") }
                let data = try Data(contentsOf: file)
                guard data.count <= limit else { throw ListenError.message("iCloud metadata is too large.") }
                return data
            }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }
    nonisolated static func validBook(_ book: AudioBook, at url: URL) -> Bool {
        book.id.uuidString == url.deletingLastPathComponent().lastPathComponent && !book.tracks.isEmpty &&
        book.tracks.allSatisfy { safeFilename($0.filename) && $0.duration.isFinite && $0.duration > 0 } &&
        (book.coverFilename.map(safeFilename) ?? true) && book.state.position.isFinite && book.state.position >= 0 &&
        book.state.updatedAt.timeIntervalSince1970.isFinite && book.metadataUpdatedAt.timeIntervalSince1970.isFinite
    }
    nonisolated static func writeBook(_ book: AudioBook, at url: URL) throws {
        guard validBook(book, at: url) else { throw ListenError.message("Invalid iCloud book metadata.") }
        try coordinatedWrite(book, at: url) { local, remote in
            guard validBook(remote, at: url) else { throw ListenError.message("Invalid remote iCloud book metadata. Local files are retained.") }
            var merged = local; merged.merge(remote); return merged
        }
    }
    nonisolated static func coordinatedWrite<T: Codable>(_ value: T, at url: URL, merge: (T, T) throws -> T) throws {
        var coordinationError: NSError?; var operationError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { file in
            do {
                var merged = value
                let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: file) ?? []
                for source in [file] + conflicts.map(\.url) where FileManager.default.fileExists(atPath: source.path) {
                    let size = try source.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
                    guard size.isSymbolicLink != true, (size.fileSize ?? Int.max) <= 8_000_000 else { throw ListenError.message("Invalid iCloud metadata file.") }
                    merged = try merge(merged, JSONDecoder().decode(T.self, from: Data(contentsOf: source)))
                }
                let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
                let data = try encoder.encode(merged)
                guard data.count <= 8_000_000 else { throw ListenError.message("iCloud metadata is too large. Local data is retained.") }
                if (try? Data(contentsOf: file)) != data { try data.write(to: file, options: .atomic) }
                for conflict in conflicts { conflict.isResolved = true }
            } catch { operationError = error }
        }
        if let error = coordinationError ?? operationError as NSError? { throw error }
    }
    nonisolated static func progressFits(_ data: Data, key: String, values: [String: Any]) -> Bool {
        var proposed = values; proposed[key] = data
        guard proposed.count <= 1000,
              let bytes = try? PropertyListSerialization.data(fromPropertyList: proposed, format: .binary, options: 0) else { return false }
        return bytes.count <= 900_000
    }
    func sync() async {
        guard enabled else { status = "iCloud sync is off"; return }
        guard !accountNeedsConfirmation else { return }
        guard !syncing else { return }
        syncing = true; defer { syncing = false }
        guard let cloud = await cloudRoot() else { if !accountNeedsConfirmation { status = "iCloud unavailable. Sign in to iCloud and use a signed build with its iCloud capability enabled." }; return }
        let generation = accountGeneration
        let identity = FileManager.default.ubiquityIdentityToken
        do {
            try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
            var shelvesPending = false
            do {
                try await syncGoodreads(at: cloud.deletingLastPathComponent().appendingPathComponent("Goodreads", isDirectory: true))
            } catch {
                shelvesPending = true
                goodreads?.status = "Goodreads iCloud sync needs attention. Saved shelves are retained. \(error.localizedDescription)"
            }
            guard generation == accountGeneration else { return }
            // Import manifests before publishing. Files download only when opened.
            let directories = try FileManager.default.contentsOfDirectory(at: cloud, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            for directory in directories {
                guard UUID(uuidString: directory.lastPathComponent) != nil else { continue }
                let properties = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard properties.isDirectory == true, properties.isSymbolicLink != true else { continue }
                let manifest = directory.appendingPathComponent("book.json")
                try await Self.hydrate(manifest)
                guard generation == accountGeneration else { return }
                let data = try await Task.detached { try Self.coordinatedRead(manifest) }.value
                var remote = try JSONDecoder().decode(AudioBook.self, from: data)
                guard Self.validBook(remote, at: manifest) else { continue }
                if let index = store.books.firstIndex(where: { $0.id == remote.id }) {
                    let local = store.books[index]
                    if activeBookID == local.id { continue } // Never jump active playback to another device's position.
                    var merged = local; merged.merge(remote)
                    store.books[index] = merged
                } else { remote.ensureBasicMetadata(); store.books.append(remote) }
            }
            let values = NSUbiquitousKeyValueStore.default
            values.synchronize()
            var quotaLimited = false
            for index in store.books.indices {
                let key = "progress-" + store.books[index].id.uuidString
                if activeBookID != store.books[index].id, let data = values.data(forKey: key), let state = try? JSONDecoder().decode(ListeningState.self, from: data) { store.books[index].state.merge(state) }
                if let data = try? JSONEncoder().encode(store.books[index].state) {
                    if Self.progressFits(data, key: key, values: values.dictionaryRepresentation) { values.set(data, forKey: key) }
                    else { quotaLimited = true }
                }
            }
            store.save(notify: false)
            let snapshot = store.books; let root = store.root
            try await Task.detached {
                for book in snapshot {
                    guard FileManager.default.ubiquityIdentityToken?.isEqual(identity) == true else { throw ListenError.message("iCloud account changed during sync. Local books are retained.") }
                    let local = root.appendingPathComponent(book.id.uuidString, isDirectory: true)
                    let remote = cloud.appendingPathComponent(book.id.uuidString, isDirectory: true)
                    try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
                    for name in book.tracks.map(\.filename) + (book.coverFilename.map { [$0] } ?? []) {
                        let source = local.appendingPathComponent(name); let destination = remote.appendingPathComponent(name)
                        if FileManager.default.fileExists(atPath: source.path), !FileManager.default.fileExists(atPath: destination.path) { try Self.coordinatedCopy(source, destination) }
                    }
                    let path = remote.appendingPathComponent("book.json")
                    try Self.writeBook(book, at: path)
                }
            }.value
            guard generation == accountGeneration else { return }
            lastChecked = Date()
            status = "Library checked. iCloud Drive may still be uploading or downloading."
            if quotaLimited || quotaExceeded { status += " Progress storage is full; book manifests retain progress." }
            if shelvesPending { status += " Goodreads shelf sync needs attention." }
        } catch { status = "iCloud needs attention: \(error.localizedDescription)" }
    }
    func syncGoodreads(at directory: URL) async throws {
        let generation = accountGeneration
        guard let goodreads, goodreads.syncEnabled, !goodreads.showSignIn, !goodreads.refreshing else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey], options: .skipsHiddenFiles) {
            guard file.pathExtension == "json", UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil,
              try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { continue }
            try await Self.hydrate(file)
            guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 8_000_000 else { continue }
            guard generation == accountGeneration else { return }
            let data = try await Task.detached { try Self.coordinatedRead(file) }.value
            guard let snapshot = try? JSONDecoder().decode(GoodreadsCloudSnapshot.self, from: data), snapshot.valid else { continue }
            goodreads.applyCloud(snapshot)
        }
        let snapshot = goodreads.cloudSnapshot
        guard snapshot.updatedAt != .distantPast else { return }
        guard snapshot.valid, UUID(uuidString: goodreads.deviceID) != nil else {
            throw ListenError.message("Goodreads shelves could not be validated for iCloud. Check the imported profile and book identifiers.")
        }
        // Each device publishes its own snapshot, avoiding simultaneous-writer overwrites.
        let file = directory.appendingPathComponent(goodreads.deviceID + ".json")
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(snapshot)
        guard data.count <= 8_000_000 else { throw ListenError.message("Goodreads shelves are too large for this sync snapshot. Local shelves are retained.") }
        guard generation == accountGeneration else { return }
        try Self.coordinatedWrite(snapshot, at: file) { local, remote in
            guard remote.valid else { throw ListenError.message("Invalid Goodreads iCloud snapshot. Saved shelves are retained.") }
            return remote.newer(than: local) ? remote : local
        }
    }
    nonisolated static func safeFilename(_ name: String) -> Bool { !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\") }
    func download(_ book: AudioBook) async throws {
        guard let cloud = await cloudRoot() else { throw ListenError.message("This book is in iCloud. Sign in to iCloud and enable sync to download it.") }
        for name in book.tracks.map(\.filename) + (book.coverFilename.map { [$0] } ?? []) {
            let target = store.directory(book).appendingPathComponent(name)
            guard !FileManager.default.fileExists(atPath: target.path) else { continue }
            let source = cloud.appendingPathComponent(book.id.uuidString).appendingPathComponent(name)
            status = "Downloading \(book.title)…"; try await Self.hydrate(source)
            try await Task.detached { try Self.coordinatedCopy(source, target) }.value
        }
        status = "Available offline"
    }
}
