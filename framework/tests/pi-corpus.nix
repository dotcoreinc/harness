{ pkgs, lib }:

let
  builders = import ../builders.nix { inherit pkgs lib; };
  sourceSets = import ../../source-sets.nix;
  normalizedSources = builders.normalizeSourceDeclarations (
    sourceSets.resolveSources { sourceRoots = [ ../../instructions ]; }
  );
  settings = {
    versionControl.mode = "jj";
    harnesses.pi = {
      rules.output = "merge-main";
      agents = "tintinweb";
      tasks = "tintinweb";
      questions = "rpiv-ask-user-question";
    };
  };
  pi = import ../harnesses/pi.nix { inherit lib settings; };
  scope = builders.makeScope {
    harness = pi;
    inherit settings;
    sources = normalizedSources.sources;
  };
  artifacts = (builtins.attrValues scope.instructions) ++ (builtins.attrValues scope.skillFiles);
  contains = needle: builtins.any (artifact: lib.hasInfix needle artifact.embed) artifacts;
  forbidden = [
    "AskUserQuestion"
    "EnterPlanMode"
    "TaskOutput"
    "todowrite"
    "!`"
    "@rules/"
    "using the `Skill` tool"
    "forked context"
  ];

  cases = [
    {
      name = "full built-in corpus renders directly through Pi before registration";
      pass = scope.instructions.main.outputPath == "AGENTS.md" && builtins.length artifacts > 30;
      detail = "expected direct full-corpus rendering with an AGENTS.md main artifact";
    }
    {
      name = "Pi aggregates rules without inert rule paths";
      pass =
        lib.hasInfix "# Main instructions" scope.instructions.main.embed
        && lib.hasInfix "Use `Agent` to launch a configured sub-agent" scope.instructions.main.embed
        && builtins.all (artifact: !(lib.hasPrefix "rules/" artifact.outputPath)) artifacts;
      detail = "expected active rule bodies in AGENTS.md and no standalone rules";
    }
    {
      name = "Pi corpus contains only declared workflow capabilities";
      pass =
        contains "`Agent`"
        && contains "`get_subagent_result`"
        && contains "`steer_subagent`"
        && contains "`TaskCreate`"
        && contains "`ask_user_question`"
        && builtins.all (needle: !(contains needle)) forbidden;
      detail = "expected configured agent, task, and question tools without unavailable tool leakage";
    }
    {
      name = "Pi PR descriptions use native skills without a fork-context claim";
      pass =
        lib.hasInfix "Agent Skill guidance" scope.commands."pr-desc".embed
        && !(lib.hasInfix "using the `Skill` tool" scope.commands."pr-desc".embed)
        && !(lib.hasInfix "forked context" scope.commands."pr-desc".embed);
      detail = "expected Pi-specific skill wording and truthful current-session execution";
    }
    {
      name = "Pi agents use tintinweb identities and explicitly deny nested delegation";
      pass =
        scope.agents."junior-dev".outputPath == "agents/junior-dev.md"
        && builtins.all (agent: lib.hasInfix "allowed_subagents: false" agent.embed) (
          builtins.attrValues scope.agents
        );
      detail = "expected adapter-discoverable agent paths with explicit nested-agent denial";
    }
    {
      name = "Pi prompts preserve supported arguments and omit shell replacement variables";
      pass =
        lib.hasInfix "Context: `$ARGUMENTS`" scope.commands.think.embed
        && lib.hasInfix "argument-hint: \"[problem or context]\"" scope.commands.think.embed
        && !(lib.hasInfix "--replace='DB: $1" scope.commands."pr-reply-comments".embed);
      detail = "expected Pi prompt arguments while keeping shell replacement variables out of templates";
    }
    {
      name = "Pi mem-writing guidance uses native artifact concepts";
      pass =
        lib.hasInfix "`AGENTS.md` is active context" scope.skills."mem-writing".embed
        && lib.hasInfix "Agent Skills under `skills/<name>/SKILL.md`" scope.skills."mem-writing".embed
        && lib.hasInfix "Markdown prompt templates under `prompts/`" scope.skills."mem-writing".embed;
      detail = "expected Pi-native context, skill, and prompt authoring guidance";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";
  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
