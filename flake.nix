{
  description = "FreeAlien: Alienware lighting and hardware control for Linux";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      packageFor = system: nixpkgs.legacyPackages.${system}.callPackage ./nix/package.nix { };
    in
    {
      packages = forAllSystems (system: {
        default = packageFor system;
        freealien = packageFor system;
      });

      apps = forAllSystems (
        system:
        let
          package = packageFor system;
          gui = nixpkgs.legacyPackages.${system}.writeShellScript "freealien-gui" ''
            exec ${package}/bin/freealien gui "$@"
          '';
        in
        {
          default = {
            type = "app";
            program = "${package}/bin/freealien";
            meta.description = "Alienware m16 R2 command-line controller";
          };
          gui = {
            type = "app";
            program = "${gui}";
            meta.description = "FreeAlien desktop control panel";
          };
        }
      );

      overlays.default = final: _prev: {
        freealien = final.callPackage ./nix/package.nix { };
      };

      nixosModules.default = import ./nix/module.nix;
      nixosModules.freealien = self.nixosModules.default;

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          package = packageFor system;
        in
        {
          inherit package;

          smoke =
            pkgs.runCommand "freealien-smoke-test"
              {
                nativeBuildInputs = [
                  package
                  pkgs.gnugrep
                ];
              }
              ''
                freealien --dry-run static 0050ff | grep -q "keyboard:"
                freealien --dry-run touchpad 0050ff | grep -q "touchpad:"
                freealien --dry-run logo 0050ff | grep -q "lid logo:"
                freealien --dry-run power white orange | grep -q "all six power profiles:"
                freealien keys | grep -q "0x88"
                freealien install-udev | grep -q '187c.*0551'
                touch "$out"
              '';

          tests =
            let
              testPython = pkgs.python3.withPackages (ps: [
                ps.pytest
                ps.pyqt6
              ]);
            in
            pkgs.stdenvNoCC.mkDerivation {
              pname = "freealien-tests";
              version = "0.1.0";
              src = self;
              nativeBuildInputs = [ testPython ];
              dontBuild = true;
              doCheck = true;
              checkPhase = ''
                runHook preCheck
                export PYTHONDONTWRITEBYTECODE=1
                export QT_QPA_PLATFORM=offscreen
                pytest -q -p no:cacheprovider
                runHook postCheck
              '';
              installPhase = ''
                touch "$out"
              '';
            };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              pkgs.nixfmt
              pkgs.shellcheck
              (pkgs.python3.withPackages (ps: [
                ps.pytest
                ps.pyqt6
              ]))
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
