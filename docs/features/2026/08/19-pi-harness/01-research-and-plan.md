# Research and plan

## Context

Determine how to add `pi` as a third supported instruction-rendering target without implementing it yet. The phase must establish Pi's current public contract, map it to this repository's renderer and Home Manager installation architecture, resolve all material scope and compatibility decisions with the user, and document tasks that another engineer can execute independently.

## Design

Research will cover two boundaries in parallel:

1. Pi's current user-facing configuration and extension model.
2. This repository's existing Claude Code/OpenCode harness abstraction, source discovery, module API, wrappers, checks, and tests.

The final plan will prefer shared renderer and module abstractions, with pi-specific behavior isolated under the existing harness-specific layout. Generated output remains build-owned and will not be hand-edited. Scope is instruction generation only: no Pi launcher, web interface, npm/plugin installation, mutable settings, credentials, models, themes, or runtime integration.

## Questions & Investigations

* [x] Q: Which pi release/documentation is authoritative for this integration?
  * Result: Official Pi documentation and source as of 2026-08-19 define the native contract. Adapter schemas are tested against tintinweb sub-agents v0.17.1, tintinweb tasks v0.8.0, and pi-vault questionnaire v0.2.1.
* [x] Q: What existing authored instruction artifacts should be emitted for Pi?
  * Result: Emit active context, Agent Skills-compatible skills, Pi prompt templates, and adapter-specific agent definitions. Blocks remain internal composition sources.
* [x] Q: How should repository concepts without a direct Pi equivalent be handled?
  * Result: Use independent capability adapters where an established extension contract is selected. Otherwise render explicit Pi-safe prose or exclude the artifact; never emit unavailable tools or invent equivalence.
* [x] Q: How should the configurable sub-agent backend adapter be represented without installing or invoking plugins?
  * Result: Expose independent `agents`, `tasks`, and `questions` adapter selections under Pi renderer configuration. Defaults target tintinweb sub-agents, tintinweb tasks, and pi-vault-questionnaire. Adapter selection affects generated instructions only.
* [x] Q: How should Pi consume standalone rule files?
  * Answer: Add a configurable Nixantic rule-aggregation mode and enable it by default for Pi.
  * Answer: Aggregation mode emits eligible rule content only in Pi's active main instruction file and omits standalone rule files. Claude Code and OpenCode retain their current separate-file mode.
  * Design consequence: Use `rules.output = "files" | "merge-main"`, rather than a boolean. Ordering, omission, harness defaults, and duplicate-content behavior require exact tests.
* [x] Q: What compatibility and version policy should the instruction output target?
  * Result: Target current official Pi instruction contracts and the documented schemas of selected adapters as of 2026-08-19. Tests pin expected schemas; Nixantic does not pin or install runtime packages.

### Research findings and decisions

* Pi's stable package mechanism supports extensions, skills, prompt templates, and themes, but Pi core has no shared sub-agent or task protocol.
* `@tintinweb/pi-subagents` is the first requested sub-agent backend, but its agent schema and discovery paths are package-specific. Other packages use incompatible schemas.
* The user clarified that this repository should generate instructions only. It must not install or activate Pi plugins, provide a launcher or web interface, generate mutable Pi settings, or otherwise interface with the Pi runtime.
* The repository's Home Manager adapter already selects rendered harness output through `nixantic.instructions.install.files.harness`, whose allowed values are derived from the renderer's `harnessNames`. Adding `pi` to the renderer registry therefore makes Pi output selectable for installation without adding Pi runtime behavior.
* The plan should define an explicit renderer-side agent backend adapter parameter. `tintinweb` is the first requested adapter; future adapters can target other plugins without changing shared semantic agent declarations. The selected adapter controls only the generated agent-file schema and path.
* Pi does not discover standalone rule files. The user selected a generic Nixantic rule-aggregation mode, enabled by default for Pi, so Pi-compatible rules become active content in its main instruction file.

### Repository architecture findings

* `framework/harnesses/default.nix` is the harness registry. Each harness supplies a name, output directory, and frontmatter renderers; adding `pi` creates a Pi scope and makes `pi` part of the derived `harnessNames`.
* `framework/harnesses/claude.nix` and `framework/harnesses/opencode.nix` define the existing harness-specific frontmatter contracts. A new `framework/harnesses/pi.nix` should follow this boundary rather than add Pi conditionals throughout shared builders.
* `framework/output.nix` writes each harness package under its output directory. Pi-specific logical destinations are needed because Pi consumes `AGENTS.md`, skills, prompts, and tintinweb agents. The final renderer keeps a neutral `agents/` source tree that consumers can map to Pi's global `~/.pi/agent/agents/` or project `.pi/agents/` location.
* `framework/builders.nix`, `framework/scope.nix`, and authored `forHarness` declarations contain the shared source semantics and harness-specific selection points. Existing explicit Claude/OpenCode mappings must be audited for Pi compatibility.
* `modules/core.nix` exposes the rendered package and checks. Its corpus checks currently hard-code Claude/OpenCode paths and must be generalized or extended for Pi. Pi wrapper generation is out of scope.
* `modules/home-manager.nix` already derives the install-file harness enum from rendered harness names. Its generic install-file mechanism should remain the way users select Pi files; no Pi-specific runtime installer is needed.
* `flake.nix` and `checks/default.nix` expose and validate the public package/check surface and contain hard-coded Claude/OpenCode loops that must be assessed for Pi.

