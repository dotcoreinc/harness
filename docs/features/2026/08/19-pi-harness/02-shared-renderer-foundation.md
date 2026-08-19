# Shared renderer foundation

## Context

Create the smallest shared artifact-rendering contract needed by Claude Code, OpenCode, Pi, and Pi agent-file adapters. Preserve complete Claude Code and OpenCode output, carry logical artifact metadata independently from destination paths, and add generic rule output before Pi is globally registered.

## Requirements

* R1.A: Every harness artifact renderer accepts normalized attributes and returns an output path plus ordered frontmatter attributes.
* R1.B: Claude Code and OpenCode retain identical paths and file contents after migration.
* R1.C: Logical artifact kinds drive BOM and collision behavior independently from destination paths.
* R1.D: Rule output supports `files` and `merge-main`; harness defaults remain configurable.

## Design

The normalized artifact contains resolved shared values such as `kind`, instruction `role`, key/name, content, optional `authoredOutputPath`, description, model, effort, permission/policy, argument hint, metadata, and existing kind-specific fields. The renderer result reserves `outputPath` for its default destination.

```nix
renderArtifact normalizedArtifact -> {
  outputPath = "relative/path.md";
  frontmatter = { ... };
  frontmatterOrder = [ ... ];
}
```

Shared code validates the result, resolves `authoredOutputPath` over the renderer's `outputPath`, converts ordered frontmatter attributes into the existing YAML renderer input, appends content, and carries logical kind metadata. Overrides apply to instructions, agents, commands, and skill entry files. Skill support files preserve their authored path relative to the skill and do not inherit the skill entry-file override. `frontmatterOrder` is mandatory for byte-stable existing output.

Validation requires exactly `outputPath`, `frontmatter`, and `frontmatterOrder`; a non-empty safe relative path; and every frontmatter key appearing exactly once in `frontmatterOrder`, including null-valued keys. Serialization omits values according to existing null/empty frontmatter rules. Existing YAML value validation remains centralized.

Instructions use explicit `main`, `rule`, and `regular` roles as the semantic source of truth. Rule source keys do not carry a `rules/` prefix; harness renderers derive the default standalone `rules/<key>.md` path from `role = "rule"`. Authored output paths continue to override renderer defaults.

Direct renderer defaults are `settings.harnesses.claude.rules.output = "files"` and `settings.harnesses.opencode.rules.output = "files"`. Explicit per-harness settings override defaults. Unknown harness setting keys and unknown output values fail with actionable errors.

`rules.output = "files"` emits each rule independently under the harness rule path derived from its unprefixed logical key. Authored output paths win over renderer defaults. `rules.output = "merge-main"` filters active rules, sorts them lexically by normalized key, merges them into the single active main instruction with fixed blank-line separators, omits standalone rule artifacts, and post-processes the merged artifact once. Empty profiles remain valid; active rules without exactly one main fail clearly.

The phase uses synthetic scopes for `merge-main`; Pi-specific rendering and registration remain in Phase 03 so this phase ends with all repository checks green.

## Questions & Investigations

* [x] Q: Should aggregation also retain standalone rule files?
  * Answer: No. Main-file output and standalone-file output are mutually exclusive.
* [x] Q: Should plugin adapters install Pi packages?
  * Answer: No. They describe generated instruction contracts only.
* [x] Q: Should all harness/plugin frontmatter renderers implement a common normalized-artifact contract?
  * Hypothesis: Existing Claude Code and OpenCode frontmatter functions are already close to this shape. Generalizing the contract may reduce Pi-specific logic and make future adapters data/functions rather than shared-renderer changes.
  * Risk: A broad migration could increase scope without helping path selection, body transformation, capability prose, or validation. Confirm the smallest useful boundary before implementation.
  * Investigation result: Use a small artifact-rendering contract rather than a universal plugin framework. Each renderer receives normalized artifact attributes and returns `outputPath`, `frontmatter`, and `frontmatterOrder`.
  * Constraint: Explicit `frontmatterOrder` is required because Nix attrset iteration is lexical and existing Claude Code/OpenCode field ordering must remain byte-for-byte stable.
  * Boundary: Generic code owns normalization, serialization, authored path precedence, logical kinds, collisions, and rule merging. Harness/agent adapters own field names, ordering, validation, translations, and default paths. Authored workflow prose and capability tool names remain outside this contract.
  * Decision: Yes. Use the three-field renderer result above and keep capability adapters separate.

## Tasks

- [x] Capture complete Claude Code and OpenCode output baselines (Agent: mid-dev) (R1.B)
  - Add full-tree path/content manifests or hashes before changing the renderer.
  - AC: Tests detect any added, removed, renamed, reordered, or content-changed existing artifact.
- [x] Implement and validate the normalized artifact contract (Agent: senior-dev) (R1.A)
  - Add normalized records, the three-field renderer result, ordered-attrset serialization, safe path validation, and authored path precedence.
  - AC: Exact tests cover valid rendering, field order, null omission, malformed adapter output, unsafe paths, and output-path overrides.
- [x] Migrate Claude Code and OpenCode renderers (Agent: senior-dev) (R1.A, R1.B)
  - Implement the common artifact contract without changing public output.
  - AC: Complete baseline tests remain byte-for-byte green.
- [x] Carry logical artifact kinds through package output (Agent: senior-dev) (R1.C)
  - Stop inferring BOM categories and collision meaning from path prefixes.
  - AC: Commands, skills, agents, instructions, and support files retain correct categories regardless of renderer-selected paths.
- [x] Implement explicit instruction roles and rule output (Agent: senior-dev) (R1.D)
  - Use exact `main` and `rule` annotations as semantic behavior, remove `rules/` prefixes from rule source keys, default other instructions to `regular`, and implement validated `files`/`merge-main` behavior using synthetic scopes.
  - AC: Tests cover filtering, lexical normalized-key order, separators, omission, path precedence in `files`, empty profiles, missing/multiple mains, collisions, and post-processing exactly once.
- [x] Run focused and full regression checks (Agent: mid-dev) (R1)
  - AC: Framework checks pass and complete Claude Code/OpenCode trees remain unchanged.
- [x] Normalize instruction declaration field ordering after user review (Agent: mid-dev) (R1.D)
  - Place activation selectors (`when`, `harnesses`) before semantic `role`, followed by output/frontmatter fields and content.
  - AC: All affected declarations follow the same order and renderer tests remain green.

## Files

- **framework/artifact.nix**: New normalized artifact-result validation and ordered serialization boundary.
- **framework/builders.nix**: Build normalized artifact declarations rather than invoking harness frontmatter directly.
- **framework/scope.nix**: Roles, renderer invocation, destinations, logical kinds, and rule merging.
- **framework/output.nix**: Package tree and BOM classification.
- **framework/harnesses/claude.nix**: Common-contract migration with unchanged output.
- **framework/harnesses/opencode.nix**: Common-contract migration with unchanged output.
- **instructions/00-main/main.nix**: Explicit main-instruction role.
- **instructions/**: Explicit role annotations and unprefixed logical keys for all current authored rule sources; other instructions default to regular.
- **framework/tests/artifact-rendering.nix**: New common-contract tests.
- **framework/tests/rule-output.nix**: New rule-output tests.
- **framework/tests/**: Existing renderer, source, collision, BOM, and golden regression tests.
- **framework/checks.nix**: Rendered-package path/content assertions.
