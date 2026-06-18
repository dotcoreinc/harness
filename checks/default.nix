{
  pkgs,
  lib,
  coreModule,
  homeManagerModule,
}:

let
  evalCore =
    modules:
    lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [ coreModule ] ++ modules;
    };

  homeManagerStub = { lib, ... }: {
    options.home = {
      file = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        default = { };
      };
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
      };
    };
  };

  evalHome =
    modules:
    lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        homeManagerStub
        homeManagerModule
      ]
      ++ modules;
    };

  coreEval = evalCore [ ];
  coreNoBuiltinEval = evalCore [ { nixantic.instructions.profile = "none"; } ];
  docsSources = {
    example = {
      instructions.main =
        { scope }:
        {
          heading = "Project instructions";
          content = "Use the project conventions.";
          outputPath = scope.forHarness {
            claude = "CLAUDE.md";
            opencode = "AGENTS.md";
          };
        };
      commands.hello = {
        description = "Say hello";
        content = "Hello from a generated command.";
      };
    };
  };
  docsCoreEval = evalCore [
    {
      nixantic.instructions.profile = "none";
      nixantic.sources = docsSources;
    }
  ];
  docsDirectRendered = import ../framework {
    inherit pkgs lib;
    postProcess = true;
    sourceRoots = [ ];
    sources = docsSources;
    settings.versionControl.mode = "jj";
  };
  homeEval = evalHome [
    {
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
      nixantic.instructions.wrappers.install = true;
    }
  ];
  duplicateHomeEval = builtins.tryEval (
    (evalHome [
      {
        nixantic.instructions.install.files = [
          {
            harness = "claude";
            source = "CLAUDE.md";
            target = "shared";
          }
          {
            harness = "opencode";
            source = "AGENTS.md";
            target = "shared";
          }
        ];
      }
    ]).config.home.file
  );
in
{
  core-module = pkgs.runCommand "nixantic-core-module-check" { } ''
    test -f ${coreEval.config.nixantic.instructions.package}/claude/CLAUDE.md
    test -f ${coreEval.config.nixantic.instructions.package}/opencode/AGENTS.md
    test -f ${coreEval.config.nixantic.instructions.package}/opencode/.gitignore
    test -f ${coreNoBuiltinEval.config.nixantic.instructions.package}/claude/BOM.md
    grep -F '# Main instructions' ${coreEval.config.nixantic.instructions.package}/claude/CLAUDE.md
    test ! -s ${coreEval.config.nixantic.instructions.package}/opencode/.gitignore
    touch $out
  '';

  home-manager-adapter = pkgs.runCommand "nixantic-home-manager-adapter-check" { } ''
    test ${
      lib.escapeShellArg homeEval.config.home.file.".claude/CLAUDE.md".source
    } = ${lib.escapeShellArg "${homeEval.config.nixantic.instructions.package}/claude/CLAUDE.md"}
    test ${toString (builtins.length homeEval.config.home.packages)} -eq 2
    ${
      if duplicateHomeEval.success then
        "echo duplicate target unexpectedly evaluated >&2; exit 1"
      else
        "true"
    }
    touch $out
  '';

  core-without-home-manager = pkgs.runCommand "nixantic-core-without-home-manager-check" { } ''
    test -f ${coreNoBuiltinEval.config.nixantic.instructions.package}/opencode/BOM.md
    touch $out
  '';

  readme-examples = pkgs.runCommand "nixantic-readme-examples-check" { } ''
    test -f ${docsCoreEval.config.nixantic.instructions.package}/claude/CLAUDE.md
    test -f ${docsCoreEval.config.nixantic.instructions.package}/opencode/AGENTS.md
    test -f ${docsCoreEval.config.nixantic.instructions.package}/opencode/.gitignore
    test -f ${docsCoreEval.config.nixantic.instructions.package}/claude/commands/hello.md
    test -f ${docsDirectRendered.package}/opencode/commands/hello.md

    grep -F 'Use the project conventions' ${docsCoreEval.config.nixantic.instructions.package}/claude/CLAUDE.md
    grep -F 'Hello from a generated command' ${docsDirectRendered.package}/claude/commands/hello.md

    test ${
      lib.escapeShellArg homeEval.config.home.file.".claude/CLAUDE.md".source
    } = ${lib.escapeShellArg "${homeEval.config.nixantic.instructions.package}/claude/CLAUDE.md"}
    grep -F 'CLAUDE_CONFIG_DIR' ${coreEval.config.nixantic.instructions.wrappers.packages.claude}/bin/nixantic-claude
    grep -F 'OPENCODE_CONFIG_DIR' ${coreEval.config.nixantic.instructions.wrappers.packages.opencode}/bin/nixantic-opencode
    touch $out
  '';
}
