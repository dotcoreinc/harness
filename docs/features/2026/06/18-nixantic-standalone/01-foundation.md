# Foundation

## Context
Initial phase for [nixantic-standalone](00-nixantic-standalone.md). This phase will hold the detailed plan, investigations, tasks, and file scope for extracting the standalone Nixantic module plus the Home Manager adapter and AP instruction corpus.

## Requirements
* R1.A: Preserve the current `nixantic.*` option namespace while moving rendering behavior into a standalone `lib.evalModules`-compatible core module
* R1.B: Keep the standalone core free of Home Manager dependencies and `home.file`-specific behavior
* R2.A: Refactor the Home Manager module into a thin adapter that consumes the core outputs and performs HM install mapping
* R2.B: Expose Home Manager module outputs through compatibility-friendly flake outputs when cheap to maintain
* R3.A: Move the reusable renderer framework from `../appdots/nixantic/**` into this repository without coupling it to appdots-specific runtime glue
* R3.B: Move the authored instruction corpus into `instructions/` and make the public profile naming configurable rather than AP-specific
* R3.C: Provide optional generic wrappers that launch Claude Code and OpenCode against the generated config directory
* R4.A: Preserve `appdots` ownership of user-specific integrations such as `nono`, `maybe`, shell helpers, and local machine/runtime glue
* R4.B: Treat output parity with current `appdots` behavior as a soft goal with explicit regression checks where high value

## Questions & Investigations
* [x] Q: Where is the reusable framework already located?
  * Uncertainty: It was unclear whether the reusable renderer was deeply entangled with Home Manager.
  * Tried: Reviewed `../appdots/nixantic/default.nix`, `../appdots/nixantic/home-manager.nix`, `../appdots/nixantic/source-sets.nix`, and `../appdots/nixantic/instructions/**`.
  * Result: Most rendering logic is already reusable; the main work is extracting it cleanly into a standalone repo and moving option ownership from HM/flake-parts layers into a generic core module.
* [x] Q: Where is the authored corpus currently sourced from?
  * Uncertainty: Needed the concrete path to define move boundaries.
  * Tried: Reviewed `../appdots/home-manager/modules/agentic/instructions/**` and the consuming HM module.
  * Result: The authored corpus currently lives under the appdots Home Manager tree and should move into this repo under `instructions/`.
* [x] Q: What should remain in `appdots` after extraction?
  * Uncertainty: Needed to avoid over-moving personal runtime glue.
  * Tried: Reviewed Claude/OpenCode integration modules and separated generated-config concerns from personal wrapper/integration concerns.
  * Result: User-specific runtime glue stays in `appdots`; only optional generic config-dir wrappers move here.
* [x] Q: What is the current best-practice context around Home Manager flake outputs?
  * Uncertainty: Naming conventions have shifted across `homeModules`, `homeManagerModules`, and generic module outputs.
  * Tried: Reviewed Home Manager docs and recent ecosystem discussions.
  * Result: Use compatibility aliases in the plan where the maintenance cost is small.
* [ ] Q: What is the exact public API compatibility contract for the standalone repo?
  * Uncertainty: Current surfaces are split between flake-parts outputs and Home Manager module outputs, and the plan only says to preserve the `nixantic.*` namespace broadly.
  * Need: Pin down the canonical core options/outputs, any compatibility aliases, and the exact flake exports (`lib`, modules, packages, checks).
* [ ] Q: What corpus identity/profile model should be exposed by default?
  * Uncertainty: The repo should not hard-code an AP-focused identity, but the current authored corpus is still AP-specific in content and assumptions.
  * Need: Decide whether the repo ships a generic default profile, an AP-specific profile under a configurable/non-default name, or both.
* [ ] Q: What exact wrapper behavior should be implemented for Claude and OpenCode?
  * Uncertainty: Claude and OpenCode differ in config-dir environment variables and current consumer wiring.
  * Need: Decide the canonical wrapper contract, especially whether OpenCode should target `OPENCODE_CONFIG_DIR`, `OPENCODE_CONFIG`, or another explicit layout.
* [ ] Q: What migration mechanics should be used between this repo and `appdots`?
  * Uncertainty: A copy-first migration and a move-first migration have different safety and review characteristics.
  * Need: Decide whether to establish a fully working standalone copy first and then switch `appdots`, or to do a tighter coordinated migration.

