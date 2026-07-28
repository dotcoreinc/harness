{
  nixantic.sources.projects.blocks."plan-procedure" =
    { scope }:
    {
      content = ''
        - Use ${scope.blocks.deep-thinking.reference}
        - Use ${scope.blocks.sub-agents-workflows.reference} for exploration, research and investigation
        - Use ${scope.blocks.context-understanding.reference} to improve understanding

        - Search web for unfamiliar or potential oudated info
        - Add sub-task 🔳 to prevent forgetting uncertainties, work them out until full understanding

        - Interview me relentlessly, using `AskUserQuestion`, about every unresolved aspect of this plan until we reach a shared understanding. Do not ask about information or decisions the user already clearly provided. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer. Any questions you could answer yourself through research should be researched first. If still unsure, give me as much context as possible in questions. Capture each question & answer in project/phase docs.

        - List/understand/ask for requirements and acceptance criteria.
        - Note all planning decisions and investigation outcomes.

        - Break into logical phases.
        - Identify key files and components
        - Consider dependencies and challenges

        - Breakdown in tasks, with ACs, dependencies
        - Select the agent for each task using ${scope.blocks.sub-agent-selection.reference}
        - Include testing as tasks for autonomous iteration using ${scope.blocks.testing-principles.reference}
      '';
    };
}
