# nixantic-standalone

## Context
Extract the reusable Nixantic instruction system from `../appdots` into this standalone repository. The target is a Home-Manager-independent `lib.evalModules` core module that can be used on its own, while still exposing a thin Home Manager adapter for consumers that want HM integration. The repository scope includes both the reusable framework and AP's Claude/OpenCode instruction corpus.

## Checkpoint
Implementation for foundation Phases 1-7 is in place. The standalone repo owns the reusable renderer framework, `lib.evalModules` core module, thin Home Manager adapter, built-in instruction corpus under `instructions/`, generic Claude/OpenCode config-dir wrappers, autonomous validation checks, and README usage docs. `appdots` consumes this repo via a local path flake input while keeping its Claude/OpenCode wrappers, `nono`/`maybe` integration, opencode JSON generation, and local shell/runtime glue in `appdots`.

The remaining follow-up is outside the foundation implementation: replace the local `appdots` path input with a remote/shared URL before using this setup outside this machine.

## Requirements
* R1: ⬜ Provide a standalone Nixantic core module that is compatible with `lib.evalModules` and usable outside Home Manager (Phase: foundation)
  * R1.1: Preserve the existing `nixantic.*` option namespace unless a compatibility-safe cleanup is explicitly justified in implementation planning
  * R1.2: Core behavior must not depend on `home.file` or Home Manager module state
  * R1.3: Core outputs must include the rendered instruction surface and package-oriented outputs needed by downstream consumers
  * R1.4: Shared option ownership must live in the core module, with ecosystem layers importing it rather than re-owning shared behavior
* R2: ⬜ Expose a Home Manager module that consumes the core module outputs instead of owning the core behavior directly (Phase: foundation)
  * R2.1: The Home Manager layer should stay thin and primarily map core outputs into HM install surfaces
  * R2.2: The flake should expose compatibility-friendly HM module outputs, with aliases where cheap and useful
  * R2.3: A flake-parts module may exist for ergonomic exposure, but it should remain an exposure layer rather than a second behavioral ownership layer
* R3: ⬜ Move the Claude/OpenCode instruction framework and corpus out of `../appdots` into this repository while keeping them usable through the standalone module surface (Phase: foundation)
  * R3.1: The framework must remain reusable without depending on AP-specific runtime integrations
  * R3.2: The repo should provide a default selectable built-in corpus/profile under `instructions/` without hard-coding an AP-focused public identity
  * R3.3: The repo should provide optional generic wrappers as package outputs, with HM optionally installing them, that point Claude Code and OpenCode at the generated config directory via the harness-specific environment variable
* R4: ⬜ Migrate `appdots` to consume the standalone repository with minimal disruption to user-specific runtime integrations (Phase: foundation)
  * R4.1: `appdots` should keep user-specific wrappers/integrations such as `nono`, `maybe`, local shell helpers, and other personal environment glue unless they are generalized first
  * R4.2: Output parity with current `appdots` behavior is a soft goal rather than a hard gate
  * R4.3: Migration should follow a copy-first, switch-later sequence to reduce coordination risk between repositories

## Questions & Investigations
* [x] Q: Should the standalone repo own only the framework, or also the corpus?
  * Uncertainty: The extraction could either stop at reusable rendering logic or also include the authored instructions.
  * Tried: Reviewed current split between `../appdots/nixantic/**` and `../appdots/home-manager/modules/agentic/instructions/**`.
  * Result: The standalone repo should own both the reusable framework and the corpus, but avoid AP-specific branding in the public path/API.
* [x] Q: Should runtime wrappers stay in `appdots`?
  * Uncertainty: Some wrapper behavior is generic while other parts are deeply personal/appdots-specific.
  * Tried: Reviewed current Claude/OpenCode HM modules and isolated package/config-dir wiring from user-specific integrations.
  * Result: Keep user-specific runtime integrations in `appdots`, but provide optional generic config-dir wrappers in this repo.
* [x] Q: Should the public option surface be redesigned during extraction?
  * Uncertainty: Redesign could improve clarity but increase migration risk.
  * Tried: Compared current option usage across renderer, HM module, and consumer modules.
  * Result: Preserve the current `nixantic.*` namespace and refactor internals under that compatibility surface.
* [x] Q: Which HM flake output naming should be planned for?
  * Uncertainty: Current ecosystem guidance is split between `homeModules`, `homeManagerModules`, and newer generic module outputs.
  * Tried: Checked current Home Manager manual and recent ecosystem discussion.
  * Result: Plan for compatibility aliases rather than forcing a single naming convention if the maintenance cost stays low.
* [x] Q: Is our current understanding truly 10/10?
  * Uncertainty: The initial plan covered the main architecture split, but may have left public API, wrapper, and migration details underspecified.
  * Tried: Ran a staff-level ctx-improve pass across the project docs, `../appdots` source, and current ecosystem guidance for `lib.evalModules`, Home Manager module outputs, Claude, and OpenCode config surfaces.
  * Result: Understanding improved, but the exact public API contract, wrapper env-var behavior, corpus profile identity, and migration mechanics still need to be pinned down before implementation can safely claim 10/10 understanding.
