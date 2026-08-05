{
  nixantic.sources.review-workflow.commands."review-interactive" = { scope }: {
    description = "Interactive review flow, investigating each feedback/comment with sub-agent and collecting into phase documentation";

    content = ''
      Goal: Interactively review feedback/comments, investigate each with sub-agent, and collect into phase documentation.

      ## Instructions

      1. 🔳 Create a new phase in project documentation for this review session.
         Should be a sub-phase of latest phase that we worked on. E.g. phase 1 -> phase 1a.
         Commit the project document files version control instructions.

      2. For each feedback/comment, launch a ${
        scope.agents."junior-dev".reference
      } in background to explore/investigate the feedback.
         Collect the results into questions/investigations section. 
         If directly actionable without further planning, add to tasks section.
         If planning is required, note it and tell user about it. 
         Never fix them directly, we are only collecting feedback and investigations.

      Do not ask me for feedback/review, I'll follow up with you, no need to ask.
    '';
  };

}
