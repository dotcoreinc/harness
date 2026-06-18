# Nixantic standalone

Nixantic renders authored instruction fragments into Claude Code and OpenCode config trees. This repo contains the reusable renderer, a `lib.evalModules` core module, a thin Home Manager adapter, and one built-in instruction profile under `instructions/`.

The stable surface is the module surface:

- `nixanticModules.default` / `nixanticModules.core`: standalone core module
- `homeManagerModules.default` / `homeModules.default`: Home Manager adapter
- `flakeModules.default`: flake-parts exposure module
- `packages.<system>.builtin`: rendered built-in instruction profile
- `packages.<system>.claude`: wrapper that sets `CLAUDE_CONFIG_DIR`
- `packages.<system>.opencode`: wrapper that sets `OPENCODE_CONFIG_DIR`

The canonical rendered outputs live under `config.nixantic.instructions.*`.

## Flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixantic.url = "github:OWNER/nixantic-standalone";
    nixantic.inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Use a local path during development:

```nix
{
  inputs.nixantic.url = "path:/home/me/src/nixantic-standalone";
}
```

## Standalone core module

Use the core module when you want rendered packages without Home Manager. Pass `pkgs` through `specialArgs`; the module imports the renderer with that package set.

```nix
{ inputs, nixpkgs, ... }:
let
  system = "x86_64-linux";
  pkgs = import nixpkgs { inherit system; };
  evaluated = nixpkgs.lib.evalModules {
    specialArgs = { inherit pkgs; };
    modules = [
      inputs.nixantic.nixanticModules.core
      {
        nixantic.instructions.profile = "none";
        nixantic.sources.example.instructions.main =
          { scope }:
          {
            heading = "Project instructions";
            content = "Use the project conventions.";
            outputPath = scope.forHarness {
              claude = "CLAUDE.md";
              opencode = "AGENTS.md";
            };
          };
      }
    ];
  };
in
evaluated.config.nixantic.instructions.package
```

Leave `nixantic.instructions.profile` at its default (`"builtin"`) to render the shipped corpus before your extra sources. Set it to `"none"` for a blank profile.

## Home Manager adapter

The Home Manager module imports the core module and only adds HM install behavior. Shared options stay in the core module.

```nix
{ inputs, ... }:
{
  imports = [ inputs.nixantic.homeManagerModules.default ];

  nixantic.instructions.install.files = [
    {
      harness = "claude";
      source = "CLAUDE.md";
      target = ".claude/CLAUDE.md";
    }
    {
      harness = "opencode";
      source = "AGENTS.md";
      target = ".config/opencode/AGENTS.md";
    }
  ];
}
```

Set `nixantic.instructions.wrappers.install = true;` if you want Home Manager to install the generic wrapper packages. Keep personal wrappers, sandboxing, shell aliases, and local runtime glue in your own Home Manager modules.

## flake-parts exposure

Import the flake-parts module when a flake should publish a rendered package and renderer check.

```nix
{
  imports = [ inputs.nixantic.flakeModules.default ];

  perSystem = { ... }: {
    nixantic.enable = true;
    nixantic.packageName = "my-instructions";
    nixantic.checkName = "my-instructions";
    nixantic.modules = [
      {
        nixantic.instructions.profile = "builtin";
      }
    ];
  };
}
```

This module is only an exposure layer. It evaluates the core module and publishes `packages.<name>` and `checks.<name>`.

## Shipped corpus and wrappers

Build the shipped profile:

```bash
nix build .#builtin
```

The result contains both harness trees:

```text
claude/CLAUDE.md
claude/commands/...
claude/agents/...
opencode/AGENTS.md
opencode/commands/...
opencode/agents/...
```

Run wrappers from the flake if `claude` or `opencode` is on `PATH`:

```bash
nix run .#claude -- --help
nix run .#opencode -- --help
```

The wrappers do one thing: set the harness config directory to the generated tree, then `exec` the configured executable.

| Package | Binary | Env var | Config dir |
| --- | --- | --- | --- |
| `packages.<system>.claude` | `nixantic-claude` | `CLAUDE_CONFIG_DIR` | `<package>/claude` |
| `packages.<system>.opencode` | `nixantic-opencode` | `OPENCODE_CONFIG_DIR` | `<package>/opencode` |

Override the executable or wrapper name through the core module:

```nix
{
  nixantic.instructions.wrappers.claude.executable = "/path/to/claude";
  nixantic.instructions.wrappers.opencode.executable = "/path/to/opencode";
}
```

## Direct renderer use

Direct renderer imports are useful for renderer development and low-level tests. Prefer the core module for consumers because it owns the supported option surface.

```nix
let
  instructions = import "${inputs.nixantic}/framework" {
    inherit pkgs lib;
    postProcess = true;
    sourceRoots = [ ./instructions ];
    sources = { };
    settings.versionControl.mode = "jj";
  };
in
instructions.package
```

## Authoring source trees

A source root is a fragment-only tree. Every non-reserved `.nix` file under it is imported and must return an attrset with `nixantic.sources`.

```nix
{
  nixantic.sources.example.commands.hello = {
    description = "Say hello";
    content = "Hello from a generated command.";
  };
}
```

Reserved paths are skipped during discovery:

- `_support/` for helper code
- `tests/` for source-tree tests and fixtures

Duplicate artifact keys fail evaluation. Duplicate Home Manager install targets also fail evaluation.

## Harness layout

The renderer currently ships two harnesses:

- `claude`, output directory `claude/`
- `opencode`, output directory `opencode/`

Both harnesses receive the same normalized source declarations. Harness files decide frontmatter fields and output names, for example `CLAUDE.md` versus `AGENTS.md`.

## Checks

Run the repo checks with:

```bash
nix flake check --show-trace
```

The check set covers renderer behavior, core module evaluation without Home Manager, Home Manager install mapping, built-in corpus rendering, wrapper env vars, and README example contracts.
