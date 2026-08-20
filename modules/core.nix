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
  rulesOutputType = lib.types.enum [
    "files"
    "merge-main"
  ];
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
      harnesses = instructionCfg.harnesses;
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

  corpusCheck = pkgs.runCommand "nixantic-builtin-corpus-check" { } ''
    test -f ${rendered.package}/claude/CLAUDE.md
    test -f ${rendered.package}/opencode/AGENTS.md
    test -f ${rendered.package}/pi/AGENTS.md
    test -d ${rendered.package}/claude/commands
    test -d ${rendered.package}/opencode/commands
    test -d ${rendered.package}/pi/prompts
    test -d ${rendered.package}/pi/skills
    test -n "$(ls -A ${rendered.package}/claude/agents)"
    test -n "$(ls -A ${rendered.package}/opencode/agents)"
    test -n "$(ls -A ${rendered.package}/pi/agents)"
    test ! -e ${rendered.package}/pi/rules
    grep -F 'ask_user_question' ${rendered.package}/pi/prompts/ctx-plan.md
    grep -F 'name: "proj-writing"' ${rendered.package}/pi/skills/proj-writing/SKILL.md
    grep -F 'name: "architecture-reviewer"' ${rendered.package}/pi/agents/architecture-reviewer.md
    grep -F '`ask_user_question`' ${rendered.package}/pi/AGENTS.md
    grep -F '`Agent`' ${rendered.package}/pi/AGENTS.md
    ! grep -R -F 'AskUserQuestion' ${rendered.package}/pi
    ! grep -R -F 'TaskOutput' ${rendered.package}/pi
    ! grep -R -F 'using the `Skill` tool' ${rendered.package}/pi
    ! grep -R -F 'forked context' ${rendered.package}/pi
    ! grep -R -F '!`' ${rendered.package}/pi
    touch $out
  '';

  wrapperChecks = {
    claude = pkgs.runCommand "nixantic-claude-wrapper-check" { } ''
      grep -F 'CLAUDE_CONFIG_DIR' ${wrapperPackages.claude}/bin/${instructionCfg.wrappers.claude.name}
      grep -F '${rendered.package}/claude' ${wrapperPackages.claude}/bin/${instructionCfg.wrappers.claude.name}
      touch $out
    '';
    opencode = pkgs.runCommand "nixantic-opencode-wrapper-check" { } ''
      grep -F 'OPENCODE_CONFIG_DIR' ${wrapperPackages.opencode}/bin/${instructionCfg.wrappers.opencode.name}
      grep -F '${rendered.package}/opencode' ${wrapperPackages.opencode}/bin/${instructionCfg.wrappers.opencode.name}
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

      harnesses = {
        claude.rules.output = lib.mkOption {
          type = rulesOutputType;
          default = "files";
          description = "How Claude Code rule instructions are emitted.";
        };

        opencode.rules.output = lib.mkOption {
          type = rulesOutputType;
          default = "files";
          description = "How OpenCode rule instructions are emitted.";
        };

        pi = {
          rules.output = lib.mkOption {
            type = rulesOutputType;
            default = "merge-main";
            description = "How Pi rule instructions are emitted.";
          };
          agents = lib.mkOption {
            type = lib.types.enum [ "tintinweb" ];
            default = "tintinweb";
            description = "Pi sub-agent file adapter expected by the rendered instructions.";
          };
          tasks = lib.mkOption {
            type = lib.types.enum [ "tintinweb" ];
            default = "tintinweb";
            description = "Pi task capability adapter expected by the rendered instructions.";
          };
          questions = lib.mkOption {
            type = lib.types.enum [
              "pi-vault-questionnaire"
              "pi-question-tool"
              "rpiv-ask-user-question"
            ];
            default = "rpiv-ask-user-question";
            description = "Pi question capability adapter expected by the rendered instructions.";
          };
        };
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
