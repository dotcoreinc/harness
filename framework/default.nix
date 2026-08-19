{
  pkgs,
  lib,
  postProcess ? false,
  bom ? { },
  sourceRoots ? [ ],
  sources ? { },
  settings ? { },
}:

let
  defaultSettings = {
    versionControl.mode = "jj";
    harnesses = {
      claude.rules.output = "files";
      opencode.rules.output = "files";
      pi = {
        rules.output = "merge-main";
        agents = "tintinweb";
        tasks = "tintinweb";
        questions = "pi-vault-questionnaire";
      };
    };
  };
  effectiveSettings = lib.recursiveUpdate defaultSettings settings;
  rawHarnessSettings = settings.harnesses or { };
  configuredHarnesses = builtins.attrNames (effectiveSettings.harnesses or { });
  knownHarnesses = [ "claude" "opencode" "pi" ];
  harnessSettingKeys = {
    claude = [ "rules" ];
    opencode = [ "rules" ];
    pi = [ "rules" "agents" "tasks" "questions" ];
  };
  unknownHarnesses = builtins.filter (name: !(builtins.elem name knownHarnesses)) configuredHarnesses;
  unknownHarnessSettingKeys = builtins.concatLists (map (
    name: map (key: "${name}.${key}") (builtins.filter (key: !(builtins.elem key harnessSettingKeys.${name})) (builtins.attrNames rawHarnessSettings.${name}))
  ) (builtins.filter (name: builtins.elem name knownHarnesses) (builtins.attrNames rawHarnessSettings)));
  unknownRuleSettingKeys = builtins.concatLists (map (
    name:
    map (key: "${name}.rules.${key}") (
      builtins.filter (key: key != "output") (builtins.attrNames (rawHarnessSettings.${name}.rules or { }))
    )
  ) (builtins.filter (name: builtins.elem name knownHarnesses) (builtins.attrNames rawHarnessSettings)));
  invalidRuleOutputs = builtins.filter (
    name: !(builtins.elem effectiveSettings.harnesses.${name}.rules.output [ "files" "merge-main" ])
  ) configuredHarnesses;
  instructionApi = import ./builders.nix { inherit pkgs lib; };
  piCapabilities = import ./harnesses/pi/capabilities.nix { inherit lib; };
  sourceSets = import ../source-sets.nix;
  harnesses = import ./harnesses {
    inherit lib;
    renderFrontmatter = instructionApi.renderFrontmatter;
    settings = effectiveSettings;
  };
  harnessNames = builtins.attrNames harnesses;

  ownerIndexedSources =
    assert unknownHarnesses == [ ] || throw "Nixantic settings.harnesses has unknown harness keys: ${builtins.concatStringsSep ", " unknownHarnesses}";
    assert unknownHarnessSettingKeys == [ ] || throw "Nixantic settings.harnesses has unknown setting keys: ${builtins.concatStringsSep ", " unknownHarnessSettingKeys}";
    assert unknownRuleSettingKeys == [ ] || throw "Nixantic settings.harnesses has unknown rule setting keys: ${builtins.concatStringsSep ", " unknownRuleSettingKeys}";
    assert invalidRuleOutputs == [ ] || throw "Nixantic settings.harnesses.<harness>.rules.output must be \"files\" or \"merge-main\": ${builtins.concatStringsSep ", " invalidRuleOutputs}";
    assert piCapabilities.validate effectiveSettings.harnesses.pi;
    sourceSets.resolveSources { inherit sourceRoots sources; };
  flattenedSources = instructionApi.normalizeSourceDeclarations ownerIndexedSources;

  scopes = lib.mapAttrs (
    _: harness:
    instructionApi.makeScope {
      inherit harness;
      sources = flattenedSources.sources;
      settings = effectiveSettings;
    }
  ) harnesses;
  instructions = lib.mapAttrs (_: scope: scope.instructions) scopes;
  blocks = lib.mapAttrs (_: scope: scope.blocks) scopes;

  package = instructionApi.mkPackage { inherit scopes postProcess bom; };

  testResult =
    let
      tests = import ./tests { inherit pkgs lib; };
    in
    if tests.allPass then "pass" else throw "Nixantic instruction tests failed";

  check = import ./checks.nix {
    inherit
      package
      pkgs
      lib
      testResult
      ;
  };
in
{
  inherit
    package
    check
    blocks
    harnessNames
    harnesses
    ;
}
// instructions
// {
  harnesses = harnesses;
}
