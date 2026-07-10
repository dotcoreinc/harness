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
    test -x ${
      coreEval.config.nixantic.instructions.tools.packages."agentic-proj-docs"
    }/bin/agentic-proj-docs
    test -x ${
      coreEval.config.nixantic.instructions.tools.packages."agentic-proj-create-adhoc"
    }/bin/agentic-proj-create-adhoc
    test -f ${coreEval.config.nixantic.instructions.package}/opencode/.gitignore
    test -f ${coreNoBuiltinEval.config.nixantic.instructions.package}/claude/BOM.md
    grep -F '# Main instructions' ${coreEval.config.nixantic.instructions.package}/claude/CLAUDE.md
    grep -F 'jj-current-branch' ${coreEval.config.nixantic.instructions.package}/claude/rules/version-control.md
    test ! -s ${coreEval.config.nixantic.instructions.package}/opencode/.gitignore
    touch $out
  '';

  git-export-variants = pkgs.runCommand "nixantic-git-export-variants-check" { } ''
    test -f ${gitCoreEval.config.nixantic.instructions.package}/claude/CLAUDE.md
    test -f ${gitCoreEval.config.nixantic.instructions.package}/opencode/AGENTS.md
    grep -F 'git branch --show-current' ${gitCoreEval.config.nixantic.instructions.package}/claude/rules/version-control.md
    grep -F 'git branch --show-current' ${gitCoreEval.config.nixantic.instructions.package}/opencode/rules/version-control.md
    if grep -F 'jj-current-branch' ${gitCoreEval.config.nixantic.instructions.package}/claude/rules/version-control.md; then
      echo 'jj content leaked into git claude export' >&2
      exit 1
    fi
    if grep -F 'jj-current-branch' ${gitCoreEval.config.nixantic.instructions.package}/opencode/rules/version-control.md; then
      echo 'jj content leaked into git opencode export' >&2
      exit 1
    fi
    grep -F '${gitCoreEval.config.nixantic.instructions.package}/claude' ${gitCoreEval.config.nixantic.instructions.wrappers.packages.claude}/bin/nixantic-claude
    grep -F '${gitCoreEval.config.nixantic.instructions.package}/opencode' ${gitCoreEval.config.nixantic.instructions.wrappers.packages.opencode}/bin/nixantic-opencode
    touch $out
  '';

  home-manager-adapter = pkgs.runCommand "nixantic-home-manager-adapter-check" { } ''
    test ${
      lib.escapeShellArg homeEval.config.home.file.".claude/CLAUDE.md".source
    } = ${lib.escapeShellArg "${homeEval.config.nixantic.instructions.package}/claude/CLAUDE.md"}
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
    grep -F 'normal `00-<project>.md` and `01-<phase>.md` files' ${coreEval.config.nixantic.instructions.package}/claude/commands/ctx-plan.md
    grep -F 'agentic-proj-create-adhoc' ${coreEval.config.nixantic.instructions.package}/opencode/commands/ctx-plan.md
    grep -F 'normal `00-<project>.md` and `01-<phase>.md` files' ${coreEval.config.nixantic.instructions.package}/opencode/commands/ctx-plan.md
    for instructions in ${coreEval.config.nixantic.instructions.package}/claude ${coreEval.config.nixantic.instructions.package}/opencode; do
      if grep -R -E 'proj-adhoc/ctx-plan\.md|active planning record|project-backed|record-state' "$instructions"; then
        echo "stale planning-record terminology in $instructions" >&2
        exit 1
      fi
      if grep -E 'mktemp|umask|ln -s' "$instructions/commands/ctx-plan.md"; then
        echo "ctx-plan embeds ad hoc project setup in $instructions" >&2
        exit 1
      fi
    done
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

      output=$(cd "$alias" && ${createAdHoc}/bin/agentic-proj-create-adhoc)
      test -L "$physical/proj-adhoc"
      target=$(readlink -f "$physical/proj-adhoc")
      test -d "$target"
      test "$(stat -c %a "$target")" = 700
      printf '%s\n' "$output" | grep -F "Created ad hoc project link: $physical/proj-adhoc"
      printf '%s\n' "$output" | grep -F "Temporary project directory: $target"

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
      output=$(cd "$physical" && OPENCODE_ROOT= CLAUDE_ROOT= ${projectDocs}/bin/agentic-proj-docs)
      test "$output" = "No project files found."
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
    touch $out
  '';
}
