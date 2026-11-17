# Metadata, genres, Goodreads iCloud and AirPods sleep pause — 18 November 2026

Fresh practical checks on 18 November: Apple Books DE/US returned matching metadata and 1200×1200 / 1169×1200 covers for two public test titles; Open Library returned the matching German title, author, subjects and cover identifier. The owner's existing Chrome Developer tab confirmed the main app's App Group and selected iCloud container are already enabled, so no capability changes were needed. App Store Connect website authentication has expired; API access still confirms iOS 1.0.0 is released, macOS 1.0.0 is in review and iOS 1.0.1 is a draft. A live Goodreads shelf request returned a sign-in page, not shelf data. The physical iPhone is currently unavailable to devicectl and Mirroring timed out; these checks do not certify authenticated Goodreads, cross-device cloud transfer or actual AirPods sleep detection for build 8.

The unsigned physical-iOS Release archive for 1.0.1 (8) was also built successfully and passed the bundle validator. It is not signed, uploaded or installed on a physical device.

Local 1.0.1 (8) candidate extended with metadata fallbacks and automatic genres, library genre shelves, M4B genre tags and server identity before conversion. Goodreads profile and cached shelves can sync through the existing private iCloud container; authentication stays per device. Legacy clients cannot erase a known genre during a metadata merge. Local disconnect disables that device’s Goodreads sync without deleting remote snapshots.

AirPods sleep pause uses Apple’s system feature and existing media pause commands, with a setup guide in Settings/the sleep menu. No HealthKit permissions, live pulse collection, workout sessions or custom sleep classifier were added. A late playback-end event cannot restart queued audio after a pause.

Validation: 30 unit tests passed, plus the targeted server conversion test (31 distinct cases); genre/setup and direct-book/player/navigation UI scenarios passed. iOS simulator and universal Mac builds and bundle checks pass. Physical AirPods detection, signed cross-device iCloud and authenticated Goodreads still need device QA. UI layout uses native controls; native screenshot review and the scoped Impeccable regex scan were used, not browser validation.

This update remains local and unsubmitted. GitHub Actions remain disabled. Genre organization is virtual shelves, with no extra audio copies. Unmatched authors/genres remain explicitly unknown rather than invented. Setup and data handling are documented in SUPPORT.md and PRIVACY.md.

---

# sovo. 1.0.1 update candidate

17 November 2026. Version 1.0.1 (8) is being validated locally and has not been uploaded or submitted. The installed app, widgets, share extension and Siri labels use sovo. Existing bundle, cloud, keychain and App Group identifiers are preserved.

Changes: tap-to-play; automatic single-pass M4B import; automatic Apple Books/Open Library metadata and covers; a personal You page with actual shelves/listening stats; Goodreads and media servers under Settings; Goodreads browsing stays in its in-app session. Goodreads remains read-only and provider-dependent, not an official full-sync API.

Local checks: 24 unit tests passed, with targeted reruns passing after the final metadata changes. Final UI regressions passed for tap-to-play/player/bookmarks, server Settings navigation, and all three tabs with the mini-player. The personal reading page and in-app Goodreads window also passed a separate screen test. Universal Mac Release build (arm64/x86_64) and both platform bundle checks pass. Native screenshots were reviewed; the Impeccable regex scan reported no findings, which does not replace native UI validation.

Live Apple Books DE/Open Library lookups and cover downloads worked for an identified public test title. Authenticated Goodreads and fresh physical iPhone/iPad QA remain unverified for build 8. Goodreads remains read-only and provider-dependent.

GitHub Actions remain disabled by owner instruction. No upload, TestFlight distribution or App Store submission was performed for this update. The existing iOS 1.0.0 version is released; its historical submission notes below predate that approval.

---

# App Store release candidate

Updated 16 November 2026. Store listing: **sovo.**; installed app and in-app name: **listen.**

| Edition | Version/build | Apple status |
| --- | --- | --- |
| iPhone & iPad | 1.0.0 (6) | Approved — Ready for Sale |
| Mac Catalyst, Intel & Apple Silicon | 1.0.0 (7) | Waiting for Review |

Both editions were submitted with automatic release after approval. The iOS Guideline 2.1 item was resolved and its existing review submission resubmitted; the Mac build 4 review was replaced with tested build 7.

The iOS edition is approved and publicly listed as [sovo.](https://apps.apple.com/app/id6834434329). Apple's live App Store Connect state is `READY_FOR_SALE`; public lookup confirmed version 1.0.0 in the US, Japan and Germany on 16 November 2026. The earlier Guideline 2.1 submission is `COMPLETE`, with the physical-iPhone review attachment delivered successfully and all six requested answers in App Review notes. No further iOS resubmission is needed for that notice.

The Mac edition remains `WAITING_FOR_REVIEW`, with automatic release configured after approval. Approval of iOS does not imply Mac approval or certification of every optional integration.

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
