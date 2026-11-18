# App Review guide

This guide describes the native `ios/` App Store app, **sovo.**, version 1.0.1 (8) update candidate. It is a personal DRM-free audiobook player for iPhone, iPad and Mac Catalyst. The repository also contains a separate desktop catalogue, which is not shipped in the Store app. No torrent client, proxy configuration or audiobook catalogue is part of this native build.

## Purpose and audience

For listeners who already have lawful, DRM-free audiobook files, sovo. brings imports, offline playback, chapters, position tracking, bookmarks, queues, playback speed, timers and metadata editing into one library. Compatible imports automatically combine chapters into AAC M4B audio while retaining the imported originals. Optional iCloud shares the user's library and progress between their own devices.

## Access and sample files

Core functionality needs no account, registration, payment or developer-operated backend. There are no in-app purchases, paid unlocks or subscriptions. No demo credentials are needed for local playback.

Use the [original sample ZIP](https://raw.githubusercontent.com/Somamill/listen/main/app-store/review/samples/listen-review-sample.zip): **Library → + → Download a file → paste the direct ZIP link → Download**. Open the imported book, start playback, change speed, add a bookmark, set a sleep timer, pause and resume. Book details let you edit metadata. Compatible imports convert automatically before the book is saved; a single existing M4B stays unchanged. Conversion is local and retains the imported originals. Original tutorial text and its redistribution license accompany the MP3 chapters.

For reading shelves without a provider login, download [goodreads-demo.csv](https://raw.githubusercontent.com/Somamill/listen/main/app-store/review/samples/goodreads-demo.csv). In **Settings → Goodreads**, expand **Other ways to bring your shelves**, then select **Import Goodreads CSV**. The three records demonstrate Want to Read, Currently Reading and Read. These are invented reading statuses for public book identifiers, not anyone's personal data or an authenticated/live connection. CSV import is explicitly a snapshot.

An optional live Goodreads connection uses the provider's website in an app-owned web session. Credentials go to the provider. Disconnect in Settings removes local website/connection data; it does not delete an external Goodreads/Amazon account. sovo. has no account-creation system of its own. There is no native public feed, messaging, user-content hosting, paid content or social posting. User-imported audio and notes remain a private library. External provider websites administer their own accounts and community features.

## External services and dependencies

- Apple iCloud Documents and key-value storage: optional user library/progress synchronization using the user's Apple account.
- Apple Books Search, Open Library search and their cover endpoints: automatic title/author metadata and covers, with embedded details used first. Audiobook audio is not uploaded for matching. A metadata request is not a purchase or access to protected Apple audio.
- Goodreads and Amazon website/authentication endpoints: optional read-only personal shelves; Google CAPTCHA resources may be needed by the provider's sign-in flow. No sovo. authentication service is operated.
- User-configured Audiobookshelf/Jellyfin servers and user-supplied HTTPS media URLs: optional access to the user's authorized files.
- A temporary local HTTP transfer listener: optional browser upload on the user's trusted local network; closing the screen stops it.
- ZIPFoundation 0.9.20, MIT licensed: local ZIP extraction. Playback and conversion use Apple system frameworks. There is no runtime AI service, advertising SDK or payment processor.

The eSpeak NG tool was used only during preparation of the original spoken review samples. Its program is not bundled in or required by the app.

## Regions and material rights

The app's local playback/import features operate consistently across regions. The interface is English; users may import audio in any language. Optional third-party availability, metadata results and network reachability depend on those services and the user's configuration. sovo. does not operate a regional content catalogue or geographically restricted paid tier.

This is not a service in a highly regulated industry. The app supplies no commercial audiobook recordings or protected book excerpts. Review sample narration and text are original and licensed for testing and redistribution in [LICENSE.txt](samples/LICENSE.txt). The CSV includes only identifying book metadata and invented shelf statuses, with provenance in [CSV-NOTICE.txt](samples/CSV-NOTICE.txt). Users are responsible for authorization to import their own media. App code and dependency notices are included in the repository; no claim is made to ownership of third-party provider names or data.

## Previous 1.0.0 physical-device evidence

The private App Review attachment demonstrates TestFlight build 6 on a real iPhone 14 running iOS 27.2.1: app launch, original sample import, playback, chapters, bookmarks, timer configuration, M4B conversion and connection/settings screens. The continuous silent video was captured through iPhone Mirroring on a Mac, with only leading connection/setup time removed. Audible sample playback was confirmed separately by the tester. Mac TestFlight build 7 was also tested on a physical Mac for playback/progress and pause, with library metadata/progress received through iCloud. These checks do not certify every hardware route or optional third-party integration. Simulator results are not a substitute for the requested physical-device evidence.

The build 6/7 recording above documents the previous release, not this update. Build 8 changes are checked locally in the simulator and unsigned Mac packaging; authenticated Goodreads use and fresh physical-device QA must be verified before claiming them for this candidate. The **You** tab now presents native Next/Listening/Finished shelves and actual device-local listening time/streaks. Goodreads and media servers are under Settings.


## Version 1.0.1 (11) reviewer update

The installed app and Store name are sovo. Library combines Books, Genres, Authors and Narrators; selecting a book starts playback. The mini-player keeps the complete cover visible. Swipe a downloaded book for Details or local removal; removal retains external originals and any iCloud copy.

Compatible new imports create an M4B automatically and retain original audio. Failed/interrupted imports retain playable originals and expose Finish import. On supported iOS versions, user-started conversion requests Apple continued processing and reports progress. The system can still interrupt background work. Chapters use short numbered display labels.

The released app no longer includes the internal test recording. Library → + → Try a free classic offers Alice’s Adventures in Wonderland, Lewis Carroll, read by Kara Shallenberg (LibriVox, 2010). It is an optional direct download with source/rights notice, not a commercial catalogue. The original licensed reviewer ZIP above remains available as an alternative test file. Core playback requires no sovo. account, payment or subscription.

Automatic metadata uses embedded tags, Apple Books/Search and Open Library; matched edition credits are constrained by identity and duration. Public author/narrator biographies and licensed portraits use Wikipedia/Wikimedia with source links. No AI service or audio upload is used. Goodreads remains an optional app-owned website session and read-only shelf adapter, with CSV fallback; user-initiated website edits go to Goodreads, without automatic progress writeback. iCloud requires the user’s own Apple account and enabled iCloud Drive; sign-in cookies remain per device. No HealthKit/pulse access or proprietary sleep diagnosis is present.
