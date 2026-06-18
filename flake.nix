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

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          core = (evalCore pkgs [ ]).config.nixantic.instructions;
        in
        {
          default = core.package;
          builtin = core.package;
          claude = core.wrappers.packages.claude;
          opencode = core.wrappers.packages.opencode;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          core = (evalCore pkgs [ ]).config.nixantic.instructions;
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
          claude-wrapper = core.wrapperChecks.claude;
          opencode-wrapper = core.wrapperChecks.opencode;
        }
      );
    };
}
