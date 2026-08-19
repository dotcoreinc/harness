# Pi target and corpus compatibility

## Context

Implement Pi using the shared artifact contract, add independent capability adapters, and adapt the built-in corpus so Pi output refers only to declared tools and behaviors. Register Pi only after focused direct rendering and corpus compatibility pass.

## Requirements

* R2.A: Pi sub-agent instructions target the configured agent adapter, defaulting to tintinweb.
* R2.B: Pi task instructions target the configured task adapter, defaulting to tintinweb tasks.
* R2.C: Pi question instructions target the configured question adapter, defaulting to pi-vault-questionnaire.
* R2.D: Pi tool names, permissions, model controls, and command syntax are valid for the declared adapters.
* R1.F: Pi renders active context to `AGENTS.md`, commands under `prompts/`, skills under `skills/`, and tintinweb agents under a neutral `agents/` source directory.

## Design

Resolve raw adapter selections once through Pi adapter registries into normalized harness capabilities. Authored sources use capability fields/helpers for task creation, task result retrieval, questions, agent launch/result/steer, skill invocation, and tool restrictions; they do not branch repeatedly on plugin package names. `forHarness` remains appropriate only for genuinely different prose or artifacts. Pi variants must preserve safety constraints explicitly; an unsupported restriction is an error or deliberate exclusion, not silently dropped metadata.

Pi-native instruction, command, and skill renderers implement the shared artifact contract. The selected agent adapter contributes both agent capabilities and a `renderAgentArtifact` function using that same contract. Task and question adapters expose capabilities/schema only and never render files.

Expected Pi tree:

```text
pi/
├── AGENTS.md
├── prompts/<command>.md
├── skills/<skill>/SKILL.md
├── skills/<skill>/<support-files>
└── agents/<agent>.md
```

The initial adapter mapping is:

```text
sub-agent launch/result/steer -> tintinweb Agent/get_subagent_result/steer_subagent
task creation and tracking    -> tintinweb pi-tasks tools, including TaskCreate
interactive questions        -> pi-vault questionnaire schema
skill invocation              -> Pi skill discovery/invocation wording
```

Adapter registries fail evaluation on unknown selections. A selected adapter exposes its tool names, schema/version metadata, supported policy fields, and prose/render helpers. A missing capability required by an authored source fails evaluation; fallback adapters are future work.

Authored sources consume this normalized shape:

```nix
capabilities = {
  agents = {
    launch = "Agent";
    result = "get_subagent_result";
    steer = "steer_subagent";
  };
  tasks = {
    create = "TaskCreate";
    list = "TaskList";
    get = "TaskGet";
    update = "TaskUpdate";
    output = "TaskOutput";
    stop = "TaskStop";
    execute = "TaskExecute";
  };
  questions = {
    ask = "questionnaire";
    interactiveOnly = true;
  };
  skills.invocation = "pi-native";
};
```

Initial tested contracts:

* tintinweb sub-agents v0.17.1: `Agent`, `get_subagent_result`, `steer_subagent`; explicit allow/deny tools, extension/skill policy, nested delegation, `isolated`, `isolation`, `persist_session`, model, and thinking mappings. Matching filename/frontmatter identity is a Nixantic convention, not a plugin requirement.
* tintinweb tasks v0.8.0: `TaskCreate`, `TaskList`, `TaskGet`, `TaskUpdate`, `TaskOutput`, `TaskStop`, and `TaskExecute`. Completion is `TaskUpdate { status = "completed"; }`; dependencies use `addBlocks`/`addBlockedBy`. `TaskExecute` requires tintinweb sub-agents and an `agentType`.
* pi-vault questionnaire v0.2.1: tool `questionnaire` with 1-10 questions; each has `id`, `header`, `prompt`, 2-12 `{ label, value?, description? }` options, and optional `multiSelect`, `recommendation`, `allowOther`, and `allowChat`. Recommendations reference option values. Interactive mode is required; rendered instructions must use normal chat in non-interactive mode rather than claiming automatic fallback.

## Questions & Investigations

* [x] Q: Does tintinweb sub-agents also provide task management?
  * Result: No. Task support is a separate adapter targeting `@tintinweb/pi-tasks`.
* [x] Q: Does Pi core provide `AskUserQuestion`?
  * Result: No. The selected default question adapter is pi-vault-questionnaire; a future plain-chat adapter remains possible.

## Tasks

- [x] Add Pi settings defaults and adapter registries (Agent: senior-dev) (R1, R2)
  - Add direct `settings.harnesses.pi` defaults: `rules.output = "merge-main"`, agents/tasks=`tintinweb`, and questions=`pi-vault-questionnaire`.
  - AC: Independent selections resolve to normalized capabilities; unknown values, unsupported policies, and incompatible combinations fail clearly without affecting other harnesses.
- [x] Implement Pi-native artifact renderers (Agent: senior-dev) (R1)
  - Render `AGENTS.md`, prompts, Agent Skills, and support files through the common contract.
  - AC: Exact tests cover paths, ordered supported frontmatter, Pi prompt arguments, skill metadata subset, authored path precedence, and logical BOM kinds.
- [x] Implement the tintinweb agent-file adapter (Agent: senior-dev) (R1, R2.A)
  - Compose tintinweb capabilities with a v0.17.1-compatible common-contract agent renderer.
  - AC: Exact tests cover path, snake_case fields, tool policies, skills/extensions, nested delegation, `isolated`, `isolation`, `persist_session`, model, and thinking.
  - AC: Unsupported restrictions fail rather than silently inheriting Claude/OpenCode semantics.
