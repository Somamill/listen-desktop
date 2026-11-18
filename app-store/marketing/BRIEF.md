# sovo. — Store presentation brief

Pinned policy: [dot. App Store playbook](https://github.com/Somamill/dot-brand-kit/blob/8bae6bb13985ae14346f41facfa751e486c7c911/docs/APP_STORE_PLAYBOOK.md).

## Release and audience

App Store ID: 6834434329. Bundle ID: `io.github.somamill.listen.mobile` (stable). Universal iPhone/iPad application and native Mac Catalyst player. Store release target: 1.0.1, build 11. Source commit and live submission receipts belong in the final release packet; an archive is not a published release.

Audience: people with their own DRM-free audiobooks, especially books split across audio files. Problem: scattered files, missing book details and hard-to-find listening positions. Outcome: an organized personal library with a direct path back to listening.

Identity: sovo., part of dot.; sage, forest, warm cream, restrained type, native controls and whole visible covers. Library combines Books, Genres, Authors and Narrators; You and Settings remain separate. Preserve bundle IDs, data locations and URL schemes.

## Coverage and evidence gates

| Benefit | Native flow | Evidence required for final build | Public card |
| --- | --- | --- | --- |
| Start listening directly | Select book, mini-player, chapters | Physical playback and pause; compact-cover inspection | 1 |
| Bring folders, not individual chapters | Folder import, automatic compatible M4B creation, retained originals | Many-file import, verified final duration and chapter count; interruption recovery | 2 |
| Useful book details automatically | Embedded tags, Apple Books/Open Library, edition checks | Native metadata tests and fresh physical-device enrichment | 3 |
| Find books your way | Books / Genres / Authors / Narrators in Library | Native navigation and portrait credits; no fabricated identities | 4 |
| Follow your listening | You shelves, history, local stats, sleep timers | Existing native tests; show actual test activity only | 5 or description |
| Continue across devices | Optional private iCloud library/progress | Fresh signed-device test; do not claim completed cloud delivery from a local check | Card only after verification |
| Bring Goodreads shelves | Optional app-owned session and CSV, read-only refresh | Current native connection/CSV test; disclose provider sign-in and availability | Description; no always-connected promise |
| Free starting point | Optional LibriVox Alice recording, source and regional rights notice | Native download/import and source verification | Supporting copy; no worldwide rights claim |

Year, publisher, language and narrator are edition facts: keep missing facts unknown rather than inventing them. Available metadata matching is automatic, not guaranteed for every book. AAC conversion is lossy; original files are retained.

## Story and copy direction

Five to seven useful cards per platform, one short benefit each, with large actual native final-build captures. Use a clean QA library containing only cleared media, not the owner's personal library. Capture iPhone, iPad and Mac separately, inspect light/dark and thumbnail readability, and retain raw captures plus editable compositions and a hash/dimension manifest.

Candidate headline direction: "Press play. Stay there." / "Many chapters. One book." / "The details, together." / "Your library. Your way." / "Make time for a chapter." These remain drafts until their specific build/platform evidence passes. No invented ratings, awards, download figures, speed claims, universal sync or sleep-detection claims.

Primary language: English UI. Prepare en-US and de-DE Store copy with an explicit English-interface note; consider ja-JP only with language review. Search intent: personal audiobook player, MP3/M4B imports, offline listening, chapters and sleep timer. Search volume and difficulty are unknown; no ranking guarantee. Avoid competitor/trademark keyword stuffing.

## Capability plan

- Use now: ordinary product page, eligible iPhone/iPad/Mac screenshots, accurate description/subtitle/keywords, reviewer guide, privacy/support links and release receipts.
- Test later: product-page optimization, only after a stable released baseline and sufficient data; no experiment started during this update.
- Not now: custom product pages without a distinct campaign, creative placements without verified eligibility, events/featuring without a qualifying experience, paid advertising without a budget authorization.
- No App Preview video requested for this pass. A private physical-device review demonstration remains separate from public marketing assets.
- Read available App Analytics baseline if accessible; unavailable/low-volume data is not zero and does not establish a conversion uplift.
- Keep approved assets available until replacement uploads finish processing. Track saved, submitted, approved and live states separately. GitHub Actions remain disabled.

## Current language exception

18 November 2026: owner explicitly approved the twelve-language readiness exception for this already-running 1.0.1/build 11 release; twelve-language UI and Store coverage is deferred to the following update. English-interface disclosure remains required. Other evidence gates are unchanged. Managed policy provenance is recorded in .agent-tools/requirements/source.json.
