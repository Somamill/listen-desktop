import SwiftUI

enum LibraryCategory: String, CaseIterable, Identifiable {
  case genres = "Genres", authors = "Authors", narrators = "Narrators"
  var id: String { rawValue }
  var symbol: String {
    switch self { case .genres: "square.grid.2x2"; case .authors: "person.crop.square"; case .narrators: "waveform" }
  }
  func value(_ book: AudioBook) -> String {
    switch self { case .genres: book.genreLabel; case .authors: book.author; case .narrators: book.narrator.isEmpty ? "Not credited" : book.narrator }
  }
}

struct BrowseView: View {
  @EnvironmentObject private var store: LibraryStore
  let category: LibraryCategory
  let search: String
  private var groups: [String] {
    Set(store.books.map(category.value)).filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }
      .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }
  var body: some View {
      List {
        Section {
          ForEach(groups, id: \.self) { name in
            NavigationLink {
              BrowseCollectionView(name: name, category: category)
            } label: {
              HStack(spacing: 16) {
                if category != .genres {
                  PersonPortrait(name: name, narrator: category == .narrators).frame(width: 60, height: 60)
                } else {
                  Image(systemName: category.symbol).font(.title2).foregroundStyle(ListenTheme.accent)
                    .frame(width: 60, height: 60).background(ListenTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 4) {
                  Text(name).font(.headline)
                  Text("Audiobooks · \(store.books.filter { category.value($0) == name }.count)").font(.subheadline).foregroundStyle(.secondary)
                }
              }.padding(.vertical, 8)
            }.accessibilityIdentifier("category-\(name)")
          }
        }
        if groups.isEmpty {
          ContentUnavailableView("A library worth exploring", systemImage: category.symbol, description: Text("Your imported books appear here, grouped by genre, author and narrator."))
        }
        if category != .genres {
          Text("Portraits match public Wikipedia profiles. Missing or ambiguous credits keep a placeholder.").font(.footnote).foregroundStyle(.secondary).listRowBackground(Color.clear)
        }
      }.scrollContentBackground(.hidden).background(ListenTheme.background)
  }
}

struct PersonPortrait: View {
  let name: String
  let narrator: Bool
  @State private var profile: PersonProfile?
  var body: some View {
    AsyncImage(url: profile?.thumbnail?.source) { image in image.resizable().scaledToFill() } placeholder: {
      Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(ListenTheme.accent.opacity(0.65)).padding(6)
    }.background(ListenTheme.accent.opacity(0.08)).clipShape(Circle()).accessibilityHidden(true)
      .task(id: "\(narrator):\(name)") { profile = await PersonMetadata.shared.profile(name: name, narrator: narrator) }
  }
}

struct BrowseCollectionView: View {
  let name: String
  let category: LibraryCategory
  @EnvironmentObject private var store: LibraryStore
  @EnvironmentObject private var player: AudioController
  @State private var profile: PersonProfile?
  private var books: [AudioBook] {
    store.books.filter { category.value($0) == name }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
  }
  var body: some View {
    List {
      if category != .genres {
        Section {
          VStack(alignment: .leading, spacing: 16) {
            PersonPortrait(name: name, narrator: category == .narrators).frame(width: 112, height: 112)
            if let description = profile?.description { Text(description).font(.title3) }
            if let profile {
              if let biography = profile.extract { Text(biography).font(.subheadline).foregroundStyle(.secondary) }
              Link("Wikipedia · biography & portrait credits", destination: profile.content_urls.desktop.page).font(.footnote)
              if let credit = profile.photoCredit, let source = profile.photoSource {
                Link(credit, destination: source).font(.caption).foregroundStyle(.secondary)
              }
              if let license = profile.photoLicense { Link("Photo license", destination: license).font(.caption) }
              Link("Biography · CC BY-SA", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!).font(.caption)
            }
          }.padding(.vertical, 12)
        }
      }
      Section("In your library") {
        ForEach(books) { book in
          Button {
            Task {
              await player.open(book)
              if player.bookID == book.id { NotificationCenter.default.post(name: Notification.Name("listen.show-player"), object: nil) }
            }
          } label: { BookRow(book: book) }.buttonStyle(.plain).disabled(store.busy || player.loading)
        }
      }
    }.navigationTitle(name).navigationBarTitleDisplayMode(.inline).scrollContentBackground(.hidden).background(ListenTheme.background)
      .task(id: "\(category.rawValue):\(name)") {
        if category != .genres { profile = await PersonMetadata.shared.profile(name: name, narrator: category == .narrators) }
      }
  }
}
