# Consumer integration and validation

## Context

Expose the completed Pi instruction output through the repository's existing public renderer and Home Manager file-installation surfaces, document consumer configuration, and perform full repository verification. Keep runtime and plugin management consumer-owned.

## Requirements

* R3.A: Generic Home Manager installation accepts Pi as a rendered harness.
* R3.B: Consumers can configure Pi rule output and capability adapters.
* R3.C: No Pi runtime, extension package, launcher, mutable setting, credential, model-provider configuration, or theme is installed or generated; optional agent model metadata may be rendered.
* R4.A: Repository checks validate all three harnesses and preserve existing behavior.

## Design

`modules/home-manager.nix` already derives valid `install.files.*.harness` values from renderer `harnessNames`. Registering Pi should make `harness = "pi"` available without a Pi-specific installer. Consumers map generated sources to their chosen global or project target paths through the existing generic `source` and `target` fields.

The rendered Pi tree is location-neutral: `AGENTS.md`, `agents/`, `prompts/`, and `skills/`. Home Manager examples map these sources to Pi's global configuration tree, while project configurations can map the same sources to project-local destinations such as `.pi/agents/`.

No new flake package is required: the existing `builtin` package contains every rendered harness tree. Existing standalone flake packages for Claude Code/OpenCode wrappers remain unchanged.

Document examples for global Pi locations while leaving project-local mappings to consumer configuration. Do not add a Pi wrapper to `wrapperPackages`; wrappers are runtime behavior outside this project's Pi scope.

Model runtime management remains out of scope. Optional `model.pi` values in generated agent frontmatter are instruction metadata consumed by the selected adapter; they do not install, configure, enable, or validate model providers.

## Questions & Investigations

* [x] Q: Should Nixantic install or activate selected Pi extensions?
  * Answer: No. Adapter settings declare the instruction contract expected by the consumer's Pi environment.
* [x] Q: Should Home Manager gain a Pi-specific installer?
  * Answer: No. Use the existing generic `install.files` mapping and derived harness enum.

## Tasks

- [x] Expose Pi renderer settings through the core module (Agent: mid-dev) (R3.B, R3.C)
  - Add typed per-harness `rules.output` options, Pi-only adapter options, and thread them into `settings.harnesses.<name>`.
  - AC: Defaults match the renderer defaults and module overrides produce the expected package tree/content.
  - AC: Direct-renderer and module option behavior is equivalent for every exposed setting.
  - AC: Options contain no runtime package, executable, installation, credentials, models, themes, or mutable Pi settings.
- [x] Validate generic Home Manager Pi installation (Agent: mid-dev) (R3.A)
  - Extend module tests/examples to select `harness = "pi"` and map representative context, skill, prompt, and agent files.
  - AC: Every source resolves under `${instructions.package}/pi/` to the configured target.
  - AC: Duplicate-target validation remains unchanged and covers Pi entries.
  - AC: No Pi-specific Home Manager installation mechanism is introduced.
  - AC: Pi configuration adds nothing to wrappers, `tools.packages`, or `home.packages`.
- [x] Extend public checks and built-in package assertions (Agent: mid-dev) (R4.A)
  - Replace appropriate hard-coded two-harness loops/assertions with registry-driven or explicit three-harness coverage.
  - AC: Built-in package checks assert active Pi context, prompts, skills, and tintinweb agent output.
  - AC: Existing Claude Code/OpenCode wrappers remain unchanged; no Pi wrapper or wrapper check exists.
  - AC: Git-export, routing, module, and README example checks cover Pi where applicable.
- [x] Update consumer documentation (Agent: mid-dev) (R3, R4)
  - Document three supported harnesses, Pi output layout, `rules.output`, independent adapters, and Home Manager mappings.
  - AC: Documentation clearly states that consumers install and activate Pi and extensions themselves.
  - AC: Examples are validated by repository checks and do not promise unsupported runtime behavior.
- [x] Run final rendering and repository validation (Agent: mid-dev) (R4.A)
  - Run focused tests during iteration, then `nix flake check --show-trace` and `nix build .#builtin`.
  - AC: All checks pass.
  - AC: Inspect `result/pi` and verify exact documented paths, aggregated `AGENTS.md`, absence of standalone rule files, and no secrets/mutable runtime files.
  - AC: Review the full diff for unexpected generated files, deletions, or Claude Code/OpenCode output changes.
- [x] Correct the reviewed tintinweb global installation mapping (Agent: mid-dev) (R3.A)
  - Map generated agent sources to tintinweb's actual global agent directory rather than nesting the project `.pi/agents` path below the global Pi config directory.
  - AC: README, Home Manager tests, and public checks use an effective documented tintinweb global target and remain generic source-to-target mappings.
- [x] Use a neutral rendered Pi agent source directory (Agent: senior-dev) (R3.A)
  - Render tintinweb agent files under `pi/agents/`; consumers map that source to global `.pi/agent/agents/` or project `.pi/agents/` targets.
  - AC: Renderer, BOM, corpus checks, Home Manager tests, README examples, and output inspection consistently use `agents/` as the generated source.

## Files

- **modules/core.nix**: Public Pi renderer options, settings threading, and corpus checks; no Pi wrapper.
- **modules/home-manager.nix**: Generic install-file behavior and descriptions/tests.
- **flake.nix**: Public checks/packages only where existing exports require three-harness coverage.
- **checks/default.nix**: Module, routing, export, corpus, and README validations.
- **framework/tests/install-files.nix**: Derived Pi harness enum and installation mapping tests.
- **README.md**: Consumer-facing Pi rendering and Home Manager examples.
