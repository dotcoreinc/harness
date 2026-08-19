# Add the pi harness

## Context

Add `pi` as the third supported instruction harness in this repository, alongside the existing Claude Code and OpenCode harnesses. Render the shared authored corpus into Pi-native context, prompt, skill, and configured agent-plugin formats, then expose those files through the existing renderer and Home Manager installation surfaces.

## Checkpoint

Implementation is complete. Pi renders active `AGENTS.md`, neutral `agents/`, `prompts/`, and `skills/` artifacts through the shared renderer and configurable capability adapters; Home Manager installs them through generic source-to-target mappings. Full rendering, focused checks, final reviews, `nix build .#builtin`, and `nix flake check --show-trace` pass.

## Requirements

* R1: ✅ Support pi as a first-class rendered instruction harness (Phase: Shared renderer foundation, Pi target and corpus compatibility)
  * R1.1: ✅ Preserve the existing Claude Code and OpenCode behavior while adding pi support.
  * R1.2: ✅ Define the pi output contract and supported authored source types.
  * R1.3: ✅ Allow Pi agent-file rendering to select a declared plugin adapter, starting with tintinweb, without installing or invoking that plugin.
  * R1.4: ✅ Add configurable `files` and `merge-main` rule output, defaulting to `merge-main` for Pi.
* R2: ✅ Adapt the built-in instruction corpus to Pi's configured capabilities (Phase: Pi target and corpus compatibility)
  * R2.1: ✅ Render task workflows for the configured Pi task adapter, defaulting to tintinweb.
  * R2.2: ✅ Render interactive questions for the configured Pi question adapter, defaulting to pi-vault-questionnaire.
  * R2.3: ✅ Render sub-agent workflows and definitions for the configured Pi agent adapter, defaulting to tintinweb.
  * R2.4: ✅ Avoid emitting unavailable or incorrectly translated Pi tool and permission semantics.
* R3: ✅ Expose Pi through the existing renderer and Home Manager consumer surfaces (Phase: Consumer integration and validation)
  * R3.1: ✅ Allow `harness = "pi"` in generic Home Manager instruction-file installation.
  * R3.2: ✅ Keep Pi runtime, extension installation, launchers, mutable settings, themes, model-provider configuration, and credentials out of scope; optional agent model metadata remains renderable.
* R4: ✅ Validate the pi integration against current pi behavior and repository checks (Phase: Consumer integration and validation)
  * R4.1: ✅ Verify rendering, generated layout, module integration, and preserved Claude Code/OpenCode behavior through automated checks and output inspection.
* R5: ✅ Document an implementation-ready breakdown with files, dependencies, agents, and acceptance criteria (Phase: Research and plan)

## Design

The implementation should extend the existing harness abstraction and source-fragment discovery rather than hand-edit generated output. This project is limited to generating instruction artifacts; it does not provide a Pi launcher, web interface, npm/plugin installation, mutable Pi settings, credentials, models, themes, or runtime integration.

## Questions & Investigations

* [x] Q: What pi version and distribution/configuration contract should be supported?
  * Result: Target the current Pi instruction contracts documented by the official Pi project, while pinning no runtime package because this repository only renders instructions. The tintinweb adapter targets its documented v0.17.1 agent-file format as the first adapter contract.
* [x] Q: Which repository source types map to pi, and how should unsupported concepts be represented?
  * Result: Main and aggregated rule content maps to `AGENTS.md`; skills map to Pi `skills/<name>/SKILL.md`; commands map to Pi `prompts/<name>.md`; agents map through the selected agent adapter, initially tintinweb. Blocks remain composition inputs rather than independent Pi resources.
* [x] Q: How should Pi consume rule files that it does not discover independently?
  * Answer: Add a Nixantic rule-aggregation mode that combines rule content into the main instruction file. Enable this mode by default for Pi.
  * Answer: In aggregation mode, omit standalone rule files. Claude Code and OpenCode retain the current separate-file behavior.
  * Consequence: The renderer must preserve deterministic rule ordering, avoid duplicate active content, and allow harness defaults to be overridden through configuration. The selected option is `rules.output = "files" | "merge-main"`.
* [x] Q: Is Pi runtime/plugin installation part of this project?
  * Answer: No. Generate instruction artifacts only. Runtime activation and plugin installation remain the user's responsibility.
  * Consequence: Do not add a Pi launcher, npm dependency, plugin installer, or Pi settings generation to this project.
* [x] Q: How should configurable Pi capability adapters be represented in the renderer/Home Manager configuration?
  * Finding: `@tintinweb/pi-subagents` supplies sub-agent tools but not task or interactive-question tools. Existing instructions reference all three capabilities.
  * Finding: `@tintinweb/pi-tasks` separately supplies Claude-compatible task tools. Pi question extensions use incompatible schemas, while plain chat remains universally available.
  * Answer: Use independent Pi adapter selections for agents, tasks, and questions. Default them to tintinweb sub-agents, tintinweb tasks, and pi-vault-questionnaire respectively. Keep future alternatives and fallback adapters possible.
  * Consequence: Adapter selection changes rendered schemas, tool names, and prose only. It never installs, activates, or invokes a Pi extension.
