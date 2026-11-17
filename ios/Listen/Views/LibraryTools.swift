import SwiftUI
import Charts

struct FolderChooser: View {
  let books: [AudioBook]
  let path: String
  let select: (String?) -> Void
  @Environment(\.dismiss) var dismiss
  var body: some View {
    List {
      Button(path.isEmpty ? "Show all books" : "Show this folder") {
        select(path.isEmpty ? nil : path)
        dismiss()
      }
      ForEach(FolderPath.children(of: path, in: books), id: \.self) { child in
        NavigationLink {
          FolderChooser(books: books, path: child, select: select)
        } label: {
          Label(child.split(separator: "/").last.map(String.init) ?? child, systemImage: "folder")
        }
      }
    }.navigationTitle(
      path.isEmpty ? "Folders" : path.split(separator: "/").last.map(String.init) ?? "Folder")
  }
}
struct PlaybackQueueView: View {
  @EnvironmentObject var player: AudioController
  @EnvironmentObject var store: LibraryStore
  @Environment(\.dismiss) var dismiss
  var body: some View {
    NavigationStack {
      List {
        if player.queue.isEmpty {
          ContentUnavailableView(
            "Nothing queued yet", systemImage: "list.bullet",
            description: Text("Touch and hold a book to choose Play Next or Add to Queue."))
        }
        ForEach(Array(player.queue.enumerated()), id: \.element) { index, id in
          if let book = store.books.first(where: { $0.id == id }) {
            Button {
              player.queue.remove(at: index)
              Task { await player.open(book) }
              dismiss()
            } label: {
              VStack(alignment: .leading) {
                Text(book.title)
                Text(book.author).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
        }.onMove { player.queue.move(fromOffsets: $0, toOffset: $1) }.onDelete {
          player.queue.remove(atOffsets: $0)
        }
      }.navigationTitle("Up next").toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        ToolbarItem(placement: .primaryAction) { EditButton() }
        ToolbarItem(placement: .secondaryAction) {
          Button("Shuffle", systemImage: "shuffle") { player.queue.shuffle() }.disabled(
            player.queue.count < 2)
        }
        ToolbarItem(placement: .secondaryAction) {
          Button("Clear", role: .destructive) { player.queue = [] }.disabled(player.queue.isEmpty)
        }
      }
    }
  }
}
struct ListeningActivityView: View {
  @ObservedObject var activity: ListeningActivity
  @EnvironmentObject var store: LibraryStore
  @EnvironmentObject var player: AudioController
  @Environment(\.dismiss) var dismiss
  var body: some View {
    NavigationStack {
      List {
        Section("Listening time") {
          LabeledContent(
            "Today",
            value: timeLabel(activity.snapshot.secondsByDay[ListeningActivity.dayKey(), default: 0])
          )
          LabeledContent(
            "Recorded total", value: timeLabel(activity.snapshot.secondsByDay.values.reduce(0, +)))
          Text("Counts elapsed listening time, not book duration. Stored locally; not analytics.")
            .font(.footnote).foregroundStyle(.secondary)
        }
        Section("Recent recovery points") {
          ForEach(activity.snapshot.events.prefix(100)) { event in
            if let book = store.books.first(where: { $0.id == event.bookID }) {
              Button {
                Task {
                  if player.bookID != book.id { await player.open(book, autoplay: false) }
                  player.seek(event.position)
                }
                dismiss()
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(book.title)
                  Text("\(timeLabel(event.position)) — \(event.kind)").font(.subheadline)
                  Text(event.date.formatted()).font(.caption).foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      }.navigationTitle("Listening history").toolbar { Button("Done") { dismiss() } }
    }
  }
}
struct BookmarkEditor: View {
  let bookID: UUID
  let mark: Bookmark
  @EnvironmentObject var store: LibraryStore
  @Environment(\.dismiss) var dismiss
  @State private var note = ""
  var body: some View {
    NavigationStack {
      Form {
        TextField("Bookmark note", text: $note, axis: .vertical).accessibilityIdentifier("bookmarkNote")
        Text(timeLabel(mark.position)).foregroundStyle(.secondary)
      }.navigationTitle("Bookmark note").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            if var book = store.books.first(where: { $0.id == bookID }),
              let index = book.bookmarks.firstIndex(where: { $0.id == mark.id })
            {
              book.bookmarks[index].note = note
              book.metadataUpdatedAt = Date()
              store.update(book)
            }
            dismiss()
          }
        }
      }.onAppear { note = mark.note }
    }
  }
}
struct SleepTimerEditor: View {
  @EnvironmentObject var player: AudioController
  @Environment(\.dismiss) var dismiss
  @State private var minutes = 30
  var body: some View {
    NavigationStack {
      Form {
        Stepper("\(minutes) minutes", value: $minutes, in: 1...360)
        Text("Playback fades over the last eight seconds when Fade sleep timer is enabled.").font(
          .footnote
        ).foregroundStyle(.secondary)
      }.navigationTitle("Sleep timer").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Start") {
            player.sleep(minutes: minutes)
            dismiss()
          }
        }
      }
    }
  }
}

