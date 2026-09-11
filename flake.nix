{
  description = "Always up-to-date Nix package for perles, a terminal UI for beads issue tracking";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  nixConfig = {
    extra-substituters = [ "https://perles-nix.cachix.org" ];
    extra-trusted-public-keys = [
      "perles-nix.cachix.org-1:33DY5Dd6f0ESCPzpkqe3IsTvVlN5GzfafZwk7lrTzGI="
    ];
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-darwin"
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};

      version = (lib.importJSON ./sources.json).version;
    in
    {
      overlays.default = final: _prev: {
        perles = final.callPackage ./package.nix { };
      };

      packages = forAllSystems (
        system:
        let
          perles = (pkgsFor system).callPackage ./package.nix { };
        in
        {
          inherit perles;
          default = perles;
        }
      );

      apps = forAllSystems (system: rec {
        perles = {
          type = "app";
          program = lib.getExe self.packages.${system}.perles;
        };
        default = perles;
      });

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          inherit (self.packages.${system}) perles;

          perles-smoke =
            pkgs.runCommand "perles-smoke" { nativeBuildInputs = [ self.packages.${system}.perles ]; }
              ''
                perles --version | tee version.txt
                grep -qF "${version}" version.txt
                perles --help | grep -qF "beads"
                mv version.txt $out
              '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              curl
              gh
              jq
              nixfmt
              shellcheck
            ];
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
