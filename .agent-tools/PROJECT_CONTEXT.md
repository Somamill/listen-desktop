# sovo. project context

## Product and identity
The App Store edition is a native SwiftUI DRM-free audiobook player for iPhone, iPad and Mac Catalyst, named **sovo.**. The legacy desktop torrent catalogue is outside the Store binary. Preserve the historical io.github.somamill.listen.mobile identifiers, App Group, iCloud container, URL schemes and user data paths. GitHub Actions remain disabled. Native app architecture and tests live under ios/.

## Design sources
Native design: ios/DESIGN.md; current Store brief: app-store/marketing/BRIEF.md. Root DESIGN.md describes the legacy web edition. Sage/forest/cream, native system type and controls, whole covers and minimal chrome. Library combines Books / Genres / Authors / Narrators; You and Settings are the other tabs. Portraits require verified identity and licensed credits. No invented metadata or sleep detection.

## Tools and evidence
Use MobileBuildMCP/native Apple commands for builds/tests, Xcode MCP for relevant editor capabilities, and installed libimobiledevice/pymobiledevice3 over direct USB when CoreDevice is unavailable. Background APIs first; owner authorizes Chrome for Store submission. Never prompt for login-keychain passwords. Dedicated release signing credentials remain outside the repository and are locked after use. Playwright is for asset composition/web flows, not native validation. Impeccable/Hallmark principles apply to supported surfaces.

Build 11: 44 native logic tests passed; targeted native UI run passed (46 total including logic). iOS and Mac Release archives, isolated signing and Apple validation succeeded; both build 11 uploads processed VALID, not submitted. Physical iPhone build 11 installed; automatic Silk Roads metadata verified; long 34-MP3 conversion is still being verified. See ios/docs/INTEGRATION-QA.de.md and app-store/RELEASE-STATUS.md for completed results; these require reconciliation before release. Never infer Store submission from an archive/upload.

## Localization and release gates
The current UI is English; twelve-language baseline is not implemented or layout-reviewed. On 18 November 2026 the owner explicitly approved an exception for this already-running update (1.0.1/build 11), with twelve languages deferred to the following update. Do not advertise translated UI. The next user-facing update must inventory real UI/extensions/permissions and Store coverage, normal system/per-app language selection and Arabic RTL under managed LOCALIZATION.md/LANGUAGES.json.

Before submission: finish physical conversion/playback, inspect current real native iPhone/iPad/Mac captures and whole-cover mini-player, reconcile metadata/privacy/reviewer instructions, current research and rights ledger, sign/validate uploads, verify selected builds and actual Review state. Live private Goodreads sign-in, two-device iCloud delivery and AirPods hardware behavior must not be claimed verified without fresh evidence. Preserve user originals and personal libraries; use cleared QA media in public assets.
