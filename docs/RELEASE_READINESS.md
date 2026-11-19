# Independent desktop release readiness — 19 November 2026

Source: reconciled native/desktop parent 4273af7975c59c69fe2d15ee69000ccf3af48f91. Current source split has independent build inputs and updater destination. Actions disabled before first push.

## Verified
- 44 Python tests pass: the inherited 38 app regressions and 6 independent split/update/locale tests.
- All five real Flask/Jinja pages render; 20 inline scripts and standalone JS pass Node syntax checks.
- Self-contained native arm64 ZIP/DMG build succeeds and verifies local signatures, fresh startup, neutral defaults, loopback auth and main pages. This is ad-hoc local QA, not Developer ID or notarization.
- Actual headless app UI inspected at 1440×1000; Arabic RTL at 1000×900 negotiates its locale and reverses layout without horizontal overflow. UI screenshots are web-surface evidence, not evidence of native window behavior or live torrent/provider authentication.
- Stable desktop bundle ID/storage remain unchanged; native Store sources are absent from the current build tree.

## Blocking public production distribution
- No verified Developer ID Application certificate/notary profile. Existing App Store signing cannot substitute for direct distribution. No ad-hoc package is advertised as notarized.
- Ten catalogs have matching 426-key coverage, including all original217 static keys, long guidance, dynamic statuses/errors and native menus. Proper product names, URLs and shortcuts remain unchanged. Qualified linguistic review is not claimed; provider websites and book metadata are separate from interface translation.
- Fresh-clone native build, exact final rendered evidence and installer/update checks are recorded when complete below. Live Goodreads authentication and remote client combinations require actual accounts/devices; fixture success is not a live connection guarantee.

## Design review
Impeccable/Hallmark were loaded. Raw Jinja template scans report false positives for inherited CSS, templating strings and missing inline shared styles; these are not a clean pass. Actual rendered captures were inspected and small functional text was increased. Warm paper/amber and existing serif headings are deliberate product identity; the standalone app does not inherit dot. branding. Remaining audit findings and unreviewed linguistic quality are not silently waived.
