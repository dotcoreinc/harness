{
  nixantic.sources.harnesses.instructions."pi-questionnaire" =
    { scope }:
    {
      harnesses = [ "pi" ];
      role = "rule";
      heading = "Interactive questions";
      content = ''
        ${scope.harness.prose.questions.workflow}
      '';
    };
}
