# Development

Python 3.13, uv, Node.js and Apple command-line developer tools are required for the native Mac build. Use the commands in README.md; build dependencies stay inside .venv. The complete native AppKit/WebKit wrapper is native/Listen.swift. Flask routes/authentication live in listen_app/server.py; catalog, covers, client adapters, Goodreads, transfer journals and local library each keep their existing modules.

UI templates/static resources ship inside the PyInstaller backend. scripts/build_macos.py compiles the wrapper, embeds the backend/resources/licenses, verifies code signatures and exercises fresh loopback startup, neutral defaults, authentication and all main pages before making ZIP/DMG and SHA-256 sums. By default this is ad-hoc signing for local QA, not notarized public distribution. LISTEN_SIGN_IDENTITY must identify a valid existing Developer ID certificate to prepare a distribution candidate; notarization must then be validated separately before publication.

Local data uses LISTEN_DATA_DIR or ~/Library/Application Support/listen. The installed desktop bundle remains io.github.somamill.listen and accepts listen://; do not change these as branding. sovo. is a separate application/container. Tests set an isolated root; never point automated fixtures at the owner’s real library.

The UI uses local semantic tokens in listen_app/static/css/tokens.css and brand.css. It has no runtime dot. branding dependency. Interface locale is distinct from catalog-language filters. Sources in locales/en.json cover static templates, dynamic errors/statuses and native UI. Each requested locale has matching keys; native .lproj resources are generated into the app at build time. Preserve placeholders, brands, links, and user media; no guessed translations of metadata.

Shared technical tooling is referenced at Somamill/mac-development-tools commit b0d92d21f6e2b19ab8480a63b5027d012719b0a1. It is an optional private reference, not a public build dependency or product membership. The shared repo owns serial validation/artifact helpers; listen-desktop owns build/sign/notarize/release and keeps secrets outside any queue. `python3 .agent-tools/run.py requirements` verifies local independent requirements; optional `--shared-checkout /path/to/mac-development-tools` verifies the reviewed helper hashes without running them. No service or job is installed.

## Transfer monitoring and locked builds

The service owns one transfer worker. It waits indefinitely with no jobs, rechecks immediately after enrolment, and applies bounded backoff when the provider is moving a torrent or the job needs attention. The authenticated loopback endpoint `GET /api/transfers/status` reports a fixed state code, pending count, next retry (Unix seconds), and an English action when applicable. It omits raw provider errors, paths, credentials and torrent identifiers. See [transfer monitor verification](verification/transfer-monitor.md).

On arm64, create a clean Python 3.13 environment and sync `requirements-macos-arm64.lock` before running `scripts/build_macos.py --dmg`. This lock is for packaging. Install pytest separately in a test environment. The bundle includes ten catalogs and corresponding native resources (ar, de, en, es, fr, id, ja, pt, ru, zh). Runtime provider content and developer diagnostics are outside that translation coverage.
