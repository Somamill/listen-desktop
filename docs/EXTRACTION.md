# Independent listen extraction

Native migration owner: sovo. Source: Somamill/sovo, formerly Somamill/listen, exact reconciled commit `4273af7975c59c69fe2d15ee69000ccf3af48f91` (19 November 2026). This repository retains complete reachable source history and original commit IDs. No history rewrite or relicense occurred; LICENSE, THIRD_PARTY_NOTICES.md and bundled dependency licenses remain.

Desktop owns `listen_app/`, `listen_server.py`, `native/`, `extras/`, desktop `scripts/`, Python dependencies and tests. sovo. owns the native Apple Store app (`ios/`), Store metadata/assets (`app-store/`) and dot. brand assets. Those native paths are absent from this repository’s current tree; their historical revisions are retained only for provenance. The old Somamill/listen URL remains a redirect to sovo.; never reuse it.

Compatibility: desktop `io.github.somamill.listen`, `listen://`, Application Support/listen, Downloads/listen and existing credential service identifiers are unchanged. Native Store sovo. uses `io.github.somamill.listen.mobile`, a separate container/App Group and updater destination. Installers must never target or replace the native sovo. app or its library. No user data is copied or deleted by this source split.