- [x] Inventory every harness-specific assumption in the built-in corpus (Agent: senior-dev) (R2)
  - Classify explicit harness mappings, tool interpolations, hard-coded tool names, model values, permission restrictions, command arguments, and skill invocation wording.
  - AC: Every affected source has a recorded action: shared unchanged, Pi mapping, adapter mapping, Pi exclusion, or deliberate unsupported error.
  - AC: Existing `forHarness` declarations no longer fail merely because Pi is registered.
- [x] Add Pi-safe main and rule variants (Agent: senior-dev) (R2.D)
  - Adapt global instructions and aggregated rules to Pi's available configured capabilities.
  - AC: Generated Pi `AGENTS.md` contains no Claude/OpenCode-only tool names unless an adapter explicitly provides the same contract.
  - AC: Pre-flight, task management, context, planning, review, development, and version-control rules retain their intended constraints.
- [x] Adapt sub-agent definitions and orchestration workflows (Agent: senior-dev) (R2.A, R2.D)
  - Add explicit tintinweb agent declarations and map launch/result/steering prose to its tools.
  - AC: Pi agent definitions are discoverable at the tintinweb adapter path and references use matching identities.
  - AC: Delegation restrictions map explicitly to tintinweb denied tools and nested-agent policy.
  - AC: `TaskOutput` and other non-Pi orchestration names do not leak into Pi output.
- [x] Adapt task-management workflows (Agent: senior-dev) (R2.B)
  - Route generic task capability references to the tintinweb task adapter and add adapter-specific prose only where semantics differ.
  - AC: Pi task instructions consistently reference tools supplied by the selected task adapter.
  - AC: Sub-agent and task adapters remain independent; selecting one never implies the other.
- [x] Adapt user-question workflows (Agent: senior-dev) (R2.C)
  - Render questionnaire-compatible instructions/schema where the corpus currently requires `AskUserQuestion`.
  - AC: Single and multi-question flows preserve recommendation, custom-answer, and stop-for-answer behavior.
  - AC: No raw `AskUserQuestion` reference remains in Pi output unless a future adapter explicitly declares that tool.
  - AC: Questionnaire rendering enforces IDs, headers, prompts, option counts/values, recommendation values, multi-select, custom answers, and chat choice; non-interactive prose uses normal chat and stop behavior.
- [x] Adapt Pi commands and skills (Agent: mid-dev) (R2.D)
  - Update prompt argument syntax, skill invocation wording, and mem-writing guidance for Pi-native prompts and Agent Skills.
  - AC: Rendered prompt templates use Pi-supported arguments and frontmatter.
  - AC: Rendered skill guidance recognizes Pi's native `AGENTS.md`, `SKILL.md`, and prompt-template concepts.
- [x] Add built-in corpus compatibility checks (Agent: mid-dev) (R2)
  - Render the full Pi tree directly before global registration, assert representative exact content, and scan output for unavailable tool names or inert rule paths.
  - AC: Checks cover agent, task, question, command, skill, and aggregated-rule seams.
  - AC: Focused tests render the full Pi tree and built-in corpus while the global registry still contains only Claude Code and OpenCode.
  - AC: Claude Code and OpenCode corpus checks continue to pass unchanged.
- [x] Register Pi after the built-in corpus is compatible (Agent: senior-dev) (R1, R2)
  - Add Pi to the global harness registry only after source routing and required adapter capabilities are valid.
  - AC: Registration does not create an intermediate failing built-in render.
  - AC: The full built-in package renders all three harnesses in one evaluation.
- [x] Address final Pi capability and corpus review findings (Agent: senior-dev) (R1, R2)
  - Replace leaked `Skill` and unsupported fork-context claims in Pi prompts, make interactive-question behavior safe in non-interactive sessions, and move all adapter-specific task/question names and schema prose behind capability adapters.
  - AC: Pi output contains no nonexistent `Skill` tool reference or false fork-isolation claim.
  - AC: Interactive sessions use the selected question adapter; non-interactive sessions ask in normal chat and stop.
  - AC: Authored workflow prose consumes adapter-provided names/schema guidance rather than hard-coded tintinweb or pi-vault contracts.
  - AC: Focused leakage/configuration tests and the full flake check pass.

## Files

- **instructions/00-main/**: Main context, pre-flight, task management, questions, and aggregated rules.
- **instructions/01-projects/**: Project workflows and interactive planning questions.
- **instructions/02-orchestration/**: Agent delegation policy and tool references.
- **instructions/03-context/**: Context planning and question workflows.
- **instructions/04-dev/**: Implementation commands and task creation.
- **instructions/05-mem/**: Pi-aware instruction-authoring skill and question workflows.
- **instructions/06-reviewing/**: Reviewer agents, launch/result tools, and task use.
- **instructions/07-version-control/**: Agent definitions and skill invocation.
- **instructions/08-writing/**: Cross-harness skill content audit.
- **instructions/09-harnesses/pi/**: Pi-specific rules only where shared capability rendering is insufficient.
- **framework/default.nix**: Effective Pi settings.
- **framework/harnesses/default.nix**: Final Pi registration.
- **framework/harnesses/pi.nix**: Pi-native artifact rendering and adapter composition.
- **framework/harnesses/pi/capabilities.nix**: Independent capability registries.
- **framework/harnesses/pi/tintinweb.nix**: Tintinweb agent-file renderer and policy validation.
- **framework/tests/pi.nix**: Pi paths/frontmatter and direct-render tests.
- **framework/tests/capabilities.nix**: Adapter defaults, overrides, validation, and schemas.
- **checks/default.nix**: Built-in routing and corpus assertions.
