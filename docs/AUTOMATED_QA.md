# Background release QA

Owner policy (17 November 2026): GitHub Actions remain disabled. Do not enable or dispatch hosted jobs for routine releases. While this policy applies, run the equivalent native simulator suites and Mac build locally against the exact source being archived, retaining result bundles and logs.

`.github/workflows/app-qa.yml` runs through the native-player CI workflow on pull requests and main commits. It can also be dispatched manually before preparing a Store build. The GitHub release workflow requires this same reusable QA workflow before packaging or publishing.

The final `quality-gate` fails if any dependency fails, is cancelled, or is skipped. It covers Python unit/dependency/frontend checks, native XCTest logic and UI tests on fresh iPhone and iPad simulators, and a sandboxed Mac Catalyst build with bundle/privacy checks. Native tests cover imports, playback and progress persistence, bookmarks and note editing, navigation with the mini-player, settings, and server-connection forms. A new UI test terminates and relaunches the app to verify bookmark-note persistence. Corrupt library-index tests verify that imported media and the original index are retained.

Debug-only UI-test fixtures use an isolated temporary library and disable iCloud. `--uitesting-preserve` keeps only that test library for relaunch tests; Release builds ignore both test flags. The QA script creates/deletes only its own simulators. XCTest result bundles and logs are retained for seven days, outside signing jobs.

Run locally from the repository root:

```sh
RUNNER_TEMP=/tmp/sovo-qa python3 ios/scripts/qa-simulator.py
```

Use a fresh output directory for a new run. Xcode result bundles cannot overwrite an existing bundle.

Native Store delivery also invokes this QA workflow before signing or uploading. It is disabled on push until `STORE_RELEASE_ENABLED=true`; manual delivery still requires the approved `store-release` environment. No publishing credentials are copied to GitHub by this change and current App Store submissions are untouched. To upload outside GitHub, first pass the local equivalent described above on the exact archived source while Actions are disabled; checks on different source do not qualify.

The delivery environment uses the same distribution certificate/API-key secrets as read. and Immersed. (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY_P8_BASE64`, `APPLE_DISTRIBUTION_P12_BASE64`, `APPLE_DISTRIBUTION_PASSWORD`, and Mac installer equivalents). Add the app profile as `IOS_PROVISIONING_PROFILE_BASE64` / `MAC_PROVISIONING_PROFILE_BASE64`, plus the matching `IOS_WIDGETS_PROFILE_BASE64`, `IOS_SHARE_PROFILE_BASE64`, `MAC_WIDGETS_PROFILE_BASE64` and `MAC_SHARE_PROFILE_BASE64`. Profiles are decoded and checked for team, target, distribution type and expiry. Existing credentials must not be moved into GitHub without the owner's approval of that storage destination. Delivery uploads tested builds to Apple and verifies processing; App Review submission remains a separate stage.

These checks do not certify physical-device audio/background behavior, iCloud on two real devices, live Goodreads/server accounts, VoiceOver, full Mac UI behavior, or Apple approval. Keep those as separate release checks.
