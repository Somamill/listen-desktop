#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
target="${1:-ios}"
case "$target" in ios|macos) ;; *) echo 'Target must be ios or macos.' >&2; exit 2;; esac
: "${DOT_BUILD_NUMBER:?Allocate a build number from Apple first}"
: "${DOT_SIGNING_KEYCHAIN:?Prepare approved signing credentials first}"
[[ "$DOT_BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo 'Build number must be numeric.' >&2; exit 2; }
build_dir="${RUNNER_TEMP:?}/listen-store-$target"
team=$(python3 -c 'import json;print(json.load(open("store-release.json"))["teamId"])')
if [[ "$target" == ios ]]; then
  destination='generic/platform=iOS'
  : "${LISTEN_IOS_PROFILE_APP:?}" "${LISTEN_IOS_PROFILE_WIDGET:?}" "${LISTEN_IOS_PROFILE_SHARE:?}"
else
  destination='generic/platform=macOS,variant=Mac Catalyst'
  : "${LISTEN_MAC_PROFILE_APP:?}" "${LISTEN_MAC_PROFILE_WIDGET:?}" "${LISTEN_MAC_PROFILE_SHARE:?}"
fi
xcodebuild -project Listen.xcodeproj -scheme Listen -configuration Release \
  -destination "$destination" -derivedDataPath "$build_dir/DerivedData" \
  -archivePath "$build_dir/Listen.xcarchive" CURRENT_PROJECT_VERSION="$DOT_BUILD_NUMBER" \
  DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' \
  "OTHER_CODE_SIGN_FLAGS=--keychain $DOT_SIGNING_KEYCHAIN" \
  "LISTEN_IOS_PROFILE_APP=${LISTEN_IOS_PROFILE_APP:-}" \
  "LISTEN_IOS_PROFILE_WIDGET=${LISTEN_IOS_PROFILE_WIDGET:-}" \
  "LISTEN_IOS_PROFILE_SHARE=${LISTEN_IOS_PROFILE_SHARE:-}" \
  "LISTEN_MAC_PROFILE_APP=${LISTEN_MAC_PROFILE_APP:-}" \
  "LISTEN_MAC_PROFILE_WIDGET=${LISTEN_MAC_PROFILE_WIDGET:-}" \
  "LISTEN_MAC_PROFILE_SHARE=${LISTEN_MAC_PROFILE_SHARE:-}" archive
export DOT_TARGET="$target" DOT_EXPORT_OPTIONS="$build_dir/ExportOptions.plist"
python3 - <<'OPTIONS'
import json, os, plistlib
config = json.load(open('store-release.json'))
platform = 'MAC' if os.environ['DOT_TARGET'] == 'macos' else 'IOS'
profiles = {config['bundleIdentifier'] + suffix: os.environ['LISTEN_' + platform + '_PROFILE_' + role]
            for role, suffix in [('APP', ''), ('WIDGET', '.widgets'), ('SHARE', '.share')]}
with open(os.environ['DOT_EXPORT_OPTIONS'], 'wb') as file:
    plistlib.dump({'method': 'app-store-connect', 'teamID': config['teamId'], 'signingStyle': 'manual',
                  'signingCertificate': 'Apple Distribution', 'provisioningProfiles': profiles,
                  'manageAppVersionAndBuildNumber': False, 'uploadSymbols': True}, file)
OPTIONS
xcodebuild -exportArchive -archivePath "$build_dir/Listen.xcarchive" \
  -exportOptionsPlist "$DOT_EXPORT_OPTIONS" -exportPath "$build_dir/export"
if [[ "$target" == ios ]]; then artifacts=("$build_dir/export/"*.ipa); else artifacts=("$build_dir/export/"*.pkg); fi
[[ "${#artifacts[@]}" -eq 1 && -f "${artifacts[0]}" ]] || { echo 'Expected one exported Store package.' >&2; exit 1; }
if [[ "${2:-}" == --upload ]]; then
  : "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}"
  xcrun altool --validate-app "${artifacts[0]}" --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID"
  xcrun altool --upload-app -f "${artifacts[0]}" --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID"
fi
