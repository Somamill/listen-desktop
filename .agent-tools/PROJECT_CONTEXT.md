# listen-desktop project context

Independent desktop audiobook discovery/search, torrent-client handoff and local library app. Not a dot. suite app or the native sovo. Store player. Preserve bundle ID io.github.somamill.listen, listen:// scheme, ~/Library/Application Support/listen and existing Keychain service IDs. Never reuse Somamill/listen: it redirects to Somamill/sovo.

Source extraction: full Git history retained from 4273af7975c59c69fe2d15ee69000ccf3af48f91. Current native Store paths removed; previous commits remain source/license provenance. Ownership: listen_app/, native/, extras/, scripts/build_macos.py, desktop Python tests and dependencies. Native ios/, app-store/ and dot. branding belong to Somamill/sovo. Actions remain disabled.

Design: DESIGN.md and listen_app/static/css/tokens.css and brand.css. Local Flask/Waitress with authenticated loopback access, WebKit Mac wrapper. Background tests use isolated LISTEN_DATA_DIR; never user media/config. Build via scripts/build_macos.py on Mac. Genuine native/rendered evidence required; headless browser verifies web surface only. UI localization and independent fresh-clone/signing/update checks must be verified before claims.

Current QA: 47 Python tests and rendered JS checks passed; native arm64 self-contained local QA ZIP/DMG built. Ten interface catalogs each include426 matching keys across static, native and dynamic text, with system preference negotiation, explicit selection and Arabic RTL. Provider websites and book metadata remain separate. Qualified linguistic review is not claimed. Developer ID/notarization unavailable; do not publish ad-hoc artifacts as production signed.

Fresh public clone f7e0edd independently built the arm64 app/ZIP/DMG; native Cmd+, German menu/settings and disposable legacy-app replacement passed without modifying installed apps/data. Local Developer ID helper supports nested runtime signing using an explicit isolated keychain; credential/notarization approval remains with migration owner. All build inputs are independent of sovo.; full source history preserved.
