# justfile for the Nixantic harness.
# Run from inside `nix develop` (or a direnv shell) so `nix` is on PATH.

# Default recipe — render the builtin harness corpus.
build:
    nix build .#builtin

# Run the repository's Nix flake checks.
check:
    nix flake check --show-trace

# Build the Claude Code launcher.
claude:
    nix build .#claude

# Build the OpenCode launcher.
opencode:
    nix build .#opencode

# Format flake.nix with nixfmt (from the dev shell).
# Repo-wide formatting can be added later via pkgs.nixfmt-tree.
fmt:
    nixfmt flake.nix
