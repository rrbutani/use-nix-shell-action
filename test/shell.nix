{ np ? import <nixpkgs> {} }: np.mkShell {
  name = "test-shell";
  packages = with np; [ coreutils gnugrep diffutils hello  ];
  shellHook = ''
    export PATH="foo:$PATH"
    echo yo

    source ${./vars.bash}
  '';
}
