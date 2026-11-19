# listen-desktop agent tools

This standalone product uses its own DESIGN.md and PROJECT_CONTEXT.md. Shared technical references are pinned in requirements/source.json to Somamill/mac-development-tools; they impose no dot. membership or brand requirements. The historical dot-only managed documents were removed from the current tree, with Git history retained.

Run python3 .agent-tools/run.py requirements before repository work. It verifies local documentation only and never downloads executable code. Optional --shared-checkout verifies an existing authorized checkout. The private shared repository is not required to build or contribute to this public product. --update verifies the same approved pin; changes require source review. See requirements/AGENT_DEVELOPMENT.md and TOOL_CATALOG.md.

Local run.py also routes impeccable, hallmark and hyperframes to installed tools. Setup is explicit; no requirements check installs a service, adds validation jobs, handles credentials or enables Actions. Build, sign, notarize and release remain consumer-owned. Global tool/background-control policies still apply.
