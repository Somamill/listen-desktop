# Local quality gates

Actions remain disabled. Run tests/test_app.py and tests/test_desktop_split.py, rendered inline JavaScript checks, independent Mac packaging and fresh-clone build. Keep native window checks distinct from headless web screenshots.

The split tests verify no current native Store inputs, stable independent desktop bundle ID, updater rejection of native/prerelease URLs, cached checks, system language negotiation and Arabic RTL separate from audio filters. Main app tests cover malformed catalog data, download handoff, credentials validation, transfer recovery, collision protection and fresh defaults. Those fixtures do not prove a live remote provider/client is reachable.

Before publishing a Mac binary: validate Developer ID Application signing, hardened runtime, notarization and stapled ticket on the exact DMG/app; verify install/update in a disposable location without replacing owner apps. No credentials are copied into this repository. No ad-hoc binary should be advertised as notarized.
