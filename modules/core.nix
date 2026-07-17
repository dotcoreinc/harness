{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixantic;
  instructionCfg = cfg.instructions;

  sourceType = lib.types.lazyAttrsOf lib.types.raw;
  kinds = [
    "blocks"
    "agents"
    "commands"
    "skills"
    "instructions"
  ];
  sourceOwnerType = lib.types.submodule {
    options = lib.genAttrs kinds (
      kind:
      lib.mkOption {
        type = sourceType;
        default = { };
        description = "Raw nixantic ${kind} sources for this source owner.";
      }
    );
  };

  builtinProfileRoot = ../instructions;
  profileRoots = {
    builtin = [ builtinProfileRoot ];
    none = [ ];
  };
  effectiveSourceRoots = profileRoots.${instructionCfg.profile} ++ cfg.sourceRoots;

  rendered = import ../framework {
    inherit pkgs lib;
    postProcess = instructionCfg.postProcess;
    bom = instructionCfg.bom;
    sourceRoots = effectiveSourceRoots;
    sources = cfg.sources;
    settings = {
      versionControl = cfg.versionControl;
    };
  };

  mkWrapper =
    {
      name,
      executable,
      envVar,
      configDir,
    }:
    pkgs.writeShellScriptBin name ''
      export ${envVar}=${lib.escapeShellArg configDir}
      exec ${executable} "$@"
    '';

  wrapperPackages = {
    claude = mkWrapper {
      inherit (instructionCfg.wrappers.claude) name executable;
      envVar = "CLAUDE_CONFIG_DIR";
      configDir = "${rendered.package}/claude";
    };
    opencode = mkWrapper {
      inherit (instructionCfg.wrappers.opencode) name executable;
      envVar = "OPENCODE_CONFIG_DIR";
      configDir = "${rendered.package}/opencode";
    };
  };

  toolPackages = {
    "agentic-proj-docs" = import ../tools/agentic-proj-docs.nix { inherit pkgs; };
    "agentic-proj-create-adhoc" = import ../tools/agentic-proj-create-adhoc.nix { inherit pkgs; };
  };

  versionControlMarkers =
    if cfg.versionControl.mode == "git" then
      {
        expected = "git branch --show-current";
        unexpected = "jj-current-branch";
      }
    else
      {
        expected = "jj-current-branch";
        unexpected = "git branch --show-current";
      };

  corpusCheck = pkgs.runCommand "nixantic-builtin-corpus-check" { } ''
    test -f ${rendered.package}/claude/CLAUDE.md
    test -f ${rendered.package}/opencode/AGENTS.md
    test -d ${rendered.package}/claude/commands
    test -d ${rendered.package}/opencode/commands
    grep -Fx '7. 🔳 Run the `proj-save` command to update project and phase docs' ${rendered.package}/claude/commands/implement.md
    grep -Fx '7. 🔳 Run the `proj-save` skill to update project and phase docs' ${rendered.package}/opencode/commands/implement.md
    grep -F '# Main instructions' ${rendered.package}/claude/CLAUDE.md
    grep -F '# Main instructions' ${rendered.package}/opencode/AGENTS.md
    grep -F 'todowrite' ${rendered.package}/opencode/AGENTS.md
    test -f ${rendered.package}/claude/agents/mid-dev.md
    test -f ${rendered.package}/opencode/agents/mid-dev.md
    test -f ${rendered.package}/claude/agents/senior-dev.md
    test -f ${rendered.package}/opencode/agents/senior-dev.md
    grep -Fx 'model: "sonnet"' ${rendered.package}/claude/agents/mid-dev.md
    grep -Fx 'model: "sonnet"' ${rendered.package}/claude/agents/senior-dev.md
    grep -Fx 'model: "openai/gpt-5.6-luna"' ${rendered.package}/opencode/agents/mid-dev.md
    grep -Fx 'reasoningEffort: "xhigh"' ${rendered.package}/opencode/agents/mid-dev.md
    grep -Fx 'model: "openai/gpt-5.6-terra"' ${rendered.package}/opencode/agents/senior-dev.md
    grep -Fx 'reasoningEffort: "high"' ${rendered.package}/opencode/agents/senior-dev.md
    if grep -Eq '^effort:' ${rendered.package}/claude/agents/mid-dev.md; then
      echo 'unexpected effort field in rendered Claude mid-dev agent' >&2
      exit 1
    fi
    if grep -Eq '^effort:' ${rendered.package}/claude/agents/senior-dev.md; then
      echo 'unexpected effort field in rendered Claude senior-dev agent' >&2
      exit 1
    fi
    grep -F '${versionControlMarkers.expected}' ${rendered.package}/claude/rules/version-control.md
    grep -F '${versionControlMarkers.expected}' ${rendered.package}/opencode/rules/version-control.md
    if grep -F '${versionControlMarkers.unexpected}' ${rendered.package}/claude/rules/version-control.md; then
      echo 'unexpected version-control content in rendered package' >&2
      exit 1
    fi
    touch $out
  '';

  wrapperChecks = {
    claude = pkgs.runCommand "nixantic-claude-wrapper-check" { } ''
      grep -F 'CLAUDE_CONFIG_DIR' ${wrapperPackages.claude}/bin/${instructionCfg.wrappers.claude.name}
      grep -F '${rendered.package}/claude' ${wrapperPackages.claude}/bin/${instructionCfg.wrappers.claude.name}
      grep -F '${versionControlMarkers.expected}' ${rendered.package}/claude/rules/version-control.md
      touch $out
    '';
    opencode = pkgs.runCommand "nixantic-opencode-wrapper-check" { } ''
      grep -F 'OPENCODE_CONFIG_DIR' ${wrapperPackages.opencode}/bin/${instructionCfg.wrappers.opencode.name}
      grep -F '${rendered.package}/opencode' ${wrapperPackages.opencode}/bin/${instructionCfg.wrappers.opencode.name}
      grep -F '${versionControlMarkers.expected}' ${rendered.package}/opencode/rules/version-control.md
      touch $out
    '';
  };
in
{
  options.nixantic = {
    sourceRoots = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Source-tree roots to discover nixantic source fragments from.";
    };

    sources = lib.mkOption {
      type = lib.types.lazyAttrsOf sourceOwnerType;
      default = { };
      description = "Feature/domain-indexed low-level nixantic sources.";
    };

    versionControl.mode = lib.mkOption {
      type = lib.types.enum [
        "jj"
        "git"
      ];
      default = "jj";
      description = "Version-control mode used when rendering VCS-aware nixantic instruction sources.";
    };

    instructions = {
      profile = lib.mkOption {
        type = lib.types.enum [
          "builtin"
          "none"
        ];
        default = "builtin";
        description = "Named built-in source profile to render before explicit source roots and sources.";
      };

      postProcess = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Apply markdown post-processing to generated instruction files.";
      };

      bom = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = { };
        description = "BOM renderer overrides, including encoding metadata.";
      };

      rendered = lib.mkOption {
        type = lib.types.raw;
        readOnly = true;
        description = "Rendered nixantic package, harness outputs, checks, and block scopes.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "Rendered nixantic instruction package.";
      };

      check = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "Renderer validation check for the configured instruction framework.";
      };

      corpusCheck = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "Validation check for the built-in instruction corpus.";
      };

      wrappers = {
        claude = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "nixantic-claude";
          };
          executable = lib.mkOption {
            type = lib.types.str;
            default = "claude";
          };
        };
        opencode = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "nixantic-opencode";
          };
          executable = lib.mkOption {
            type = lib.types.str;
            default = "opencode";
          };
        };
        packages = lib.mkOption {
          type = lib.types.attrsOf lib.types.package;
          readOnly = true;
          description = "Generic config-dir wrapper packages keyed by harness.";
        };
      };

      wrapperChecks = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        readOnly = true;
        description = "Validation checks for generated wrapper packages.";
      };

      tools = {
        packages = lib.mkOption {
          type = lib.types.attrsOf lib.types.package;
          readOnly = true;
          description = "Runtime tools required by rendered instruction protocols.";
        };
      };
    };
  };

  config.nixantic.instructions = {
    inherit rendered corpusCheck wrapperChecks;
    package = rendered.package;
    check = rendered.check;
    wrappers.packages = wrapperPackages;
    tools.packages = toolPackages;
  };
}
