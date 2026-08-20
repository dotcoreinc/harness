{ lib }:

let
  tintinweb = import ./tintinweb.nix;

  taskAdapters = {
    # @tintinweb/pi-tasks (npm:@tintinweb/pi-tasks@0.8.0) registers the
    # `Task*` task tools.
    tintinweb = {
      version = "0.8.0";
      capabilities = {
        create = "TaskCreate";
      };
      prose.workflow = "Use the `Task*` tools for tasks.";
    };
  };
  questionAdapters = {
    # @pi-vault/pi-questionnaire (npm:@pi-vault/pi-questionnaire@0.2.1)
    # registers the `questionnaire` tool.
    pi-vault-questionnaire = {
      version = "0.2.1";
      capabilities = {
        ask = "questionnaire";
      };
    };

    # pi-question-tool (https://pi.dev/packages/pi-question-tool) registers
    # `question` (single) and `questionnaire` tools for an interactive TTY.
    pi-question-tool = {
      version = "0.1.1";
      capabilities = {
        ask = "questionnaire";
      };
    };

    # @juicesharp/rpiv-ask-user-question
    # (npm:@juicesharp/rpiv-ask-user-question@2.4.0) registers the
    # `ask_user_question` tool and removes it from the tool list in
    # non-interactive runs.
    rpiv-ask-user-question = {
      version = "2.4.0";
      capabilities = {
        ask = "ask_user_question";
      };
    };
  };
  select =
    kind: registry: selection:
    assert
      builtins.isString selection || throw "Nixantic Pi ${kind} adapter selection must be a string";
    assert
      builtins.hasAttr selection registry || throw "Nixantic Pi has no ${kind} adapter '${selection}'";
    registry.${selection};
  resolve =
    config:
    let
      selections = {
        agents = config.agents or "tintinweb";
        tasks = config.tasks or "tintinweb";
        questions = config.questions or "rpiv-ask-user-question";
      };
      agentAdapter = select "agent" { tintinweb = tintinweb; } selections.agents;
      taskAdapter = select "task" taskAdapters selections.tasks;
      questionAdapter = select "question" questionAdapters selections.questions;
    in
    {
      inherit
        selections
        agentAdapter
        taskAdapter
        questionAdapter
        ;
      adapters = {
        agents = agentAdapter;
        tasks = taskAdapter;
        questions = questionAdapter;
      };
      capabilities = {
        agents = agentAdapter.capabilities;
        tasks = taskAdapter.capabilities;
        questions = questionAdapter.capabilities;
        skills.invocation = "pi-native";
      };
      # Extension tool descriptions already document tool usage in the model
      # context, so rendered instructions only name the tools to use.
      prose = {
        tasks = taskAdapter.prose;
        questions = { request = "use `${questionAdapter.capabilities.ask}`"; };
      };
    };
in
{
  inherit resolve;
  validate =
    config:
    let
      resolved = resolve config;
    in
    resolved.capabilities.agents.launch != null
    && resolved.capabilities.tasks.create != null
    && resolved.capabilities.questions.ask != null;
}
