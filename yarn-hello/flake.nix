{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = { self, nixpkgs, flake-utils, nix-filter }:
    flake-utils.lib.eachDefaultSystem (system:
      with import nixpkgs { inherit system; };
      let
        project = pkgs.callPackage ./yarn-project.nix { } {
          src = nix-filter.lib {
            root = ./.;
            include = (map nix-filter.lib.inDirectory [ ".yarn" ])
              ++ [ ".yarnrc.yml" "package.json" "yarn.lock" ];
          };
        };
      in {
        defaultPackage = project.overrideAttrs (oldAttrs: {
          buildPhase = "yarn run build";
          installPhase = "mv public $out";
        });

        devShell = pkgs.mkShell { buildInputs = [ yarn ]; };
      });
}
