# listen. Audiobook Player

Support for the native iPhone, iPad and Mac App Store edition.

listen. plays your own DRM-free audiobooks. Import a file, folder or ZIP, then keep your place with chapters, bookmarks, playback speed and a sleep timer. There is no listen. account, subscription, in-app purchase or supplied audiobook catalogue. The separately distributed desktop catalogue in this repository is not included in the App Store app.

## Try a book without an account

[Download the original two-chapter sample ZIP](https://raw.githubusercontent.com/Somamill/listen/main/app-store/review/samples/listen-review-sample.zip). It contains original synthetic spoken tutorials, not an excerpt from a commercial audiobook.

1. Open **Library → + → Download from HTTPS**.
2. Paste the sample ZIP link and select **Download**. Alternatively, save the ZIP in Files and use **Import audio files**.
3. Open the imported book and select **Start listening**. Tap the player to change speed, seek, add a bookmark or set a sleep timer.
4. Open the book's details to edit its title and author or create an M4B. Conversion creates AAC audio and keeps the imported originals.

Metadata search may not find a commercial match for this original tutorial. Manual editing works without that lookup. Supported formats include MP3 and M4B; encrypted or DRM-protected purchases are not supported.

## Optional connections

- **Goodreads:** connect in the app's own web session, independent of Safari. Reading shelves are read-only; listen. does not write ratings or reading progress to Goodreads. A Goodreads CSV can also be imported as a snapshot. [Download a fictional shelf demonstration](https://raw.githubusercontent.com/Somamill/listen/main/app-store/review/samples/goodreads-demo.csv), then open Goodreads → Other ways to bring your shelves → Import Goodreads CSV. The demonstration is not a live account connection.
- **iCloud:** uses your Apple account for optional library and progress synchronization. Give uploads time to finish before opening another device. Download books before going offline.
- **Audiobookshelf or Jellyfin:** add your own server and credentials in Servers. These services are not required for local playback.
- **Browser transfer:** starts a temporary local-network upload session. Keep its secret link private and close the transfer screen when finished.

Disconnecting Goodreads removes the app's stored connection and website data; it does not delete your external Goodreads or Amazon account. Manage external accounts with the relevant provider. There is no separate listen. account to delete.

## Help and privacy

For an import problem, check that the file contains supported, unencrypted audio. HTTPS downloads need a direct file URL rather than a website or login page. For metadata errors, edit the book manually or retry with its title and author. For a server connection problem, confirm the server is reachable and its certificate is valid.

[Report an issue](https://github.com/Somamill/listen/issues/new) with your device, OS, app version and steps to reproduce. Do not include passwords, private server tokens, personal audiobook files or account data in a public issue.

[Privacy policy](PRIVACY.md) · [Review guide](review/README.md) · [Sample license](review/samples/LICENSE.txt)