* [x] Q: Should the repo use a core module, HM module, and flake-parts module?
  * Uncertainty: Needed to distinguish behavior ownership from output exposure.
  * Tried: Reviewed the desired dendritic import model and compared it to the current split in `appdots`.
  * Result: The repo should have a core module that owns shared behavior, a thin HM module that imports it and adds HM-only behavior, and a flake-parts module used only for output exposure ergonomics.
* [x] Q: Where should shared option ownership live?
  * Uncertainty: Shared options could have remained split between core and HM layers.
  * Tried: Compared the migration cost of split ownership versus a clean core-owned surface.
  * Result: Shared `nixantic.*` options should belong to the core module only; HM should add only HM-specific options and behavior.
* [x] Q: What corpus identity/profile model should be planned?
  * Uncertainty: The current corpus is AP-specific in content, but the public repo identity should remain neutral.
  * Tried: Explored neutral built-in profile versus optional-only profile versus generic-default framing.
  * Result: Ship the current corpus as a neutral named built-in profile under `instructions/`, with a default selectable profile and configurable naming/selection.
* [x] Q: What wrapper contract should the repo own?
  * Uncertainty: Needed to pin down whether wrappers are package outputs, HM-only behavior, or outside the Nix surface.
  * Tried: Compared standalone usability needs against HM-only integration.
  * Result: Wrappers should exist as generic package outputs, HM may optionally install them, and each wrapper should set the existing harness-specific config-dir environment variable for its generated config tree.
* [x] Q: What migration sequence should be planned?
  * Uncertainty: A coordinated multi-repo switch would be riskier but potentially shorter.
  * Tried: Compared copy-first and coordinated migration strategies against reviewability and rollback safety.
  * Result: Use a copy-first, switch-later migration plan so this repo is fully working before `appdots` begins consuming it.

## Phases
### 🔄 01 Phase: foundation
[01-foundation](01-foundation.md)
Define the implementation plan, architectural decisions, investigation notes, and execution breakdown for extracting Nixantic into a standalone repository. This phase covers the standalone framework skeleton, core module split, Home Manager adapter refactor, corpus move, migration path, and validation strategy.

## Files
- **../appdots/flake.nix**: Upstream consumer entrypoint and migration touchpoint for switching from local framework imports to this standalone repo.
- **../appdots/nixantic/default.nix**: Existing flake-parts integration layer. Source context for standalone flake/module exposure planning.
- **../appdots/nixantic/home-manager.nix**: Current HM-owned option and install behavior. Main refactor target for the thin-adapter design.
- **../appdots/nixantic/source-sets.nix**: Source discovery and duplicate validation behavior that should remain part of the reusable framework.
- **../appdots/nixantic/instructions/**: Reusable renderer, harness logic, builders, outputs, checks, and tests that form the standalone framework base.
- **../appdots/nixantic/instructions/frontmatter.nix**: Harness frontmatter rendering logic that affects Claude/OpenCode compatibility.
- **../appdots/nixantic/instructions/harnesses/**: Built-in harness registry and per-harness output conventions that should stay explicit in the standalone design.
- **../appdots/nixantic/instructions/render-bom.py**: BOM generation helper and part of the standalone dependency/testing surface.
- **../appdots/home-manager/modules/agentic/instructions/**: Current authored instruction corpus to relocate into this repository under `instructions/`.
- **../appdots/home-manager/modules/agentic/default.nix**: Current corpus consumer module and package wiring in `appdots`.
- **../appdots/home-manager/modules/agentic/claude/default.nix**: Current Claude integration module. Important for separating generic wrappers from user-specific runtime glue.
- **../appdots/home-manager/modules/agentic/opencode/default.nix**: Current OpenCode integration module. Important for separating generic wrappers from user-specific runtime glue.
- **flake.nix**: Standalone public flake surface for core/HM/flake-parts modules, built-in corpus package, wrapper packages, and checks.
- **flake.lock**: Locked standalone inputs for `nixpkgs` and `flake-parts`.
- **source-sets.nix**: Standalone reusable source discovery and duplicate validation logic.
- **framework/**: Standalone renderer framework, harness registry, package/BOM generation, and reusable tests/fixtures.
- **modules/core.nix**: Core `lib.evalModules` module owning shared `nixantic.*` options and `config.nixantic.instructions.*` outputs.
- **modules/home-manager.nix**: Thin Home Manager adapter importing core and mapping outputs into HM surfaces.
- **modules/flake-parts.nix**: Exposure-only flake-parts module for package/check publication.
- **instructions/**: Built-in instruction corpus profile copied from `appdots`.
- **checks/default.nix**: Standalone validation checks for core, HM adapter, wrappers, and no-HM evaluation.
- **../appdots/flake.nix**: Phase 6 migration. Adds the standalone path input, keeps the local Nixantic adapter import, and defines the appdots migration check.
- **../appdots/flake.lock**: Phase 6 migration. Locks the standalone path input.
- **../appdots/nixantic/default.nix**: Phase 6 migration. Compatibility adapter to standalone flake-parts and HM module outputs.
- **../appdots/home-manager/modules/agentic/default.nix**: Phase 6 migration. Imports standalone HM module and relies on its built-in corpus while preserving local integrations.
- **README.md**: Phase 7 documentation. Covers standalone core usage, Home Manager adapter usage, flake-parts exposure, shipped corpus package, wrappers, direct renderer imports, source discovery, harness layout, and checks.
