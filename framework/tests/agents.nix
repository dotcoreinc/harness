{ pkgs, lib }:

let
  builders = import ../builders.nix { inherit pkgs lib; };
  claude = import ../harnesses/claude.nix { renderFrontmatter = builders.renderFrontmatter; };
  opencode = import ../harnesses/opencode.nix { renderFrontmatter = builders.renderFrontmatter; };

  agentSource = {
    description = "Agent with harness-specific model and effort";
    content = "Agent body";
    model = {
      claude = "sonnet";
      opencode = "openai/gpt-5.6-luna";
    };
    effort.opencode = "xhigh";
  };

  renderAgent =
    harness:
    (builders.makeScope {
      inherit harness;
      sources.agents."tiered-agent" = agentSource;
    }).agents."tiered-agent".embed;

  claudeAgent = renderAgent claude;
  opencodeAgent = renderAgent opencode;

  claudeExpected = builtins.concatStringsSep "\n" [
    "---"
    "name: \"tiered-agent\""
    "description: \"Agent with harness-specific model and effort\""
    "model: \"sonnet\""
    "---"
    ""
    "Agent body"
  ];

  opencodeExpected = builtins.concatStringsSep "\n" [
    "---"
    "mode: \"subagent\""
    "description: \"Agent with harness-specific model and effort\""
    "model: \"openai/gpt-5.6-luna\""
    "reasoningEffort: \"xhigh\""
    "---"
    ""
    "Agent body"
  ];

  cases = [
    {
      name = "Claude agent selects its model and omits OpenCode-only effort";
      pass = claudeAgent == claudeExpected;
      detail = "expected Claude sonnet model with no effort field";
    }
    {
      name = "OpenCode agent selects its model effort and subagent mode";
      pass = opencodeAgent == opencodeExpected;
      detail = "expected OpenCode selects its model, effort, and subagent mode";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
