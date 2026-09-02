{
  description = "biehenjia/dotfiles — nix flake templates";

  # No inputs: this flake only ships templates. The devshell template carries
  # its own nixpkgs input, which is what actually gets locked per project.
  outputs = { self }: {
    templates.devshell = {
      path = ./templates/devshell;
      description = "per-project nix devshell (packages.nix + direnv sandbox)";
    };
    templates.default = self.templates.devshell;
  };
}
