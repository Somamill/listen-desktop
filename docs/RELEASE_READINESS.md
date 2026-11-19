# Independent desktop release readiness — 19 November 2026

Source: reconciled native/desktop parent 4273af7975c59c69fe2d15ee69000ccf3af48f91. Current source split has independent build inputs and updater destination. Actions disabled before first push.

## Verified
- 47 Python tests pass: the inherited 38 app regressions and 9 independent split/update/locale/signing/cover tests.
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

## Independent fresh-clone evidence

Public source f7e0eddd076c2ad2b7c237c6c4886e209314ac79 was cloned from Somamill/listen-desktop into a fresh directory and installed in its own Python3.13 environment.44 tests and all five rendered-page/20-inline-script checks passed there. The self-contained Mac arm64 ZIP/DMG built with bundled10-language strings, stable bundle ID and native macOS13 target. All10 Localizable.strings files passed plist validation. Subsequent accessibility/update/signing changes have47 local tests; exact-source rebuild follows before publication.

The fresh-clone native app launched with an isolated LISTEN_DATA_DIR. Cmd+, opened German settings and translated native Edit menu; genuine Mac capture retained privately. The DMG mounted read-only and its app replaced a disposable copy of legacy0.4.2 as0.5.0, with stable identity and strict signature validation. The original /Applications/listen.app, its library and qBittorrent routing were untouched. LaunchServices resolves the installed magnet handler to qBittorrent.app, but the known local qBittorrent API port18080 was not reachable; no live torrent/client login is claimed. Manual official-feed check returned current0.5.0, available=false (no public release).

All12 observed Mach-O minimum versions in the first fresh bundle were macOS13 or older. Build automation now rejects any bundled dependency newer than the advertised minimum. Developer ID support signs nested Mach-O/frameworks and the outer bundle inside-out, with hardened runtime, secure timestamps and optional explicit isolated keychain. Credentials are never requested or embedded. Public signing/notarization is still pending the migration owner’s authorized credential check.

Visual review: Hallmark rendered floor reached0 FAIL; remaining source-spacing reflexes and deliberate warm-paper palette are documented in DESIGN.md. HTML/native checks are distinct. Qualified linguistic/accessibility certification and every remote provider/client combination remain unverified.

## Exact independent candidate verification (2026-11-19)
Fresh public GitHub clone at `0c2fc6b` passed all 47 Python tests, five rendered page checks, 20 inline-script checks, and the self-contained arm64 build. The native macOS app launched with isolated empty data; English Settings and an actual saved Arabic preference were inspected, including RTL layout and Arabic native menus. Cleared captures and hashes are in `docs/images/manifest.json`. No private library or account is pictured.

A live read-only catalog search for the public-domain work *Alice’s Adventures in Wonderland* returned six results with TLS validation enabled. Nothing was downloaded or sent to a torrent client. qBittorrent was not running, so live authenticated peer/download routing remains unverified. Test fixture failures and localized error handling are covered by the automated suite.

The installed legacy app and magnet handler remain `/Applications/listen.app` and `/Applications/qBittorrent.app`. Only owned QA processes, headless browser, and temporary app registrations were cleaned up. Legacy data and torrent settings were not modified.

The exact candidate ZIP SHA256 is `77252aab223e79164409f07de4b19fbea0c8a56ed24fecf5ea8421cdc872cb93`; DMG SHA256 is `691e0a25088de5926b3b0f12e3eb6b9336acfa55094775937f63edd67d3a66b5`. These hashes describe local ad-hoc QA artifacts, not a notarized public release. Developer ID signing and notarization must complete before production binary publication.
