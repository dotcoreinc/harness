{
  description = "Standalone Nixantic instruction framework and corpus";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      evalCore =
        pkgs: modules:
        nixpkgs.lib.evalModules {
          specialArgs = { inherit pkgs; };
          modules = [ self.nixanticModules.default ] ++ modules;
        };
    in
    {
      nixanticModules = {
        default = ./modules/core.nix;
        core = ./modules/core.nix;
      };

      homeManagerModules = {
        default = ./modules/home-manager.nix;
        nixantic = ./modules/home-manager.nix;
      };
      homeModules = self.homeManagerModules;

      flakeModules = {
        default = ./modules/flake-parts.nix;
        nixantic = ./modules/flake-parts.nix;
      };

      # Reproducible dev shell loaded via direnv (`use flake`). Mirrors the
      # ccmon flake: a plain `mkShell` per system. `flake-parts` is an unused
      # input here, so this is a plain output, not a flake-parts module.
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.just
              pkgs.nixfmt
            ];
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          core = (evalCore pkgs [ ]).config.nixantic.instructions;
          gitCore =
            (evalCore pkgs [ { nixantic.versionControl.mode = "git"; } ]).config.nixantic.instructions;
        in
        {
          default = core.package;
          builtin = core.package;
          claude = core.wrappers.packages.claude;
          opencode = core.wrappers.packages.opencode;
          agentic-proj-docs = core.tools.packages.agentic-proj-docs;
          agentic-proj-create-adhoc = core.tools.packages.agentic-proj-create-adhoc;
          builtin-git = gitCore.package;
          claude-git = gitCore.wrappers.packages.claude;
          opencode-git = gitCore.wrappers.packages.opencode;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          core = (evalCore pkgs [ ]).config.nixantic.instructions;
          gitCore =
            (evalCore pkgs [ { nixantic.versionControl.mode = "git"; } ]).config.nixantic.instructions;
          validation = import ./checks {
            inherit pkgs;
            lib = nixpkgs.lib;
            coreModule = self.nixanticModules.core;
            homeManagerModule = self.homeManagerModules.default;
          };
        in
        validation
        // {
          framework = core.check;
          builtin-corpus = core.corpusCheck;
          pi-builtin-corpus = validation.builtin-pi-corpus;
          claude-wrapper = core.wrapperChecks.claude;
          opencode-wrapper = core.wrapperChecks.opencode;
          git-builtin-corpus = gitCore.corpusCheck;
          git-claude-wrapper = gitCore.wrapperChecks.claude;
          git-opencode-wrapper = gitCore.wrapperChecks.opencode;
        }
      );
    };
}
