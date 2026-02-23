{
  description = "Pi Mono - coding agent monorepo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      nodejs = pkgs.nodejs_22;
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = [
          nodejs
          pkgs.git
        ];

        shellHook = ''
          echo "Pi Mono Dev Shell (Node $(node --version))"

          if [ ! -d node_modules ]; then
            echo "Installing dependencies..."
            npm install --no-audit --no-fund
          fi
        '';
      };
    });
}
