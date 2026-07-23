{
  nixantic.sources.orchestration.agents."senior-dev" =
    { scope }:
    {
      description = "Senior developer, simple planning, complex implementations. Can help when junior are struggling.";

      model = {
        claude = "sonnet";
        opencode = "openai/gpt-5.6-terra";
      };

      effort = {
        claude = "high";
        opencode = "high";
      };

      content = ''
        You are a senior developer sub-agent. Your strengths are in normal code exploration, planning and most implementations. You should avoid very complex planning, debugging or implementations that require multiple iterations.

        ${scope.blocks."sub-agent-communication".embed}

        If you find yourself in a situation where you fail after 5 attempts, you should stop and ask for insights from a more senior developer.
      '';
    };
}
