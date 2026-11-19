# Independent desktop development requirements

listen-desktop is an independent product, not a dot. suite member. Product identity, interface languages, compatibility, privacy, design and release decisions belong to this repository's DESIGN.md and .agent-tools/PROJECT_CONTEXT.md. No external brand policy is inherited through technical tooling.

The reviewed shared technical source is Somamill/mac-development-tools at b0d92d21f6e2b19ab8480a63b5027d012719b0a1. It owns serial validation runner.py, explicit installation helper install-agent.py and artifact-manifest.py. This repository owns its build, signing, notarization and release. Secrets and signing are outside the validation queue.

The references are provenance, not an installed dependency or running service. Do not install a permanent agent, add jobs or execute downloaded scripts as part of requirements checks. Actions remain disabled. Use background tools with bounded logs and clean up only owned processes.

Before source changes run python3 .agent-tools/run.py requirements. This verifies local documentation hashes; an optional --shared-checkout verifies the reviewed shared source; --update repeats verification but does not silently change the reviewed revision. Change the pin only after reviewing the shared source. Native AppKit/WebKit evidence and web rendering are distinct; source tests do not replace native checks.
