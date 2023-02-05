# `use-nix-shell-action`

This action applies the environment of a nix shell to your GitHub Actions job.

This action works like [`workflow/nix-shell-action`](https://github.com/workflow/nix-shell-action) with one crucial difference: rather than only "applying" the provided shell to a script passed to the action's step, the shell is "applied" to the rest of the job.

This allows you to use `nix` to provide binaries that other GitHub Actions require and also allows you to run your action's steps in a nix shell without needing to wrap every step in a `nix-shell` action or bundle all your commands under one step.

## Example

> **Note**
> If `nix` isn't found, this action *will* handle installing `nix` for you using [`cachix/install-nix-action`](https://github.com/cachix/install-nix-action).
>
> However it's recommended that you run this action yourself.

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
      # To make the environment in your flake's devShell available to future
      # steps:
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

### Source

These options describe the shell that `use-nix-shell-action` should use.

> **Note**
> You can only specify **one** of these options.

  - `packages`: Comma-separated list of [packages](https://search.nixos.org/packages?) to install in your shell.
    + i.e. `packages: bash,python3,python3Packages.numpy`
      * spaces will be stripped so `bash, python3, python3Packages.numpy` works too
    + these packages are sourced from `<nixpkgs>`; see [`cachix/install-nix-action`](https://github.com/cachix/install-nix-action) for easy ways to influence this channel or consider using flakes
  - `flakes`: Comma-separated list of [flake references](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html#flake-references) to install in your shell.
    + i.e. `nixpkgs#hello, github:edolstra/nix-serve, .#myPackage`
  - `devShell`: Flake reference to a [devShell output](https://nixos.wiki/wiki/Flakes). <kbd>(default)</kbd>
    + i.e. `.#` or `github:NixOS/nix` or `some/path#someShell` or `.#devShells.x86_64-linux.someSpecialShell`
  - `file`: Path to a [nix file producing a shell](https://nixos.wiki/wiki/Development_environment_with_nix-shell).
    + i.e. `shell.nix`

### Export Options

  - `exportEnv`: Boolean specifying whether `use-nix-shell-action` should export the shell given to your environment.
    + defaults to <kbd>`true`</kbd>
  - `preserveDefaultPath`: Boolean controlling whether the shell's environment *overrides* `$PATH` in the job (`false`) or appends to it (`true`).
    + note: things added to `$GITHUB_PATH` (i.e. by other actions) will be preserved regardless
    + defaults to <kbd>`true`</kbd>

### Script Options

  <!-- + TODO: I don't think this will actually work?
  + TODO: what does GITHUB_ENV actually let us do?
  + TODO: lower to `-i` if using `nix develop`
  + If you're looking for actual purity probably use `script` -->



### Other options

  - `extraNixOptions`: Escape hatch that you can use to specify extra flags to be passed to the command producing the shell.
    + for example `--impure` or extra [`--option`s](https://nixos.org/manual/nix/stable/command-ref/conf-file.html?highlight=nix.conf)
    + see the options for [`nix print-dev-env`](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-print-dev-env.html#options) and [`nix shell`](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-shell.html)

<!-- TODO: pass flake args (--experimental) -->
<!-- TODO: warn about needing bash (?) -->

## FAQ

#### Does this work on self-hosted runners?

Yes!

#### Are bash functions set in the shell preserved?

Nope, sorry. Just regular (non-array) env vars. Anything that `env` prints out.

Note that this also does not preserve the `readonly` property of env vars.

#### How does this work?

Essentially just constructs a nix shell, [one way](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-print-dev-env.html) or [another](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-shell.html), and then dumps the contents of `env` into [`$GITHUB_ENV`](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-environment-variable).

We reuse [this logic from `nix-direnv`](https://github.com/nix-community/nix-direnv/blob/75c74a090bf37f34cd92eeab7f22f17dc0fcd48f/direnvrc#L83-L126).

