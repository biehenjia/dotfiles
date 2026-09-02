{
  description = "project devshell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # The package list lives in packages.nix so `proj add` / `proj remove`
      # only ever edit a flat Nix list — this file stays untouched after init.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = import ./packages.nix { inherit pkgs; };
        };
      });
    };
}
