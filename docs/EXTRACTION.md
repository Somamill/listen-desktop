# Independent listen extraction

Native migration owner: sovo. Source: Somamill/sovo, formerly Somamill/listen, exact reconciled commit `4273af7975c59c69fe2d15ee69000ccf3af48f91` (19 November 2026). This repository retains complete reachable source history and original commit IDs. No history rewrite or relicense occurred; LICENSE, THIRD_PARTY_NOTICES.md and bundled dependency licenses remain.

Desktop owns `listen_app/`, `listen_server.py`, `native/`, `extras/`, desktop `scripts/`, Python dependencies and tests. sovo. owns the native Apple Store app (`ios/`), Store metadata/assets (`app-store/`) and dot. brand assets. Those native paths are absent from this repository’s current tree; their historical revisions are retained only for provenance. The old Somamill/listen URL remains a redirect to sovo.; never reuse it.

Compatibility: desktop `io.github.somamill.listen`, `listen://`, Application Support/listen, Downloads/listen and existing credential service identifiers are unchanged. Native Store sovo. uses `io.github.somamill.listen.mobile`, a separate container/App Group and updater destination. Installers must never target or replace the native sovo. app or its library. No user data is copied or deleted by this source split.

## One-time legacy desktop update

Installed desktop0.4.2 was inspected read-only: its frozen updater uses the old Somamill/listen API/release URL prefix. The GitHub rename changes canonical URLs to sovo., so the old strict checker cannot discover this independent desktop repository. It also does not accept native sovo. releases as matching desktop URLs. Existing desktop users need one manual install of the new signed/notarized desktop candidate when available. Thereafter the independent updater checks only Somamill/listen-desktop and requires a compatible Mac artifact. No old /listen URL is reused.

The new installer retains bundle ID and data locations; do not delete the old library or credential entries. Legacy app0.4.2 is self-contained and does not depend on the removed original checkout. Its bundled backend, startup and data were left untouched during migration QA.
