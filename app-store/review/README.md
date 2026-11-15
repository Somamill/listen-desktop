# App Review guide

This guide describes the native `ios/` App Store app, **listen. Audiobook Player**, version 1.0.0. It is a personal DRM-free audiobook player for iPhone, iPad and Mac Catalyst. The repository also contains a separate desktop catalogue, which is not shipped in the Store app. No torrent client, proxy configuration or audiobook catalogue is part of this native build.

## Purpose and audience

For listeners who already have lawful, DRM-free audiobook files, listen. brings imports, offline playback, chapters, position tracking, bookmarks, queues, playback speed, timers and metadata editing into one library. Optional MP3-to-M4B conversion combines chapters into AAC audio while retaining the imported originals. Optional iCloud shares the user's library and progress between their own devices.

## Access and sample files

Core functionality needs no account, registration, payment or developer-operated backend. There are no in-app purchases, paid unlocks or subscriptions. No demo credentials are needed for local playback.

Use the [original sample ZIP](https://raw.githubusercontent.com/Somamill/listen/main/app-store/review/samples/listen-review-sample.zip): **Library → + → Download from HTTPS → paste the direct ZIP link → Download**. Open the imported book, start playback, change speed, add a bookmark, set a sleep timer, pause and resume. In book details, edit metadata or choose **Create M4B audiobook**. Conversion is local and retains the imported originals. Original tutorial text and its redistribution license accompany the MP3 chapters.

For reading shelves without a provider login, download [goodreads-demo.csv](https://raw.githubusercontent.com/Somamill/listen/main/app-store/review/samples/goodreads-demo.csv). In Goodreads, expand **Other ways to bring your shelves**, then select **Import Goodreads CSV**. The three records demonstrate Want to Read, Currently Reading and Read. These are invented reading statuses for public book identifiers, not anyone's personal data or an authenticated/live connection. CSV import is explicitly a snapshot.

An optional live Goodreads connection uses the provider's website in an app-owned web session. Credentials go to the provider. Disconnect in Settings removes local website/connection data; it does not delete an external Goodreads/Amazon account. listen. has no account-creation system of its own. There is no native public feed, messaging, user-content hosting, paid content or social posting. User-imported audio and notes remain a private library. External provider websites administer their own accounts and community features.

## External services and dependencies

- Apple iCloud Documents and key-value storage: optional user library/progress synchronization using the user's Apple account.
- Apple's iTunes Search endpoint and returned artwork URLs: optional title/author metadata and covers. Audiobook audio is not uploaded for matching. A metadata request is not a purchase or access to protected Apple audio.
- Goodreads and Amazon website/authentication endpoints: optional read-only personal shelves; Google CAPTCHA resources may be needed by the provider's sign-in flow. No listen. authentication service is operated.
- User-configured Audiobookshelf/Jellyfin servers and user-supplied HTTPS media URLs: optional access to the user's authorized files.
- A temporary local HTTP transfer listener: optional browser upload on the user's trusted local network; closing the screen stops it.
- ZIPFoundation 0.9.20, MIT licensed: local ZIP extraction. Playback and conversion use Apple system frameworks. There is no runtime AI service, advertising SDK or payment processor.

The eSpeak NG tool was used only during preparation of the original spoken review samples. Its program is not bundled in or required by the app.

## Regions and material rights

The app's local playback/import features operate consistently across regions. The interface is English; users may import audio in any language. Optional third-party availability, metadata results and network reachability depend on those services and the user's configuration. listen. does not operate a regional content catalogue or geographically restricted paid tier.

This is not a service in a highly regulated industry. The app supplies no commercial audiobook recordings or protected book excerpts. Review sample narration and text are original and licensed for testing and redistribution in [LICENSE.txt](samples/LICENSE.txt). The CSV includes only identifying book metadata and invented shelf statuses, with provenance in [CSV-NOTICE.txt](samples/CSV-NOTICE.txt). Users are responsible for authorization to import their own media. App code and dependency notices are included in the repository; no claim is made to ownership of third-party provider names or data.

## Physical-device evidence

The physical-device recording and the exact device, OS, build and test results are supplied privately to Apple in App Review Information. This public guide does not assert that a recording has been completed or that optional hardware/cloud features have passed physical-device testing. Simulator results are not a substitute for the requested evidence.
