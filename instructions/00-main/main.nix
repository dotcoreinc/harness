{
  nixantic.sources.main.instructions."main" =
    { scope }:
    let
      outputPath = scope.forHarness {
        claude = "CLAUDE.md";
        opencode = "AGENTS.md";
      };
    in
    {
      inherit outputPath;

      heading = "Main instructions";

      content = ''
        ## Top level
        CRITICAL: When encounter file reference (ex: @rules/general.md), if not already loaded, read it.

        IMPORTANT: Always write prose using ASD-STE100 Simplified Technical English standard. Short sentences, simple/short/common words, single synonym, active voice, verb as action, one instruction per sentence, no semicolons/emdash, etc.

        Main agents ask the user with `AskUserQuestion`. Sub-agents follow their agent instructions or return questions and decisions to the parent. Never ask directly in responses. Include enough context.

        Unless asked otherwise, always use 

        Trust explicit user input. Don't reconfirm clearly stated information or decisions. Ask only when something is missing, ambiguous, conflicting, or requires separate approval.

        ${scope.blocks."engagement-gate".content}

        Planning is mandatory for ALL implementations, no matter how trivial. When agreed on a plan, ALWAYS follow it. If you deviate or the plan fails, stop and ask the user.

        NEVER execute an irreversible action without explicit user approval. Before deleting/reverting/etc., ALWAYS make sure we can restore. Ask user otherwise.

        NEVER revert changes that you don't recognize. Concurrent work is done in same folder, they may be mine OR another agent.

        NEVER dismiss failures as pre-existing. Confirm with user to fix part of work.

        If work fails after 5 attempts, STOP and ask user for instructions

        ${scope.blocks."task-management".embed}

        ${scope.blocks."pre-flight".embed}

        ${scope.blocks."context-understanding".embed}

        ${scope.blocks."problem-solving".embed}

        ${scope.blocks."deep-thinking".embed}
      '';
    };
}
