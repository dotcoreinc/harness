{ lib }:

let
  tintinweb = import ./tintinweb.nix;

  renderTaskWorkflow = adapter:
    let
      inherit (adapter) capabilities schema;
    in
    ''
      Use `${capabilities.create}` to create a task. Use `${capabilities.list}`, `${capabilities.get}`, and `${capabilities.update}` to track it. Complete a task with `${schema.completion.tool} { status = "${schema.completion.status}"; }`. Use `${schema.dependencies.addBlocks}` and `${schema.dependencies.addBlockedBy}` for dependencies. Use `${schema.execute.tool}` only with an explicit `agentType`.
    '';

  renderQuestionRequest = adapter:
    if adapter.capabilities.interactiveOnly then
      "use `${adapter.capabilities.ask}` in interactive mode; outside interactive mode, ask in normal chat and stop for the answer"
    else
      "use `${adapter.capabilities.ask}` or ask in normal chat, then stop for the answer";

  renderQuestionWorkflow = adapter:
    let
      inherit (adapter) capabilities schema;
    in
    ''
      ${renderQuestionRequest adapter}. Submit ${toString schema.questionCount.min}-${toString schema.questionCount.max} questions. Each question needs `${builtins.concatStringsSep "`, `" schema.questionFields}`. Include ${toString schema.options.min}-${toString schema.options.max} options, each with `${builtins.concatStringsSep "`, `" schema.options.fields}`.

      Use only adapter-supported optional fields: `${builtins.concatStringsSep "`, `" schema.optionalFields}`. Stop and wait for the answer before continuing.
    '';

  taskAdapters = {
    tintinweb = rec {
      version = "0.8.0";
      capabilities = {
        create = "TaskCreate";
        list = "TaskList";
        get = "TaskGet";
        update = "TaskUpdate";
        output = "TaskOutput";
        stop = "TaskStop";
        execute = "TaskExecute";
      };
      schema = {
        completion = {
          tool = "TaskUpdate";
          status = "completed";
        };
        dependencies = {
          addBlocks = "addBlocks";
          addBlockedBy = "addBlockedBy";
        };
        execute = {
          tool = "TaskExecute";
          requiresAgentType = true;
        };
      };
      prose.workflow = renderTaskWorkflow { inherit capabilities schema; };
    };
  };
  questionAdapters = {
    pi-vault-questionnaire = rec {
      version = "0.2.1";
      capabilities = {
        ask = "questionnaire";
        interactiveOnly = true;
      };
      schema = {
        questionFields = [ "id" "header" "prompt" ];
        questionCount = {
          min = 1;
          max = 10;
        };
        options = {
          min = 2;
          max = 12;
          fields = [ "label" "value" "description" ];
        };
        optionalFields = [ "multiSelect" "recommendation" "allowOther" "allowChat" ];
      };
      prose = {
        request = renderQuestionRequest { inherit capabilities schema; };
        workflow = renderQuestionWorkflow { inherit capabilities schema; };
      };
    };
  };
  select = kind: registry: selection:
    assert builtins.isString selection || throw "Nixantic Pi ${kind} adapter selection must be a string";
    assert builtins.hasAttr selection registry || throw "Nixantic Pi has no ${kind} adapter '${selection}'";
    registry.${selection};
  resolve = config:
    let
      selections = {
        agents = config.agents or "tintinweb";
        tasks = config.tasks or "tintinweb";
        questions = config.questions or "pi-vault-questionnaire";
      };
      agentAdapter = select "agent" { tintinweb = tintinweb; } selections.agents;
      taskAdapter = select "task" taskAdapters selections.tasks;
      questionAdapter = select "question" questionAdapters selections.questions;
    in
    {
      inherit selections agentAdapter taskAdapter questionAdapter;
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
      prose = {
        tasks = taskAdapter.prose;
        questions = questionAdapter.prose;
      };
    };
in
{
  inherit renderTaskWorkflow renderQuestionWorkflow resolve;
  validate = config:
    let
      resolved = resolve config;
    in
    resolved.capabilities.agents.launch != null
    && resolved.capabilities.tasks.create != null
    && resolved.capabilities.questions.ask != null;
}
