{ }:
let
  pkgs = import (builtins.fetchGit {
    url = "https://github.com/dapphub/dapptools";
    ref = "hevm/0.41.0";
    rev = "34b2799a26623464c4ab8b7900c6b268adf7d36f";
  }) {};
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    dapp
    bashInteractive
  ];
}