* [x] Q: Can harness and plugin adapters share a small functional interface?
  * Proposal: An adapter receives normalized artifact attributes and returns frontmatter attributes directly, with destination-path metadata handled by the same adapter contract or a neighboring function.
  * Goal: Make tintinweb one configured adapter rather than embedding plugin-specific branches, while allowing the same mechanism to simplify Claude Code, OpenCode, Pi, and future harnesses.
  * Constraint: Avoid turning Pi support into an unrelated renderer rewrite; preserve exact existing output and introduce only the abstraction required by real current adapters.
  * Investigation: Existing Claude Code and OpenCode frontmatter renderers are already close to this shape. A common artifact renderer can return `outputPath`, `frontmatter`, and explicit `frontmatterOrder`; shared code resolves authored path overrides and serializes the body.
  * Important boundary: Capability adapters for task, question, and sub-agent tool names remain separate from artifact/frontmatter rendering. Only agent-file plugins such as tintinweb need both concerns composed.
  * Staff estimate: Approximately 500-800 production/source lines, 500-800 test/check lines, and 4-7 engineering days. Complexity is medium-high because of corpus adaptation and renderer regression risk, not Pi schema volume.
  * Decision: Adopt the common artifact-renderer contract across Claude Code, OpenCode, Pi, and Pi agent-file adapters. Keep capability adapters separate and do not build a universal plugin framework.

## Phases

### ✅ 01 Phase: Research and plan

[01-research-and-plan](01-research-and-plan.md)

Research pi's current harness contract, inspect the repository's existing harness implementation, resolve product and technical questions, and produce the detailed implementation plan. No production implementation is included in this phase.

### ✅ 02 Phase: Shared renderer foundation

[02-shared-renderer-foundation](02-shared-renderer-foundation.md)

Introduce the common normalized-artifact renderer contract, migrate Claude Code and OpenCode without output changes, carry logical artifact kinds through output/BOM handling, and implement generic `files`/`merge-main` rule output. Pi is not globally registered in this phase.

### ✅ 03 Phase: Pi target and corpus compatibility

[03-pi-target-and-corpus-compatibility](03-pi-target-and-corpus-compatibility.md)

Implement Pi-native artifact rendering, independent capability adapters, and the tintinweb agent-file adapter; then adapt the built-in corpus and register Pi only after focused rendering passes. Ensure generated Pi instructions use only declared capabilities and preserve safety restrictions.

### ✅ 04 Phase: Consumer integration and validation

[04-consumer-integration-and-validation](04-consumer-integration-and-validation.md)

Expose Pi through the existing module and Home Manager installation surfaces, extend repository checks and examples, and run full rendering and flake validation. This phase adds no Pi runtime or plugin installation behavior.

## Files

- **flake.nix**: Public flake surface to assess for a third harness package/module export.
- **modules/**: Module APIs and Home Manager instruction-file installation surface for Pi exposure; existing wrappers remain Claude Code/OpenCode-only.
- **modules/home-manager.nix**: Existing `install.files` harness selector, which derives its enum from rendered harness names and installs selected paths.
- **framework/**: Shared artifact renderer, explicit instruction roles, rule merging, Pi harness/adapters, logical BOM kinds, fixtures, and regression tests (Phases 02-03).
- **instructions/**: Pi-safe built-in corpus, explicit instruction roles, capability-aware workflows, and Pi-specific rules (Phases 02-03).
- **modules/core.nix**: Typed per-harness rule output and Pi adapter options, settings threading, and corpus validation (Phase 04).
- **modules/home-manager.nix**: Existing generic install-file adapter used unchanged for Pi mappings (Phase 04).
- **checks/default.nix**: Three-harness module, corpus, routing, README, and Home Manager validation (Phases 03-04).
- **README.md**: Pi configuration, neutral generated layout, adapters, and global/project Home Manager mapping examples (Phase 04).
- **source-sets.nix**: Source-root discovery and duplicate detection contract.
- **docs/features/2026/08/19-pi-harness/01-research-and-plan.md**: Research findings and implementation-ready phase plan.
- **docs/features/2026/08/19-pi-harness/02-shared-renderer-foundation.md**: Common artifact renderer, logical output metadata, and rule-output plan.
- **docs/features/2026/08/19-pi-harness/03-pi-target-and-corpus-compatibility.md**: Pi renderers, adapters, and built-in corpus compatibility plan.
- **docs/features/2026/08/19-pi-harness/04-consumer-integration-and-validation.md**: Module, Home Manager, docs, and final validation plan.
