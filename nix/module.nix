{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatStringsSep
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.hardware.freealien;
  profile = cfg.startupProfile;
  binary = "${cfg.package}/bin/freealien";

  keyboardCommand =
    if profile.keyboard.effect == null then
      "${binary} static ${lib.escapeShellArg profile.keyboard.baseColor}"
    else
      let
        effect = profile.keyboard.effect;
        colourMode =
          if effect == "rainbow" then
            3
          else if
            builtins.elem effect [
              "double_wave"
              "morph"
            ]
          then
            2
          else
            1;
      in
      concatStringsSep " " [
        "${binary} effect"
        (lib.escapeShellArg effect)
        (lib.escapeShellArg profile.keyboard.baseColor)
        "--secondary"
        (lib.escapeShellArg profile.keyboard.secondaryColor)
        "--tempo"
        (toString profile.keyboard.tempo)
        "--colour-mode"
        (toString colourMode)
      ];

  keysByColour = lib.groupBy (key: profile.keyboard.keys.${key}) (
    lib.attrNames profile.keyboard.keys
  );

  keyCommands = mapAttrsToList (
    colour: keys:
    concatStringsSep " " (
      [
        "${binary} key"
        (lib.escapeShellArg colour)
      ]
      ++ map lib.escapeShellArg keys
      ++ [
        "--keep"
        "--no-take-control"
      ]
    )
  ) keysByColour;

  profileScript = pkgs.writeShellApplication {
    name = "freealien-apply-startup-profile";
    text = concatStringsSep "\n" (
      [ keyboardCommand ]
      ++ keyCommands
      ++ lib.optional (
        profile.touchpad != null
      ) "${binary} touchpad ${lib.escapeShellArg profile.touchpad}"
      ++ lib.optional (profile.logo != null) "${binary} logo ${lib.escapeShellArg profile.logo}"
      ++ lib.optional (
        profile.chassisBrightness != null
      ) "${binary} brightness ${toString profile.chassisBrightness}"
    );
  };
in
{
  options.hardware.freealien = {
    enable = mkEnableOption "FreeAlien hardware control";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "freealien.packages.${pkgs.system}.default";
      description = "FreeAlien package";
    };

    startupProfile = {
      enable = mkEnableOption "applying a volatile lighting profile at user login";

      keyboard = {
        baseColor = mkOption {
          type = types.str;
          default = "0050ff";
          description = "Base keyboard colour as a name, rrggbb, #rrggbb, or r,g,b.";
        };

        keys = mkOption {
          type = types.attrsOf types.str;
          default = { };
          example = {
            W = "ff0000";
            A = "ff0000";
            S = "ff0000";
            D = "ff0000";
          };
          description = "Per-key colour overrides. Attribute names are labels from `freealien keys`.";
        };

        effect = mkOption {
          type = types.nullOr (
            types.enum [
              "breathing"
              "side_wave"
              "double_wave"
              "morph"
              "bounce"
              "rainbow"
            ]
          );
          default = null;
          description = "Keyboard hardware effect, or null for per-key mode.";
        };

        secondaryColor = mkOption {
          type = types.str;
          default = "000000";
          description = "Second colour for two-colour keyboard effects.";
        };

        tempo = mkOption {
          type = types.ints.between 0 255;
          default = 100;
          description = "Keyboard hardware-effect tempo byte (0 to 255).";
        };
      };

      touchpad = mkOption {
        type = types.nullOr types.str;
        default = "0050ff";
        description = "Volatile touchpad-ring colour, or null to leave it unchanged.";
      };

      logo = mkOption {
        type = types.nullOr types.str;
        default = "0050ff";
        description = "Volatile lid-logo colour, or null to leave it unchanged.";
      };

      chassisBrightness = mkOption {
        type = types.nullOr (types.ints.between 0 255);
        default = null;
        description = "AW-ELC chassis brightness, or null to leave it unchanged.";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    systemd.user.services.freealien-startup-profile = mkIf profile.enable {
      description = "Apply the FreeAlien lighting profile";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${profileScript}/bin/freealien-apply-startup-profile";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "3s";
      };
    };
  };
}
