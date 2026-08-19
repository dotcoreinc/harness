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
  gitCoreEval = evalCore [ { nixantic.versionControl.mode = "git"; } ];
  coreNoBuiltinEval = evalCore [ { nixantic.instructions.profile = "none"; } ];
  docsSources = {
    example = {
      instructions.main =
        { scope }:
        {
          role = "main";
          heading = "Project instructions";
          content = "Use the project conventions.";
        };
      instructions.rule = {
        role = "rule";
        heading = "Project rule";
        content = "Use the project rule.";
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
  moduleHarnessSettings = {
    claude.rules.output = "merge-main";
    opencode.rules.output = "merge-main";
    pi = {
      rules.output = "files";
      agents = "tintinweb";
      tasks = "tintinweb";
      questions = "pi-vault-questionnaire";
    };
  };
  defaultHarnessSettings = {
    claude.rules.output = "files";
    opencode.rules.output = "files";
    pi = {
      rules.output = "merge-main";
      agents = "tintinweb";
      tasks = "tintinweb";
      questions = "pi-vault-questionnaire";
    };
  };
  moduleOverrideEval = evalCore [
    {
      nixantic.instructions.profile = "none";
      nixantic.instructions.harnesses = moduleHarnessSettings;
      nixantic.sources = docsSources;
    }
  ];
  invalidModuleSettings = builtins.tryEval (
    (evalCore [ { nixantic.instructions.harnesses.pi.tasks = "not-an-adapter"; } ])
    .config.nixantic.instructions.package
  );
  directOverrideRendered = import ../framework {
    inherit pkgs lib;
    postProcess = true;
    sourceRoots = [ ];
    sources = docsSources;
    settings = {
      versionControl.mode = "jj";
      harnesses = moduleHarnessSettings;
    };
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
        {
          harness = "pi";
          source = "AGENTS.md";
          target = ".pi/agent/AGENTS.md";
        }
        {
          harness = "pi";
          source = "prompts/hello.md";
          target = ".pi/agent/prompts/hello.md";
        }
        {
          harness = "pi";
          source = "skills/example/SKILL.md";
          target = ".pi/agent/skills/example/SKILL.md";
        }
        {
          harness = "pi";
          source = "agents/example.md";
          target = ".pi/agent/agents/example.md";
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
    test -f ${coreEval.config.nixantic.instructions.package}/pi/AGENTS.md
    test -x ${
      coreEval.config.nixantic.instructions.tools.packages."agentic-proj-docs"
    }/bin/agentic-proj-docs
    test -x ${
      coreEval.config.nixantic.instructions.tools.packages."agentic-proj-create-adhoc"
    }/bin/agentic-proj-create-adhoc
    test -f ${coreEval.config.nixantic.instructions.package}/opencode/.gitignore
    test -f ${coreNoBuiltinEval.config.nixantic.instructions.package}/claude/BOM.md
    test ! -s ${coreEval.config.nixantic.instructions.package}/opencode/.gitignore
    touch $out
  '';

  module-settings = pkgs.runCommand "nixantic-module-settings-check" { } ''
    test '${builtins.toJSON coreEval.config.nixantic.instructions.harnesses}' = '${builtins.toJSON defaultHarnessSettings}'
    test '${builtins.toJSON moduleOverrideEval.config.nixantic.instructions.harnesses}' = '${builtins.toJSON moduleHarnessSettings}'
    test '${moduleOverrideEval.config.nixantic.instructions.package}' = '${directOverrideRendered.package}'
    ${
      if invalidModuleSettings.success then
        "echo invalid Pi module adapter unexpectedly evaluated >&2; exit 1"
      else
        "true"
    }
    grep -F 'Use the project rule' ${moduleOverrideEval.config.nixantic.instructions.package}/claude/CLAUDE.md
    grep -F 'Use the project rule' ${moduleOverrideEval.config.nixantic.instructions.package}/opencode/AGENTS.md
    test ! -e ${moduleOverrideEval.config.nixantic.instructions.package}/claude/rules
    test ! -e ${moduleOverrideEval.config.nixantic.instructions.package}/opencode/rules
    test -f ${moduleOverrideEval.config.nixantic.instructions.package}/pi/rules/rule.md
    touch $out
  '';

  builtin-pi-corpus = pkgs.runCommand "nixantic-builtin-pi-corpus-check" { } ''
    test -f ${coreEval.config.nixantic.instructions.package}/pi/AGENTS.md
    test -d ${coreEval.config.nixantic.instructions.package}/pi/prompts
    test -d ${coreEval.config.nixantic.instructions.package}/pi/skills
    test -n "$(ls -A ${coreEval.config.nixantic.instructions.package}/pi/agents)"
    grep -F 'Main instructions' ${coreEval.config.nixantic.instructions.package}/pi/AGENTS.md
    grep -F 'questionnaire' ${coreEval.config.nixantic.instructions.package}/pi/prompts/ctx-plan.md
    grep -F 'name: "proj-writing"' ${coreEval.config.nixantic.instructions.package}/pi/skills/proj-writing/SKILL.md
    grep -F 'name: "architecture-reviewer"' ${coreEval.config.nixantic.instructions.package}/pi/agents/architecture-reviewer.md
    test ! -e ${coreEval.config.nixantic.instructions.package}/pi/rules
    ! grep -R -F 'AskUserQuestion' ${coreEval.config.nixantic.instructions.package}/pi
    ! grep -R -F 'TaskOutput' ${coreEval.config.nixantic.instructions.package}/pi/prompts/review-launch.md
    touch $out
  '';

  agent-selection-routing = pkgs.runCommand "nixantic-agent-selection-routing-check" { } ''
    for harness in claude opencode; do
      root=${coreEval.config.nixantic.instructions.package}/$harness
      orchestration="$root/rules/orchestration.md"

      workflow_open=$(grep -n -m1 '^<sub-agents-workflows>$' "$orchestration" | cut -d: -f1)
      selection_open=$(grep -n -m1 '^<sub-agent-selection>$' "$orchestration" | cut -d: -f1)
      selection_close=$(grep -n -m1 '^</sub-agent-selection>$' "$orchestration" | cut -d: -f1)
      workflow_close=$(grep -n -m1 '^</sub-agents-workflows>$' "$orchestration" | cut -d: -f1)
      test "$workflow_open" -lt "$selection_open"
      test "$selection_open" -lt "$selection_close"
      test "$selection_close" -lt "$workflow_close"

      grep -F 'Select the agent for each task using <sub-agent-selection>' "$root/commands/ctx-plan.md"
      grep -F 'Select the agent for each task using <sub-agent-selection>' "$root/commands/proj-plan.md"
      grep -F 'select it using <sub-agent-selection>' "$root/skills/proj-writing/SKILL.md"
      grep -F 'reselect using <sub-agent-selection>' "$root/commands/implement.md"

      grep -F 'Use <sub-agents-workflows> for exploration, research and investigation' "$root/commands/ctx-plan.md"
      grep -F 'Use <sub-agents-workflows> for exploration, research and investigation' "$root/commands/proj-plan.md"
      grep -F 'Use <sub-agents-workflows> for exploration, research and investigation' "$root/commands/ctx-improve.md"
      grep -F 'You need to follow <sub-agents-workflows>' "$root/commands/implement.md"
    done
    touch $out
  '';

  git-export-variants = pkgs.runCommand "nixantic-git-export-variants-check" { } ''
    test -f ${gitCoreEval.config.nixantic.instructions.package}/claude/CLAUDE.md
    test -f ${gitCoreEval.config.nixantic.instructions.package}/opencode/AGENTS.md
    test -f ${gitCoreEval.config.nixantic.instructions.package}/pi/AGENTS.md
    assert_variant() {
      expected=$1
      unexpected=$2
      shift 2
      for rules in "$@"; do
        grep -F "$expected" "$rules"
        if grep -F "$unexpected" "$rules"; then
          echo "unexpected version-control variant in $rules" >&2
          exit 1
        fi
      done
    }
    assert_variant 'jj-current-branch' 'git branch --show-current' \
      ${coreEval.config.nixantic.instructions.package}/claude/rules/version-control.md \
      ${coreEval.config.nixantic.instructions.package}/opencode/rules/version-control.md \
      ${coreEval.config.nixantic.instructions.package}/pi/AGENTS.md
    assert_variant 'git branch --show-current' 'jj-current-branch' \
      ${gitCoreEval.config.nixantic.instructions.package}/claude/rules/version-control.md \
      ${gitCoreEval.config.nixantic.instructions.package}/opencode/rules/version-control.md \
      ${gitCoreEval.config.nixantic.instructions.package}/pi/AGENTS.md
    grep -F '${gitCoreEval.config.nixantic.instructions.package}/claude' ${gitCoreEval.config.nixantic.instructions.wrappers.packages.claude}/bin/nixantic-claude
    grep -F '${gitCoreEval.config.nixantic.instructions.package}/opencode' ${gitCoreEval.config.nixantic.instructions.wrappers.packages.opencode}/bin/nixantic-opencode
    touch $out
  '';

  home-manager-adapter = pkgs.runCommand "nixantic-home-manager-adapter-check" { } ''
    test ${
      lib.escapeShellArg homeEval.config.home.file.".claude/CLAUDE.md".source
    } = ${lib.escapeShellArg "${homeEval.config.nixantic.instructions.package}/claude/CLAUDE.md"}
    test ${
      lib.escapeShellArg homeEval.config.home.file.".pi/agent/AGENTS.md".source
    } = ${lib.escapeShellArg "${homeEval.config.nixantic.instructions.package}/pi/AGENTS.md"}
    test ${
      lib.escapeShellArg homeEval.config.home.file.".pi/agent/prompts/hello.md".source
    } = ${lib.escapeShellArg "${homeEval.config.nixantic.instructions.package}/pi/prompts/hello.md"}
    test ${
      lib.escapeShellArg homeEval.config.home.file.".pi/agent/skills/example/SKILL.md".source
    } = ${lib.escapeShellArg "${homeEval.config.nixantic.instructions.package}/pi/skills/example/SKILL.md"}
    test ${
      lib.escapeShellArg homeEval.config.home.file.".pi/agent/agents/example.md".source
    } = ${lib.escapeShellArg "${homeEval.config.nixantic.instructions.package}/pi/agents/example.md"}
    ${
      if
        builtins.elem coreEval.config.nixantic.instructions.tools.packages."agentic-proj-docs"
          homeEval.config.home.packages
      then
        "true"
      else
        "echo 'Home Manager does not install agentic-proj-docs' >&2; exit 1"
    }
    ${
      if
        builtins.elem coreEval.config.nixantic.instructions.tools.packages."agentic-proj-create-adhoc"
          homeEval.config.home.packages
      then
        "true"
      else
        "echo 'Home Manager does not install agentic-proj-create-adhoc' >&2; exit 1"
    }
    ${
      if builtins.hasAttr "pi" homeEval.config.nixantic.instructions.wrappers.packages then
        "echo Home Manager unexpectedly exposes a Pi wrapper >&2; exit 1"
      else
        "true"
    }
    test ${toString (builtins.length homeEval.config.home.packages)} = 4
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
    grep -F 'agentic-proj-create-adhoc' ${coreEval.config.nixantic.instructions.package}/claude/commands/ctx-plan.md
    grep -F 'agentic-proj-create-adhoc' ${coreEval.config.nixantic.instructions.package}/opencode/commands/ctx-plan.md
    touch $out
  '';

  ad-hoc-project-tools =
    let
      createAdHoc = coreEval.config.nixantic.instructions.tools.packages."agentic-proj-create-adhoc";
      projectDocs = coreEval.config.nixantic.instructions.tools.packages."agentic-proj-docs";
    in
    pkgs.runCommand "nixantic-ad-hoc-project-tools-check" { } ''
      root=$(mktemp -d)
      physical="$root/physical"
      alias="$root/alias"
      mkdir "$physical"
      ln -s "$physical" "$alias"

      (cd "$alias" && ${createAdHoc}/bin/agentic-proj-create-adhoc)
      test -L "$physical/proj-adhoc"
      target=$(readlink -f "$physical/proj-adhoc")
      test -d "$target"
      test "$(stat -c %a "$target")" = 700

      rm "$physical/proj-adhoc"
      ln -s "$root/missing" "$physical/proj-adhoc"
      (cd "$physical" && ${createAdHoc}/bin/agentic-proj-create-adhoc)
      test -L "$physical/proj-adhoc"
      test "$(readlink -f "$physical/proj-adhoc")" != "$root/missing"

      mkdir "$physical/proj"
      if (cd "$physical" && ${createAdHoc}/bin/agentic-proj-create-adhoc); then
        echo "creator unexpectedly replaced proj" >&2
        exit 1
      fi
      test -d "$physical/proj"
      rm -rf "$physical/proj" "$physical/proj-adhoc"

      mkdir "$physical/live"
      ln -s "$physical/live" "$physical/proj-adhoc"
      if (cd "$physical" && ${createAdHoc}/bin/agentic-proj-create-adhoc); then
        echo "creator unexpectedly replaced a live symlink" >&2
        exit 1
      fi
      test "$(readlink "$physical/proj-adhoc")" = "$physical/live"
      rm "$physical/proj-adhoc"

      : > "$physical/proj-adhoc"
      if (cd "$physical" && ${createAdHoc}/bin/agentic-proj-create-adhoc); then
        echo "creator unexpectedly replaced a file" >&2
        exit 1
      fi
      test -f "$physical/proj-adhoc"
      rm "$physical/proj-adhoc"

      mkdir "$physical/proj-adhoc"
      if (cd "$physical" && ${createAdHoc}/bin/agentic-proj-create-adhoc); then
        echo "creator unexpectedly replaced a directory" >&2
        exit 1
      fi
      test -d "$physical/proj-adhoc"
      rm -rf "$physical/proj-adhoc"

      ln -s "$root/missing" "$physical/proj-adhoc"
      (cd "$physical" && OPENCODE_ROOT= CLAUDE_ROOT= ${projectDocs}/bin/agentic-proj-docs)
      test ! -e "$physical/proj"
      test -L "$physical/proj-adhoc"
      rm "$physical/proj-adhoc"

      ad_hoc_target="$root/ad-hoc-project"
      mkdir "$ad_hoc_target"
      : > "$ad_hoc_target/00-ad-hoc.md"
      ln -s "$ad_hoc_target" "$physical/proj-adhoc"
      output=$(cd "$physical" && OPENCODE_ROOT= CLAUDE_ROOT= ${projectDocs}/bin/agentic-proj-docs)
      printf '%s\n' "$output" | grep -F "$physical/proj-adhoc ("
      printf '%s\n' "$output" | grep -F '00-ad-hoc.md'
      rm "$physical/proj-adhoc"
      rm -rf "$ad_hoc_target"

      mkdir "$physical/proj" "$physical/proj-adhoc"
      : > "$physical/proj/00-committed.md"
      : > "$physical/proj-adhoc/00-ad-hoc.md"
      output=$(cd "$physical" && OPENCODE_ROOT= CLAUDE_ROOT= ${projectDocs}/bin/agentic-proj-docs)
      printf '%s\n' "$output" | grep -F "$physical/proj ("
      printf '%s\n' "$output" | grep -F '00-committed.md'
      if printf '%s\n' "$output" | grep -F '00-ad-hoc.md'; then
        echo "project helper did not preserve proj precedence" >&2
        exit 1
      fi

      failure_workspace="$root/link-failure"
      failure_tmp="$root/link-failure-tmp"
      mkdir "$failure_workspace" "$failure_tmp"
      : > "$failure_tmp/keep"
      chmod 500 "$failure_workspace"
      if output=$(cd "$failure_workspace" && TMPDIR="$failure_tmp" ${createAdHoc}/bin/agentic-proj-create-adhoc 2>&1); then
        echo "creator unexpectedly succeeded when link creation was denied" >&2
        exit 1
      fi
      chmod 700 "$failure_workspace"
      printf '%s\n' "$output" | grep -F 'temporary directory'
      printf '%s\n' "$output" | grep -F 'was removed'
      test -f "$failure_tmp/keep"
      for entry in "$failure_tmp"/ctx-plan.*; do
        test ! -e "$entry"
      done

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
    grep -F 'harness = "pi"' ${../README.md}
    grep -F 'rules.output' ${../README.md}
    grep -F 'agents = "tintinweb"' ${../README.md}
    grep -F 'tasks = "tintinweb"' ${../README.md}
    grep -F 'questions = "pi-vault-questionnaire"' ${../README.md}
    grep -F 'target = ".pi/agent/agents/reviewer.md"' ${../README.md}
    grep -F '~/.pi/agent/agents/' ${../README.md}
    grep -F 'Consumers install and activate Pi' ${../README.md}
    touch $out
  '';
}
