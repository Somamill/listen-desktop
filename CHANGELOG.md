# Changelog

## 0.5.0 — independent desktop candidate

- Extract the desktop application from reconciled source 4273af7, retaining source history, MIT license and dependency notices. Native Apple Store app continues in Somamill/sovo; old /listen remains its redirect.
- Preserve desktop bundle ID, URL scheme, storage and credential identifiers. Remove dot. membership and native Store build inputs from the current tree.
- Introduce independent warm amber identity and icon, readable controls and Arabic RTL.
- Add ten interface catalogs, system/per-app selection, localized navigation, guidance, client/provider errors, status text and native menus.
- Isolate update checks to Somamill/listen-desktop; reject prereleases/foreign feeds, cache daily checks and keep installation manual.
- Fix native deployment target to macOS 13 rather than inheriting the build host’s current version.

This is not a notarized public release. See docs/RELEASE_READINESS.md for exact tests and signing limitations. Earlier product history is retained in Git, before the extraction commit.