### Pi and tintinweb findings

Authoritative research sources:

* [Pi usage](https://pi.dev/docs/latest/usage)
* [Pi skills](https://pi.dev/docs/latest/skills)
* [Pi prompt templates](https://pi.dev/docs/latest/prompt-templates)
* [Pi packages](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/packages.md)
* [Pi extension example](https://github.com/earendil-works/pi/tree/main/packages/coding-agent/examples/extensions/subagent)
* [tintinweb release v0.17.1](https://github.com/tintinweb/pi-subagents/releases/tag/v0.17.1)
* [tintinweb agent loader](https://raw.githubusercontent.com/tintinweb/pi-subagents/v0.17.1/src/custom-agents.ts)
* [tintinweb runtime](https://raw.githubusercontent.com/tintinweb/pi-subagents/v0.17.1/src/index.ts)

Pi-native mappings are plain context files, Agent Skills-compatible `SKILL.md` files, and Markdown prompt templates. Tintinweb discovers agent Markdown from `.pi/agents`, `.agents/agents`, or the global Pi agent directory and supports fields including `name`, `description`, `tools`, `disallowed_tools`, `model`, `thinking`, `skills`, extension policy, nested-agent policy, `persist_session`, `isolated`, and `isolation`. Claude/OpenCode permission and tool fields are not semantically identical and must be translated explicitly or omitted with a deliberate policy; they must not be silently represented as equivalent.

### Pi workflow capability findings

* Pi core has no model-facing sub-agent, task, todo, or interactive-question tools.
* `@tintinweb/pi-subagents` provides `Agent`, `get_subagent_result`, and `steer_subagent`, but does not provide task or question tools.
* `@tintinweb/pi-tasks` separately provides task tools including `TaskCreate`; it is a distinct instruction capability and must not be implied by selecting the sub-agent adapter.
* Pi's official question examples and community questionnaire extensions use different schemas. Without a selected question adapter, instructions can remain portable by asking in chat and stopping for the answer.
* The corpus contains direct assumptions about `${scope.harness.tools.taskCreate}`, `AskUserQuestion`, `TaskOutput`, and `Skill`. Pi rendering must resolve each assumption through an explicit capability adapter or Pi-specific prose; it must not emit unavailable tool names.
* Relevant research sources include [Pi extensions](https://pi.dev/docs/latest/extensions), [official question example](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/examples/extensions/question.ts), [official todo example](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/examples/extensions/todo.ts), [tintinweb pi-tasks](https://pi.dev/packages/@tintinweb/pi-tasks), and [Pi Vault questionnaire](https://pi.dev/packages/@pi-vault/pi-questionnaire).

## Tasks

- [x] Establish the repository and project context before research.
  - AC: Existing harness entry points, source roots, generated-output rules, checks, tests, and public module surfaces are identified in this document.
- [x] Research pi's current contract using authoritative web sources.
  - AC: Findings cite the relevant sources and record required file locations, schemas, discovery rules, CLI/launcher behavior, extension points, and version assumptions.
- [x] Compare pi requirements with the existing Claude Code and OpenCode implementation.
  - AC: Every likely integration point is mapped to a repository file or explicitly marked as a new file/abstraction.
- [x] Interview the user on unresolved product and compatibility decisions.
  - AC: Each question includes context, recommendation, answer, implications, and resulting requirement/design update.
- [x] Define implementation phases and delegated agent tasks.
  - AC: Tasks are ordered by dependency, name the appropriate agent type, include test work, and have verifiable acceptance criteria.
- [x] Report and verify the full-understanding checklist.
  - AC: Goal, patterns, use cases, files, symbols, test strategy, scope, acceptance criteria, and web research are all explicitly recorded; remaining gaps are either resolved or surfaced.
- [x] Write the final implementation-ready plan and update project navigation.
  - AC: Project and phase docs contain current requirements, decisions, questions, phase summaries, files, and task breakdown; no implementation is performed.

## Files

- **flake.nix**: Public exports and package/check surface to inspect.
- **modules/core.nix**: Main module API, renderer wiring, wrappers, and instruction checks to inspect.
- **modules/home-manager.nix**: Home Manager installation adapter to inspect.
- **modules/flake-parts.nix**: Flake-parts exposure layer to inspect.
- **framework/**: Renderer implementation, harness output logic, post-processing, and tests to inspect.
- **framework/harnesses/**: Harness-specific source layout and conventions to inspect.
- **instructions/**: Built-in authored source to inspect for cross-harness assumptions.
- **checks/default.nix**: Repository checks and README example validation to inspect.
- **source-sets.nix**: Source discovery and duplicate detection to inspect.
