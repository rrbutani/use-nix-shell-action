# `use-nix-shell-action`

This action applies the environment of a nix shell to your GitHub Actions job.

This action works like [`workflow/nix-shell-action`](https://github.com/workflow/nix-shell-action) with one crucial difference: rather than only "applying" the provided shell to a script passed to the action's step, the shell is "applied" to the rest of the job.

This allows you to use `nix` to provide binaries that other GitHub Actions require and also allows you to run your action's steps in a nix shell without needing to wrap every step in a `nix-shell` action or bundle all your commands under one step.

## Example

> **Note**
> This action does *not* handle installing `nix` for you; see [`cachix/install-nix-action`](https://github.com/cachix/install-nix-action).

```yaml
name: "Test"
on: [push]
jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      - uses: cachix/install-nix-action@v18
        with:
          nix_path: nixpkgs=channel:nixos-unstable
      - name: Print env, before
        run: env
      - uses: rrbutani/use-nix-shell-action@master
        with:
          devShell: .#default # this is the default
      - name: Print env, after
        run: env
      - name: Run hello
        run: hello
      - name: Print env var
        run: echo $SOME_ENV_VAR
```

## Options (`with: ...`)

##### Source

These options describe the shell that `use-nix-shell-action` should use.

> **Note**
> You can only specify **one** of these options.

  - `packages`: Comma-separated list of packages to install in your shell.
    + i.e. `packages: bash,python3,python3Packages.numpy`
      * spaces will be stripped so `bash, python3, python3Packages.numpy` works too
    + these packages are sourced from `<nixpkgs>`; see [`cachix/install-nix-action`](https://github.com/cachix/install-nix-action) for easy ways to influence this channel or consider using flakes
  - `flakes`: Comma-separated list of [flake references](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html#flake-references) to install in your shell.
    + i.e. `nixpkgs#hello, github:edolstra/nix-serve, .#myPackage`
  - `devShell`: Flake reference to a devShell output. <kbd>(default)</kbd>
    + i.e. `.#` or `github:NixOS/nix` or `some/path#someShell` or `.#devShells.x86_64-linux.someSpecialShell`
  - `file`: Path to a nix file producing a shell.
    + i.e. `shell.nix`

<!-- TODO: pass flake args (--experimental) -->
<!-- TODO: warn about needing bash (?) -->

## FAQ

TODO: shellcheck in CI
