# perles-nix

Nix flake for [perles](https://github.com/zjrosen/perles) — a terminal UI for
[beads](https://github.com/steveyegge/beads) issue tracking. Tracks upstream
releases hourly and lands each one only after it builds and runs on Linux and macOS.

Packages the binaries upstream publishes for each release, not a from-source
rebuild, so this is byte-identical to `install.sh`.

## Use it

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    perles-nix = {
      url = "github:AodhanHayter/perles-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

Then either take the package directly:

```nix
environment.systemPackages = [
  inputs.perles-nix.packages.${pkgs.stdenv.hostPlatform.system}.perles
];
```

or apply the overlay and use `pkgs.perles` anywhere:

```nix
nixpkgs.overlays = [ inputs.perles-nix.overlays.default ];
```

Pin to a release with `?ref=v0.8.94`, or to the newest verified build with `?ref=latest`.

### Try it without installing

```sh
nix run github:AodhanHayter/perles-nix
```

## What the package does

| | |
|---|---|
| Binary | `perles` |
| Completions | bash, zsh and fish, generated from the binary at build time |
| Updates | the store is read-only, so `perles update` is a no-go — bump this flake instead |
| Platforms | `x86_64-darwin`, `aarch64-darwin`, `x86_64-linux`, `aarch64-linux` |

Upstream builds with `CGO_ENABLED=0`, so the binaries are static and need no patching.

perles needs a project with a `.beads/` directory and the `bd` (or `br`) binary
on `PATH`; neither is packaged here.

## Binary cache

CI pushes every built path to [Cachix](https://app.cachix.org/cache/perles-nix).
Substituting it skips the upstream download and the completion-generation build:

```nix
nix.settings = {
  substituters = [ "https://perles-nix.cachix.org" ];
  trusted-public-keys = [ "perles-nix.cachix.org-1:33DY5Dd6f0ESCPzpkqe3IsTvVlN5GzfafZwk7lrTzGI=" ];
};
```

Non-NixOS: the same two keys in `~/.config/nix/nix.conf`, or `cachix use perles-nix`.

CI needs `CACHIX_AUTH_TOKEN` (a write token) as a repo secret.

## Automation

| Workflow | Trigger | What it does |
|---|---|---|
| `update.yml` | hourly | Reads the latest GitHub release. On a new version: pins every platform hash, runs `nix flake check` on ubuntu-latest, ubuntu-24.04-arm and macos-latest, and only then commits to `master` and tags `v<version>` + moves `latest` |
| `ci.yml` | push / PR | `nix flake check` on the same matrix |

### Updating by hand

```sh
./scripts/update-version.sh                  # sync to the latest release, then verify the build
./scripts/update-version.sh --check          # report only, changes nothing
./scripts/update-version.sh --version 0.8.94 # pin a specific version
```

`sources.json` is the only file a version bump touches: the version and one SRI
hash per platform.

## Licensing

perles is MIT (see [zjrosen/perles](https://github.com/zjrosen/perles)); this
package installs the binaries built from it and marks it
`sourceProvenance = binaryNativeCode`. The Nix expressions here are MIT.
