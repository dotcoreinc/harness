{ pkgs, lib }:

let
  capabilities = import ../harnesses/pi/capabilities.nix { inherit lib; };
  defaults = capabilities.resolve { };
  overridden = capabilities.resolve {
    agents = "tintinweb";
    tasks = "tintinweb";
    questions = "pi-vault-questionnaire";
  };
  unknownAgent = builtins.tryEval (capabilities.validate { agents = "unknown"; });
  unknownTask = builtins.tryEval (capabilities.validate { tasks = "unknown"; });
  unknownQuestion = builtins.tryEval (capabilities.validate { questions = "unknown"; });
  mockTaskWorkflow = capabilities.renderTaskWorkflow {
    capabilities = {
      create = "CreateWork";
      list = "ListWork";
      get = "GetWork";
      update = "UpdateWork";
      stop = "StopWork";
      execute = "RunWork";
    };
    schema = {
      completion = {
        tool = "UpdateWork";
        status = "done";
      };
      dependencies = {
        addBlocks = "blocks";
        addBlockedBy = "blocked-by";
      };
      execute = {
        tool = "RunWork";
        requiresAgentType = true;
      };
    };
  };
  mockQuestionWorkflow = capabilities.renderQuestionWorkflow {
    capabilities = {
      ask = "AskStructured";
      interactiveOnly = false;
    };
    schema = {
      questionFields = [ "id" "header" ];
      questionCount = {
        min = 2;
        max = 4;
      };
      options = {
        min = 3;
        max = 5;
        fields = [ "title" "answer" ];
      };
      optionalFields = [ "freeform" ];
    };
  };

  cases = [
    {
      name = "Pi capability defaults resolve independent adapter selections";
      pass =
        defaults.selections == {
          agents = "tintinweb";
          tasks = "tintinweb";
          questions = "pi-vault-questionnaire";
        }
        && defaults.capabilities.agents == {
          launch = "Agent";
          result = "get_subagent_result";
          steer = "steer_subagent";
        }
        && defaults.capabilities.tasks.create == "TaskCreate"
        && defaults.capabilities.questions == {
          ask = "questionnaire";
          interactiveOnly = true;
        }
        && defaults.capabilities.skills.invocation == "pi-native"
        && defaults.adapters.agents.version == "0.17.1"
        && defaults.adapters.agents.supportedPolicyFields == [
          "allowedSubagents"
          "disallowedTools"
          "excludeExtensions"
          "extensions"
          "isolated"
          "isolation"
          "persistSession"
          "skills"
          "tools"
        ]
        && defaults.adapters.tasks.version == "0.8.0"
        && defaults.adapters.tasks.schema.execute.requiresAgentType
        && defaults.adapters.questions.version == "0.2.1"
        && defaults.adapters.questions.schema.questionCount.max == 10;
      detail = "expected the three configured adapters to expose the normalized Pi capability contract";
    }
    {
      name = "Pi adapter selections remain independent";
      pass = overridden.capabilities.agents.launch == "Agent" && overridden.capabilities.tasks.execute == "TaskExecute";
      detail = "expected independently selected agent and task adapters to retain their respective capabilities";
    }
    {
      name = "unknown Pi adapter selections fail clearly";
      pass = !unknownAgent.success && !unknownTask.success && !unknownQuestion.success;
      detail = "expected unknown agent, task, and question selections to fail evaluation";
    }
    {
      name = "adapter prose helpers derive task and question wording from adapter contracts";
      pass =
        lib.hasInfix "`CreateWork`" mockTaskWorkflow
        && lib.hasInfix "status = \"done\"" mockTaskWorkflow
        && lib.hasInfix "`blocks`" mockTaskWorkflow
        && lib.hasInfix "2-4 questions" mockQuestionWorkflow
        && lib.hasInfix "3-5 options" mockQuestionWorkflow
        && lib.hasInfix "`AskStructured`" mockQuestionWorkflow
        && !(lib.hasInfix "questionnaire" mockQuestionWorkflow);
      detail = "expected semantic workflow prose to remain adapter-driven instead of package-name driven";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";
  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
