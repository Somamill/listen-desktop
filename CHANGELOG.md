# Changelog

## 0.6.1

- Use the same steel-blue waveform artwork for the Mac application icon and browser surfaces.
- Display the metadata state once and show an unknown torrent size clearly while waiting for peers.

## 0.6.0

- Introduced a slate-blue Liquid Glass interface and waveform icon for the Mac.
- Added the optional standalone BitTorrent engine with a proxy-only macOS network guard.
- Update checks select the exact installer for the installed build variant.
- Downloads show an unknown size until torrent metadata supplies one.

## 0.5.0 — independent desktop candidate

- Extract the desktop application from reconciled source 4273af7, retaining source history, MIT license and dependency notices. Native Apple Store app continues in Somamill/sovo; old /listen remains its redirect.
- Preserve desktop bundle ID, URL scheme, storage and credential identifiers. Remove dot. membership and native Store build inputs from the current tree.
- Introduce independent warm amber identity and icon, readable controls and Arabic RTL.
- Add ten interface catalogs, system/per-app selection, localized navigation, guidance, client/provider errors, status text and native menus.
- Isolate update checks to Somamill/listen-desktop; reject prereleases/foreign feeds, cache daily checks and keep installation manual.
- Fix native deployment target to macOS 13 rather than inheriting the build host’s current version.

This is not a notarized public release. See docs/RELEASE_READINESS.md for exact tests and signing limitations. Earlier product history is retained in Git, before the extraction commit.