## Tasks
- [x] Build the detailed implementation plan and task breakdown (R1, R2, R3, R4)
  - AC: Requirements are expanded into concrete work items with clear acceptance criteria
  - AC: Key files/components, dependencies, testing strategy, and assigned agent levels are documented
- [ ] Phase 1: establish the standalone framework skeleton (R1, R3)
  - Agent: senior
  - Dependencies: none
  - AC: A standalone flake/package structure exists in this repo and can host the extracted framework without depending on `appdots`
  - AC: Reusable renderer files from `../appdots/nixantic/instructions/**` and supporting source discovery logic are copied or moved into coherent standalone locations
  - AC: Existing reusable tests/fixtures are ported or mirrored into the standalone repo as a baseline safety net
  - AC: A public library surface exists for direct renderer usage in addition to the future module-driven path
- [ ] Phase 2: introduce the standalone core module (R1)
  - Agent: staff
  - Dependencies: Phase 1
  - AC: A `lib.evalModules`-compatible core module owns the main `nixantic.*` option surface
  - AC: Core evaluation works outside Home Manager and exposes rendered/package outputs required by downstream consumers
  - AC: Core behavior no longer requires `home.file` or HM-specific module state
  - AC: Compatibility-sensitive outputs are preserved or intentionally documented where they differ
  - AC: The core documents how `pkgs` and other module arguments are provided, using `specialArgs` only where import-time resolution actually requires it
- [ ] Phase 3: refactor the Home Manager adapter (R2)
  - Agent: senior
  - Dependencies: Phase 2
  - AC: The HM module consumes the core outputs instead of owning renderer behavior directly
  - AC: HM-specific install-file mapping remains functional, including duplicate-target validation
  - AC: Flake module outputs expose compatibility-friendly HM module entrypoints and aliases where cheap to maintain
  - AC: HM-specific tests prove the adapter still works while the core remains HM-independent
- [ ] Phase 4: move and package the instruction corpus (R3)
  - Agent: senior
  - Dependencies: Phase 1, Phase 2
  - AC: The authored corpus is relocated from `../appdots/home-manager/modules/agentic/instructions/**` into `instructions/`
  - AC: Public configuration does not hard-code an AP-focused corpus identity; naming/profile selection is configurable
  - AC: The repo exposes a default configurable profile and/or convenient package path for rendering the shipped corpus
  - AC: Claude/OpenCode rendered trees for the shipped corpus build successfully from the standalone repo
- [ ] Phase 5: provide optional generic config-dir wrappers (R3)
  - Agent: senior
  - Dependencies: Phase 4
  - AC: The repo provides optional wrappers or equivalent launch surfaces for Claude Code and OpenCode that point at the generated config directory
  - AC: Wrapper behavior remains generic and does not absorb appdots-specific integrations such as personal shell glue, `nono`, or `maybe`
  - AC: Standalone usage outside Home Manager is documented and testable for the wrapper path
  - AC: Wrapper env-var behavior is explicit and tested per harness instead of assuming Claude/OpenCode use the same contract
- [ ] Phase 6: migrate `appdots` to consume the standalone repo (R4)
  - Agent: staff
  - Dependencies: Phase 2, Phase 3, Phase 4, Phase 5
  - AC: `appdots` replaces local Nixantic framework imports with inputs from this standalone repo
  - AC: User-specific runtime integrations remain in `appdots` unless explicitly generalized first
  - AC: High-value regression checks confirm rendered entry files, install behavior, and key output surfaces remain acceptable after migration
  - AC: Any intentional drift from previous `appdots` behavior is documented as a soft-parity deviation rather than an accidental regression
  - AC: The migration sequence is documented clearly enough to avoid partial-switch states that strand `appdots` between two incompatible framework surfaces
- [ ] Phase 7: documentation and examples polish (R1, R2, R3)
  - Agent: junior
  - Dependencies: Phase 2, Phase 3, Phase 4, Phase 5
  - AC: README or equivalent usage docs cover direct renderer usage, standalone core module usage, Home Manager adapter usage, and shipped corpus usage
  - AC: Example snippets are backed by checks or otherwise verified to stay in sync with the implementation
  - AC: Developer-facing docs explain source discovery, harness layout, and wrapper boundaries clearly

- [ ] Add autonomous validation tasks for framework extraction (R1, R3)
  - Agent: senior
  - Dependencies: Phase 1
  - AC: Port or create reusable eval tests covering source discovery, frontmatter, dual outputs, post-processing, collisions, BOM generation, and settings behavior
  - AC: `nix flake check` or equivalent validation runs these framework tests in the standalone repo
  - AC: Failures identify root-cause regressions rather than being papered over by weakened assertions