struct ReadingView: View {
  @EnvironmentObject var player: AudioController
  var body: some View {
    NavigationStack { ReadingPage(activity: player.activity) }
  }
}

private struct ReadingPage: View {
  @ObservedObject var activity: ListeningActivity
  @EnvironmentObject var store: LibraryStore
  @EnvironmentObject var player: AudioController
  @AppStorage("readerName") private var readerName = ""
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var shelf = "Listening"
  private var books: [AudioBook] {
    store.books.filter {
      switch shelf {
      case "Finished": return $0.state.finished
      case "Next": return !$0.state.finished && $0.state.position == 0
      default: return !$0.state.finished && $0.state.position > 0
      }
    }.sorted { $0.state.updatedAt > $1.state.updatedAt }
  }
  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text(readerName.isEmpty ? "Your reading life." : "\(readerName)’s reading life.")
            .font(.title.weight(.semibold)).accessibilityAddTraits(.isHeader)
          Text("A little, every day.").foregroundStyle(.secondary)
        }.padding(.vertical, 12)
        let layout = typeSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
          : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 24))
        layout {
          metric("\(store.books.filter { $0.state.finished }.count)", "Finished")
          metric("\(activity.snapshot.currentStreak())", "Day streak")
          metric("\(Int(activity.snapshot.recentDays().reduce(0) { $0 + $1.seconds } / 60))", "Minutes in 7 days")
        }.padding(.vertical, 8)
      }
      Section("Last 7 days") {
        Chart(activity.snapshot.recentDays()) { day in
          BarMark(x: .value("Day", day.date, unit: .day), y: .value("Minutes", day.seconds / 60))
            .foregroundStyle(ListenTheme.accent)
            .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide)))
            .accessibilityValue("\(Int(day.seconds / 60)) minutes")
        }
        .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
        .frame(height: 140)
        Text("Listening time and streaks are recorded on this device. Book progress follows your iCloud library.")
          .font(.footnote).foregroundStyle(.secondary)
      }
      Section {
        Picker("Your shelf", selection: $shelf) {
          ForEach(["Next", "Listening", "Finished"], id: \.self) { Text($0) }
        }.pickerStyle(.segmented).accessibilityIdentifier("personalShelf")
        if books.isEmpty {
          Text(shelf == "Next" ? "New imports will be here, ready for their first chapter."
            : shelf == "Finished" ? "Finished books will have a place here."
            : "Start a book in your library. Your place will be waiting here.")
            .foregroundStyle(.secondary).padding(.vertical, 12)
        }
        ForEach(books) { book in
          Button {
            Task {
              await player.open(book)
              if player.bookID == book.id {
                NotificationCenter.default.post(name: Notification.Name("listen.show-player"), object: nil)
              }
            }
          } label: { BookRow(book: book).contentShape(Rectangle()) }
          .buttonStyle(.plain).disabled(store.processingBookID == book.id)
        }
      }
      Section {
        NavigationLink {
          ListeningActivityView(activity: activity)
        } label: { Label("Listening history", systemImage: "clock") }
      }
    }
    .scrollContentBackground(.hidden).background(ListenTheme.background)
    .navigationTitle("You").accessibilityIdentifier("readingIdentity")
  }
  private func metric(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(value).font(.title2.weight(.semibold)).monospacedDigit()
      Text(label).font(.caption).foregroundStyle(.secondary)
    }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
  }
}

struct AirPodsSleepHelp: View {
  var body: some View {
    List {
      Section {
        Label("Let your book rest, too.", systemImage: "moon.zzz").font(.title2.weight(.semibold))
        Text("Supported AirPods can automatically pause sovo. when Apple detects that you have fallen asleep.")
      }
      Section("Set up once") {
        Text("1. Wear your AirPods and connect them to this device.")
        Text("2. On iPhone or iPad, open Settings and choose your AirPods. On Mac, open System Settings and choose your AirPods.")
        Text("3. Turn on Pause Media While Falling Asleep. If needed, look under Audio & Routing.")
      }
      Section("What sovo. does") {
        Text("sovo. accepts the system pause command and saves your listening position. This setting is controlled by Apple; sovo. cannot read or switch it on.")
        Text("No pulse readings, Health access or workout recording are needed. Heart rate alone is not used to guess whether you are asleep.")
          .foregroundStyle(.secondary)
        Text("Detection is not guaranteed or immediate. For a predictable stop, use the sleep timer or End of chapter in the player.")
      }
      Section {
        Link("Apple’s AirPods setup and supported models", destination: URL(string: "https://support.apple.com/108764")!)
      }
    }.navigationTitle("AirPods sleep pause").navigationBarTitleDisplayMode(.inline)
      .accessibilityIdentifier("airPodsSleepGuide")
  }
}
