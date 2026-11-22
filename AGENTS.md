# listen-desktop

This repository owns the independent listen. desktop catalogue, torrent-client handoff and local library. The native sovo. player lives in Somamill/sovo. Keep their branding, features, data and release schedules separate. Somamill/mac-development-tools provides optional technical tooling.

- Start with the [README](README.md), [project context](.agent-tools/PROJECT_CONTEXT.md), [development guide](docs/DEVELOPMENT.md) and [release readiness](docs/RELEASE_READINESS.md). [Source ownership and compatibility](docs/EXTRACTION.md) explain the repository split.
- The authenticated Flask/Waitress loopback service starts in [server.py](listen_app/server.py). The native AppKit/WebKit wrapper is [Listen.swift](native/Listen.swift). Keep the bundle ID, URL scheme, data directory, Keychain service and existing migration paths compatible.
- Preserve collaborator work in an isolated branch. Run tests with isolated data and fake providers. Keep credentials, private files and test captures out of Git.
- For applicable UI or video work, read the [local tool policy](.agent-tools/policy.md) and use the supported design or video tools. Native and browser evidence cover their own surfaces.
- Keep GitHub Actions off. Direct Mac packaging is local. Signing, notarization, upload and publication require their existing owner authorization. Use the approved background runner for credential-dependent work and avoid login Keychain prompts.
- Use the [committed arm64 build lock](requirements-macos-arm64.lock) for clean packaging, and keep interface language coverage distinct from catalogue language preferences. Report actual native, locale and platform checks.

## Local validation

From the repository root with the environment described in the [development guide](docs/DEVELOPMENT.md):

```sh
python3 .agent-tools/check-instructions.py
python3 .agent-tools/run.py requirements
.venv/bin/python -m pytest tests -q
.venv/bin/python scripts/check_frontend.py
.venv/bin/python scripts/build_macos.py --dmg
```

The build script defaults to ad-hoc signing for local QA. Record the source commit, commands, test evidence and any missing platform coverage.