- [ ] Add autonomous validation tasks for the standalone core module (R1)
  - Agent: staff
  - Dependencies: Phase 2
  - AC: Tests evaluate the core with `lib.evalModules` outside Home Manager
  - AC: Tests assert concrete rendered/package outputs and the absence of HM-only dependencies
  - AC: Compatibility-sensitive option behaviors are covered by targeted assertions
  - AC: Tests cover the documented `pkgs`/module-argument contract and guard against accidental overuse of `specialArgs`
- [ ] Add autonomous validation tasks for the Home Manager adapter (R2)
  - Agent: senior
  - Dependencies: Phase 3
  - AC: Tests cover HM install-file mapping, duplicate target validation, and integration with core outputs
  - AC: A regression test proves the same configuration can be evaluated via the core without HM install semantics
- [ ] Add autonomous validation tasks for the shipped corpus and wrappers (R3)
  - Agent: senior
  - Dependencies: Phase 4, Phase 5
  - AC: Tests build the shipped Claude/OpenCode rendered trees and assert key files like `CLAUDE.md` and `AGENTS.md` exist with expected content anchors
  - AC: Wrapper checks verify the generated config directory is the one used at launch time
  - AC: Snapshot-style checks are used only where they provide durable signal rather than noisy churn
  - AC: Harness-specific frontmatter and output directory behavior remain covered by targeted assertions
- [ ] Add autonomous validation tasks for appdots migration safety (R4)
  - Agent: staff
  - Dependencies: Phase 6
  - AC: Migration checks evaluate `appdots` against the standalone input and verify important generated surfaces remain acceptable
  - AC: Soft-parity comparisons focus on high-value behavior rather than brittle byte-for-byte reproduction unless explicitly needed
  - AC: Migration checks compare the current appdots-rendered package against the standalone-rendered package using high-value anchors and key paths

## Files
- **../appdots/flake.nix**: Consumer flake migration touchpoint and likely place where the standalone repo becomes an input.
- **../appdots/nixantic/default.nix**: Existing flake-parts exposure and current package/check/module wiring reference.
- **../appdots/nixantic/home-manager.nix**: Current mixed core/HM module that should be split into standalone core plus thin adapter.
- **../appdots/nixantic/source-sets.nix**: Current source discovery and duplicate validation implementation to preserve.
- **../appdots/nixantic/instructions/default.nix**: Current renderer entrypoint and output assembly.
- **../appdots/nixantic/instructions/builders.nix**: Public authoring/build helpers that should remain part of the reusable surface.
- **../appdots/nixantic/instructions/frontmatter.nix**: Harness frontmatter formatting and escaping behavior.
- **../appdots/nixantic/instructions/harnesses/default.nix**: Harness registry and shared harness metadata.
- **../appdots/nixantic/instructions/harnesses/claude.nix**: Claude-specific output/frontmatter behavior.
- **../appdots/nixantic/instructions/harnesses/opencode.nix**: OpenCode-specific output/frontmatter behavior.
- **../appdots/nixantic/instructions/scope.nix**: Core scope/render pipeline and collision logic.
- **../appdots/nixantic/instructions/output.nix**: Package assembly and BOM generation logic.
- **../appdots/nixantic/instructions/render-bom.py**: BOM support script and dependency surface.
- **../appdots/nixantic/instructions/checks.nix**: Reusable check derivations for renderer validation.
- **../appdots/nixantic/instructions/tests/**: Existing baseline tests to port into the standalone repo.
- **../appdots/home-manager/modules/agentic/default.nix**: Current corpus consumer and package wiring in `appdots`.
- **../appdots/home-manager/modules/agentic/instructions/**: Current authored corpus to relocate into `instructions/`.
- **../appdots/home-manager/modules/agentic/claude/default.nix**: Current Claude runtime integration split reference.
- **../appdots/home-manager/modules/agentic/opencode/default.nix**: Current OpenCode runtime integration split reference.
- **flake.nix**: Expected standalone flake entrypoint to add during implementation.
- **modules/core.nix**: Expected standalone `lib.evalModules`-compatible core module to add during implementation.
- **modules/home-manager.nix**: Expected thin Home Manager adapter to add during implementation.
- **instructions/**: Expected new home for the repo-shipped configurable instruction corpus/profile.
- **checks/** or equivalent test locations: Expected home for standalone validation tasks and regression checks.
