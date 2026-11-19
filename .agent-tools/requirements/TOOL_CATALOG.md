# Desktop tool ownership

- Consumer-owned: scripts/build_macos.py, scripts/make_icon.swift, scripts/check_frontend.py, Python tests and release artifacts. Developer ID credentials, keychain unlock, notarization and publication stay outside any shared queue.
- Optional private shared reviewed reference (authorized access only; not required for a public build): [README](https://github.com/Somamill/mac-development-tools/blob/b0d92d21f6e2b19ab8480a63b5027d012719b0a1/README.md), [runner.py](https://github.com/Somamill/mac-development-tools/blob/b0d92d21f6e2b19ab8480a63b5027d012719b0a1/runner.py), [install-agent.py](https://github.com/Somamill/mac-development-tools/blob/b0d92d21f6e2b19ab8480a63b5027d012719b0a1/install-agent.py), [artifact-manifest.py](https://github.com/Somamill/mac-development-tools/blob/b0d92d21f6e2b19ab8480a63b5027d012719b0a1/artifact-manifest.py). No helper is installed or invoked by this connection.
- Design: existing independent DESIGN.md; Impeccable/Hallmark for supported web surfaces, genuine native app captures for AppKit/WebKit judgments.
- Browser: isolated headless Playwright for flows, Chrome DevTools for debugging when required. Do not attach private tabs without a task need.
- Native: official macOS build/signature tools, native UI inspection and isolated data. Preserve io.github.somamill.listen and existing user data.
- Product locales: ten actual interface languages documented in PROJECT_CONTEXT; shared tooling does not change product membership or language scope.
