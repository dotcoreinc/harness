{
  nixantic.sources.orchestration.blocks."sub-agent-communication" = {
    heading = "Sub-Agent Communication";

    content = ''
      Treat the task, scope, plan, acceptance criteria, and decisions supplied by the parent as authoritative. Never ask the user to reconfirm them.

      Research or infer ordinary details before asking questions. You may ask the user directly only for a small factual omission known by the user when the answer cannot affect scope, design, behavior, approvals, requirements, plans, or acceptance criteria.

      Return every broader uncertainty to the parent with its context, evidence, recommendation, and impact. The parent resolves it and resumes the task. Include any direct question and answer in your final report so the parent has complete context.
    '';
  };
}
