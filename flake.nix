{
  description = "An emacs exporter for LWN-compatible HTML";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils.url = "github:numtide/flake-utils";
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { flake-parts, flake-utils, devshell, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devshell.flakeModule
      ];

      systems = flake-utils.lib.defaultSystems;

      perSystem = { pkgs, ... }: {
        devshells.default = {
          packages = with pkgs; [
            emacs
            just
          ];
        };
      };
    };
}
