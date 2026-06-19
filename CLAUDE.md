# Harness contributor guide

Use this file when you work on this repository.

This repo has two equal parts: the standalone Nixantic Nix-driven renderer/framework, and built-in instructions with workflows, commands, instructions, skills, agents, and related source content.

Treat both parts as first-class. The repo builds and validates them together, then produces generated config trees for Claude Code and OpenCode from authored Nix fragments.

## Work on the source, not generated output

- Edit source under `framework/`, `modules/`, `checks/`, `instructions/`, and root docs.
- Do not hand-edit generated downstream harness output. Rendered files belong to build results such as `result/claude/...` and `result/opencode/...`.
- Keep README human-focused. Use this file for contributor and agent guidance.

## Know the repo layout before editing

- `flake.nix`: public flake surface, exported packages, modules, and checks
- `modules/core.nix`: main module API, renderer wiring, wrapper packages, instructions checks
- `modules/home-manager.nix`: Home Manager install adapter
- `modules/flake-parts.nix`: flake-parts exposure layer
- `framework/`: renderer implementation, harness output logic, post-processing, tests
- `instructions/`: built-in authored instructions
- `checks/default.nix`: repo validation checks, including README example coverage
- `source-sets.nix`: source-root discovery and duplicate detection

## Follow these repo rules

- Treat `instructions/` as source input, not generated output.
- Keep the stable consumer surface at the module API exposed from the flake.
- When you change README examples or exported behavior, verify them against `flake.nix`, `modules/`, and `checks/default.nix`.
- Prefer changes in source fragments and renderer code over edits to rendered artifacts.
- Keep this file short. Do not restate code or README content unless it changes agent behavior.

## Watch the source-tree contract

- `_support/` and `tests/` under source roots are reserved and skipped by fragment discovery.
- Discovered source fragments must export `nixantic.sources`.
- Harness-specific file layout and naming live under `framework/harnesses/`.

## Verify before you finish

- Run `nix flake check --show-trace` for final verification.
- Use `nix build .#builtin`, `nix build .#claude`, and `nix build .#opencode` for focused instructions and wrapper checks while iterating.
