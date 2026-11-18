import SwiftUI
import AVFoundation

@main @MainActor struct ListenApp: App {
  @StateObject private var store: LibraryStore
  @StateObject private var cloud: CloudLibrary
  @StateObject private var player: AudioController
  @StateObject private var goodreads: GoodreadsConnection
  @StateObject private var servers: ServerLibrary
  @StateObject private var transfer: LocalTransfer
  @Environment(\.scenePhase) private var phase
  @AppStorage("appearance") private var appearance = "system"
  init() {
    #if DEBUG
    let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
    #else
    let testing = false
    #endif
    let root =
      testing
      ? FileManager.default.temporaryDirectory.appendingPathComponent("listen-ui-tests") : nil
    if testing && !ProcessInfo.processInfo.arguments.contains("--uitesting-preserve") {
      try? FileManager.default.removeItem(at: root!)
      UserDefaults.standard.set(false, forKey: "cloudEnabled")
    }
    let library = LibraryStore(root: root)
    let sync = CloudLibrary(store: library)
    _store = StateObject(wrappedValue: library)
    _cloud = StateObject(wrappedValue: sync)
    let audio = AudioController(store: library, cloud: sync)
    _player = StateObject(wrappedValue: audio)
    MobileCompanionBridge.store = library
    MobileCompanionBridge.player = audio
    let reading = GoodreadsConnection()
    sync.goodreads = reading
    reading.onChange = { [weak sync] in sync?.schedule() }
    _goodreads = StateObject(wrappedValue: reading)
    _servers = StateObject(wrappedValue: ServerLibrary(root: library.root))
    _transfer = StateObject(wrappedValue: LocalTransfer())
    #if DEBUG
    if testing && library.books.isEmpty {
      let sample = FileManager.default.temporaryDirectory.appendingPathComponent("Sample recording.wav")
      if let format = AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 1),
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96_000) {
        buffer.frameLength = 96_000
        if let samples = buffer.floatChannelData?[0] { samples.initialize(repeating: 0, count: 96_000) }
        if let file = try? AVAudioFile(forWriting: sample, settings: format.settings) {
          try? file.write(from: buffer)
          Task { await library.importFiles([sample], enrich: false, convert: false) }
        }
      }
    }
    #endif
  }
  var body: some Scene {
    WindowGroup {
      RootView().environmentObject(store).environmentObject(cloud).environmentObject(player)
        .environmentObject(goodreads).environmentObject(servers).environmentObject(transfer)
        .tint(ListenTheme.accent).preferredColorScheme(
          appearance == "system" ? nil : appearance == "dark" ? .dark : .light
        )
        .task {
          await cloud.sync()
          #if DEBUG
          if ProcessInfo.processInfo.arguments.contains("--uitesting") { return }
          #endif
          await store.refreshMissingMetadata()
        }
        .onChange(of: phase) { _, next in
          if next == .active {
            Task {
              await cloud.sync()
              await MobileCompanionBridge.importShared(store)
              if UserDefaults.standard.bool(forKey: "intentContinue") {
                UserDefaults.standard.set(false, forKey: "intentContinue")
                await MobileCompanionBridge.open()
              }
              #if DEBUG
              if ProcessInfo.processInfo.arguments.contains("--uitesting") { return }
              #endif
              await store.refreshMissingMetadata()
            }
            if goodreads.profileID != nil { goodreads.refresh() }
          } else {
            player.persist()
            cloud.schedule()
            if next == .background { transfer.stop() }
          }
        }
        .onOpenURL { url in
          if url.scheme == "listen-mobile" {
            Task {
              await MobileCompanionBridge.open(
                url.host == "book" ? url.pathComponents.last.flatMap(UUID.init(uuidString:)) : nil)
            }
          } else if url.isFileURL {
            Task {
              await store.importFiles(
                [url],
                enrich: true)
            }
          }
        }
    }
  }
}
