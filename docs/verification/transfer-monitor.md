# Transfer monitor verification

Baseline: `52739513e51000713641efef6bcb09ae4a7c146a`. The baseline queried providers only with existing jobs, but called the monitor body every five seconds. The new worker waits indefinitely when empty, checks immediately on enrolment, and retries moving jobs at 2 seconds up to 15 seconds. Error and verification waits start at 5 seconds and cap at 120 seconds. Backoff doubles for a repeated state. The authenticated loopback diagnostics display a troubleshooting action and retry time without provider messages, book names, paths, IDs, or credentials.

| Five-minute workload | Baseline | Changed |
| --- | ---: | ---: |
| Idle periodic wakes | 60 | 0 |
| Idle provider calls | 0 | 0 |
| Provider calls during continuous failure | 60 | 7 |
| Poll intervals during continuous failure | 5 s | 5, 10, 20, 40, 80, 120 s, then capped |

The baseline counts replay its exact loop with mocked time, settings and provider responses. The new failure test advances a fake clock through the actual worker waits. The idle test proves the initial wait has no timeout and measures an actual thread wake on enrolment. The provider probe started about 1 ms after recording the job on this Mac. That is a local observation, not a scheduling guarantee or a battery measurement.

## Transfer safety

The existing journal is compatible. Jobs survive incomplete moves, errors, unknown torrent IDs, temporary omissions and restart. The monitor requires a local, matching client and a complete torrent reporting a library location. Every recorded destination file must be a regular file of the original size and every original must be absent. Symlinks cannot satisfy a file check, and existing destinations are rejected before starting a move. This is a size check. It does not detect equal-size content changes or make another client’s filesystem move atomic.

Completion attempts are serialized. When an RPC succeeds and journal persistence fails, an in-memory receipt avoids a second removal call in that process. After a crash before the journal update, a missing torrent remains a pending job for inspection. Torrent removal explicitly retains data. Cleanup prunes only empty source directories and Finder metadata as before. Idle and backoff waits cancel immediately on service shutdown. A provider call already in progress cannot be recalled.

## Reproduction

Run from the checkout root on arm64 macOS:

```sh
uv venv --python 3.13 .venv
uv pip sync --python .venv/bin/python requirements-macos-arm64.lock
uv pip install --python .venv/bin/python pytest
python3 .agent-tools/run.py requirements
.venv/bin/python -m pytest tests -q -s
.venv/bin/python scripts/check_frontend.py

uv venv --python 3.13 ../listen-transfer-build-env
uv pip sync --python ../listen-transfer-build-env/bin/python requirements-macos-arm64.lock
env -u LISTEN_SIGN_IDENTITY -u LISTEN_SIGN_KEYCHAIN \
  ../listen-transfer-build-env/bin/python scripts/build_macos.py --dmg
(cd dist && shasum -a 256 -c SHA256SUMS-arm64.txt && hdiutil verify listen-0.5.0-macOS-arm64.dmg)
```

The Python suite passed 58 tests, including corruption, collision, incomplete and failed moves, duplicate cleanup and restarted journal handling. The frontend check rendered five pages and checked 20 inline scripts and standalone JavaScript. Updater tests cover the official repository, architecture and stable filters, warm offline cache, manual errors and automatic recovery after a failed check. The updater implementation is unchanged.

The clean arm64 build compiled the native wrapper and froze its locked service. Bundled smoke tests exercised startup, neutral defaults, rendered routes, launcher identity and authentication. A separate extraction verified the ad-hoc bundle signature and packaged locales, then launched the frozen service with a new data root. Its startup created the official-release check cache, the cached API reused it, the manual endpoint refreshed it, and SIGTERM removed the connection file. Neither update path installed anything.

Ten packaged catalogs cover the existing interface. Fresh linguistic review, all-locale native screen checks, Intel packaging, live provider move and real-world energy measurement were outside this run. The candidate ZIP and DMG are ad-hoc signed local artifacts. Developer ID signing, notarization and public publication were outside this task.
