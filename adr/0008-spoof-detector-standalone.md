# ADR 0008: Spoof-detector as a standalone submodule

**Status**: Accepted
**Date**: 2026-05-07
**Deciders**: Biometric, research, platform

## Context

Anti-spoof / presentation-attack detection (PAD) for FIVUCSAS includes several model families:

- **rPPG** (remote photoplethysmography) — heart-rate signal recovered from facial micro-colour changes, the "screen replay" defence.
- **DNN spoof classifiers** — passive image-based PAD (UniFace and successors).
- **Texture / Moiré detectors** — screen-capture artefacts.
- **MRZ + document forensics** — separate from face PAD but adjacent to the same intake.

Two competing pressures were at play:

1. **The biometric-processor (Python / FastAPI) needs PAD at request time.** Verify and enroll endpoints take frames and need a verdict.
2. **The PAD work itself is a research target.** The project is positioned for BIOSIG 2026 / IJCB 2026 submission. A research repo wants its own ROADMAP, paper drafts, bootstrap-CI scripts, dataset README, evaluation tables — none of which belong in a production FastAPI service repo. The memory rule `feedback_spoof_detector_architecture` captures this: *"Algorithms live in spoof-detector submodule; biometric-processor only imports + wires. Don't cherry-pick algorithm code directly into biometric-processor."*

We also did not want to invent a vendor / license problem. The PAD models we train + evaluate are ours; the corpora include both open datasets and our own captures. Keeping that in a dedicated repo makes attribution and licensing tractable.

## Decision

Anti-spoof algorithms live in **`spoof-detector/`**, a separate git submodule of FIVUCSAS. The submodule is published as a versioned Python package; biometric-processor pins it as a dependency.

The split:

- `spoof-detector/`: model code, training scripts, evaluation harness, paper drafts, dataset README, version tags (e.g. `v0.2.1`).
- `biometric-processor/`: import-and-wire only. `app/infrastructure/spoof/` adapts `spoof_detector.api.*` to the platform's port (`PadDetector` interface). No algorithm code lives here; bumping the PAD model is a submodule SHA bump + one config flag.

Per the parent `ROADMAP.md` (2026-05-11), the integration is live: `biometric-processor → 6f69a7d` integrates `spoof-detector v0.2.1`, and the paper push is the active research wave.

## Consequences

**Positive**
- Research and platform are decoupled. Paper authors do not need to coordinate with platform deploys to iterate on models; platform deploys do not block on paper progress.
- The PAD repo carries its own README, ROADMAP, citation block, dataset card, and license — making it citable and submittable as standalone work.
- Versioning: biometric-processor pins a tag; rolling back PAD is a tag change, not a code archaeology project.
- Tests for PAD live with PAD (114 tests at last count); biometric-processor's integration test asserts the contract, not the algorithm.

**Negative**
- Two-repo workflow. Contributors who touch both have to commit twice, push twice, and bump the submodule pointer in biometric-processor.
- Worktree / submodule operations require care (`gh -R Rollingcat-Software/spoof-detector` not the parent — captured in `feedback_gh_repo_flag.md`).
- Initial integration cost: a `PadDetector` port in biometric-processor + an adapter for the submodule API + a configuration surface to swap implementations.

**Neutral**
- This matches a research-platform pattern many groups use (think `transformers/` vs the app that consumes it). Familiar to anyone with academic background, which is the contributor pool we are recruiting from.

## Alternatives considered

- **Keep PAD inline in biometric-processor.** Rejected: dilutes both the production repo and the paper. The memory rule (`feedback_spoof_detector_architecture`) was written after cherry-picking attempts went wrong — algorithm tweaks that should have happened in one place ended up needing four PRs across two repos.
- **Pull PAD into a fully external package on PyPI.** Rejected for now: dataset access + private-eval scripts make a public PyPI package premature. Submodule gives us versioning without forcing public release.
- **Bundle PAD as a Docker sidecar with HTTP API.** Rejected: extra network hop, extra container to monitor, no obvious win when the PAD pipeline runs in the same Python process as the rest of the biometric work.
- **Vendor + freeze the model weights into biometric-processor.** Rejected: makes model rolls a code change instead of a config change; defeats the whole point of iterating on PAD.

## References

- Parent `ROADMAP.md` (2026-05-11) — active spoof-detector paper-push wave.
- `MEMORY.md` `feedback_spoof_detector_architecture` — origin rule.
- `MEMORY.md` `feedback_gh_repo_flag` — submodule gh CLI gotcha.
- `MEMORY.md` "spoof-detector v0.2.1 integration" entries (sessions 2026-05-07/08/09).
- `RESEARCH_PROCTORING_AMISPOOF_2026-05-02.md` — earlier strategic memo recommending the extract.
