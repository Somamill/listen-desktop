import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var cloud: CloudLibrary
  @EnvironmentObject var player: AudioController
  @EnvironmentObject var goodreads: GoodreadsConnection
  @AppStorage("readerName") private var readerName = ""
  @AppStorage("smartRewind") private var rewind = true
  @AppStorage("appearance") private var appearance = "system"
  @State private var disconnect = false
  @AppStorage("rewindLimit") private var rewindLimit = 30.0
  @AppStorage("skipForward") private var skipForward = 30.0
  @AppStorage("skipBackward") private var skipBackward = 15.0
  @AppStorage("fadeSleep") private var fadeSleep = true
  @AppStorage("recoveryBookmarks") private var recoveryBookmarks = true
  @AppStorage("autoplayNext") private var autoplayNext = true
  var body: some View {
    NavigationStack {
      Form {
        Section("Library & iCloud") {
          Toggle("iCloud sync", isOn: $cloud.enabled).onChange(
            of: cloud.enabled
          ) { _, _ in Task { await cloud.sync() } }
          Text(cloud.status).font(.footnote).foregroundStyle(.secondary)
          Toggle("Sync Goodreads shelves with iCloud", isOn: $goodreads.syncEnabled).disabled(!cloud.enabled)
          Text("Shares your Goodreads profile link and saved shelves between your devices. Passwords and website sessions stay on each device; signing in again may be needed.")
            .font(.footnote).foregroundStyle(.secondary)
          Button("Sync now", systemImage: "arrow.triangle.2.circlepath") {
            Task { await cloud.sync() }
          }.disabled(cloud.syncing || !cloud.enabled)
          Text(
            "Books download before playback and remain available offline. Signed builds need an enabled iCloud container. This app’s iCloud library is separate from your Mac’s existing audiobook folder; use Files to import from it."
          ).font(.footnote).foregroundStyle(.secondary)
        }
        Section("Your library") {
          Text("New imports automatically find metadata and covers, then create one M4B audiobook when conversion is needed. Existing M4B files are not converted again.")
          Text("Embedded tags and covers come first. Missing details are matched against Apple Books and Open Library using the title and author; audio is never uploaded. Original audio stays on your device. AAC conversion is lossy and needs extra storage.")
            .font(.footnote).foregroundStyle(.secondary)
        }
        Section("You") {
          TextField("Your name (optional)", text: $readerName).textContentType(.nickname)
          Text("Only used for your reading page on this device. No account is created.")
            .font(.footnote).foregroundStyle(.secondary)
        }
        Section("Connections") {
          NavigationLink { MediaServersView() } label: {
            Label("Media servers", systemImage: "externaldrive")
          }.accessibilityIdentifier("mediaServersSettings")
          NavigationLink { GoodreadsView() } label: {
            Label("Goodreads", systemImage: "book.closed")
          }.accessibilityIdentifier("goodreadsSettings")
        }
        Section("Playback") {
          Toggle("Smart rewind after a pause", isOn: $rewind)
          Slider(value: $rewindLimit, in: 5...60, step: 5) { Text("Maximum smart rewind") }
          Text("Smart rewind limit: \(Int(rewindLimit)) seconds").font(.footnote)
          Picker("Forward skip", selection: $skipForward) {
            ForEach([5.0, 10, 15, 30, 45, 60, 90], id: \.self) {
              Text("\(Int($0)) seconds").tag($0)
            }
          }
          Picker("Backward skip", selection: $skipBackward) {
            ForEach([5.0, 10, 15, 30, 45, 60, 90], id: \.self) {
              Text("\(Int($0)) seconds").tag($0)
            }
          }
          Toggle("Fade before sleep timer ends", isOn: $fadeSleep)
          Toggle("Save automatic recovery bookmarks", isOn: $recoveryBookmarks)
          Toggle("Continue with next book in folder", isOn: $autoplayNext)
          Toggle("Volume boost", isOn: $player.boost)
          Text(
            "Boost doubles quiet PCM audio levels and limits peaks. It can be much louder; use care with headphones."
          ).font(.footnote).foregroundStyle(.secondary)
          Text(
            "Smart rewind increases with the length of a pause. Speed, sleep timer, chapters, bookmarks, and AirPlay are in the player."
          ).font(.footnote).foregroundStyle(.secondary)
        }
        Section("Sleep") {
          NavigationLink { AirPodsSleepHelp() } label: {
            Label("Pause when you fall asleep", systemImage: "moon.zzz")
          }.accessibilityIdentifier("airPodsSleepHelp")
        }
        Section("Appearance") {
          Picker("Appearance", selection: $appearance) {
            Text("Follow system").tag("system")
            Text("Light").tag("light")
            Text("Dark").tag("dark")
          }
        }
        Section("Goodreads") {
          Text(
            "An independent in-app website session. Goodreads may expire your login or change its pages; CSV import remains available. No Goodreads password or cookie is shared through iCloud."
          ).font(.footnote).foregroundStyle(.secondary)
          Button("Disconnect Goodreads", role: .destructive) { disconnect = true }.disabled(
            goodreads.books.isEmpty && goodreads.profileID == nil)
        }
        Section("About sovo.") {
          LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
          Text("Part of dot.").font(.headline)
          Text("A quieter way to read, listen, and learn.").foregroundStyle(.secondary)
          Link("Source & setup", destination: URL(string: "https://github.com/Somamill/listen")!)
          Text(
            "For DRM-free audio you have permission to use. No torrent client, torrent catalog, advertising, or analytics is included."
          ).font(.footnote).foregroundStyle(.secondary)
        }
      }.navigationTitle("Settings").confirmationDialog(
        "Disconnect Goodreads on this device?", isPresented: $disconnect, titleVisibility: .visible
      ) { Button("Disconnect", role: .destructive) { goodreads.disconnect() } }
    }
  }
}
