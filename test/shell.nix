{ np ? import <nixpkgs> {}, includeHello ? true, includeTiny ? false }: np.mkShell {
  name = "test-shell";
  packages = with np; ([ coreutils gnugrep diffutils python3 ]
    ++ np.lib.optional includeHello hello
    ++ np.lib.optional includeTiny tiny
  );
  shellHook = ''
    export PATH="foo:$PATH"
    echo yo

    source ${./vars.bash}
  '';
}
