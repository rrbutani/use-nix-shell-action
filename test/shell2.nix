{ np ? import <nixpkgs> {} }:
  import ./shell.nix { inherit np; includeHello = false; includeTiny = true; }
