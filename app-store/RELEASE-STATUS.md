# App Store release candidate

Updated 16 November 2026. Store listing: **sovo.**; installed app and in-app name: **listen.**

| Edition | Version/build | Apple status |
| --- | --- | --- |
| iPhone & iPad | 1.0.0 (6) | Waiting for Review |
| Mac Catalyst, Intel & Apple Silicon | 1.0.0 (7) | Waiting for Review |

Both editions were submitted with automatic release after approval. The iOS Guideline 2.1 item was resolved and its existing review submission resubmitted; the Mac build 4 review was replaced with tested build 7.

Neither edition is approved or publicly available yet. Automatic release is configured for after Apple approval.

## Validation and corrections

- Both final packages passed signing, bundle checks and Apple validation; uploaded builds processed as VALID. Signing uses a dedicated private keychain without requesting the login-keychain password.
- Real iPhone 14 testing on iOS 27.2.1 covered original sample ZIP import, advancing playback, chapters, bookmarks, timer configuration, MP3-to-M4B conversion, visible tab navigation and settings. Audible sample playback was confirmed by the tester. The continuous review video begins at TestFlight launch; leading connection/setup time was trimmed. It was captured through iPhone Mirroring, rather than a simulator.
- Corrected incompatible iOS audio-session options, mini-player navigation obstruction and the finished flag when seeking back into a book. Selected unit tests and the playback/navigation UI regression passed locally. The targeted native Goodreads extraction test also passed after allowing more time for cold WebKit startup on hosted runners.
- Real Mac TestFlight build 7 played the sample with advancing progress and working pause. It corrects a Mac-specific audio-session activation error found in build 6. iCloud library metadata and progress arrived from the physical iPhone.
- The iOS Guideline 2.1 response includes a complete physical-device demonstration and answers covering purpose, access, services, regions and content rights. Local playback requires no app account, payment or subscription. Original sample audio and fictional shelf CSV remain available in the [review guide](review/README.md).

Physical iPad hardware, all audio-route/background combinations, Siri, widgets/share extensions and authenticated third-party flows have not all been certified end to end. Test/build success does not guarantee every device or provider behavior.

Hosted native iOS/iPadOS tests and Mac builds, source tests and the brand check passed for [the final source changes](https://github.com/Somamill/listen/actions/runs/43727238368).

## Store materials

Native iPhone, iPad and Mac screenshots, privacy declarations, support and privacy-policy links, age rating, free pricing and availability are configured. Optional provider data handling is documented. See the [native support page](SUPPORT.md) and [review guide](review/README.md).

[Store record](https://appstoreconnect.apple.com/apps/6834434329/distribution)

## Separate desktop edition

The sandboxed Mac Store player installs as `listen Player.app`, bundle identifier `io.github.somamill.listen.mobile`. The separate desktop catalogue/torrent application is not included in Store builds. Its installation, library and qBittorrent routing were not changed by this remediation.
