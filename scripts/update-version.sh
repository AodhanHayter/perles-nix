#!/usr/bin/env bash
#
# Sync sources.json to the newest perles GitHub release.
#
#   update-version.sh                 # update to latest, then verify the build
#   update-version.sh --check         # print current/latest/update as key=value, change nothing
#   update-version.sh --version X.Y.Z # pin a specific version
#   update-version.sh --no-verify     # skip the `nix build` check
#
# --check writes GITHUB_OUTPUT-shaped lines and always exits 0, so CI can do:
#   ./scripts/update-version.sh --check >> "$GITHUB_OUTPUT"

set -euo pipefail

readonly REPO="zjrosen/perles"
readonly SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9._]+)?$'

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SOURCES="$repo_root/sources.json"

log() { printf '\033[0;32m[update]\033[0m %s\n' "$1" >&2; }
die() {
  printf '\033[0;31m[error]\033[0m %s\n' "$1" >&2
  exit 1
}

require_tools() {
  local missing=""
  for tool in curl jq nix; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
  done
  [ -z "$missing" ] || die "missing required tools:$missing"
  [ -f "$SOURCES" ] || die "sources.json not found at $SOURCES"
}

latest_version() {
  local tag
  tag=$(curl -fsSL --max-time 20 --retry 3 \
    "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name') ||
    die "could not read latest release of $REPO"
  printf '%s' "${tag#v}"
}

update_to() {
  local version="$1" platform hash platform_list
  local platforms_json='{}'

  # Read the list up front: a failing jq behind a process substitution would run
  # the loop zero times and silently write back an empty platform map.
  platform_list=$(jq -r '.platforms | keys[]' "$SOURCES") ||
    die "could not read .platforms from $SOURCES"
  [ -n "$platform_list" ] || die ".platforms in $SOURCES is empty"

  log "fetching artifact hashes for $version..."
  while read -r platform; do
    hash=$(nix store prefetch-file --json \
      "https://github.com/$REPO/releases/download/v$version/perles_${version}_${platform}.tar.gz" |
      jq -r '.hash') || die "no artifact for $platform at version $version"
    log "  $platform  $hash"
    platforms_json=$(jq -c --arg k "$platform" --arg v "$hash" '.[$k] = $v' <<<"$platforms_json")
  done <<<"$platform_list"

  local tmp
  tmp="$(mktemp)"
  jq --arg v "$version" --argjson p "$platforms_json" \
    '.version = $v | .platforms = $p' "$SOURCES" >"$tmp"
  mv "$tmp" "$SOURCES"
  log "sources.json updated to $version"
}

main() {
  local target="" check_only=false verify=true

  while (($# > 0)); do
    case "$1" in
      --check)
        check_only=true
        shift
        ;;
      --version)
        [ $# -ge 2 ] || die "--version needs an argument"
        target="${2#v}"
        shift 2
        ;;
      --no-verify)
        verify=false
        shift
        ;;
      -h | --help)
        sed -n '3,11p' "${BASH_SOURCE[0]}" | sed 's/^#[[:space:]]\{0,1\}//'
        exit 0
        ;;
      *) die "unknown option: $1" ;;
    esac
  done

  require_tools

  local current latest
  current="$(jq -r '.version' "$SOURCES")"
  if [ -n "$target" ]; then
    [[ "$target" =~ $SEMVER_RE ]] || die "invalid version: $target"
    latest="$target"
  else
    latest="$(latest_version)"
    [[ "$latest" =~ $SEMVER_RE ]] || die "latest release tag '$latest' is not a version"
  fi

  if [ "$check_only" = true ]; then
    local update=false
    [ "$current" = "$latest" ] || update=true
    printf 'current=%s\nlatest=%s\nupdate=%s\n' "$current" "$latest" "$update"
    exit 0
  fi

  log "current=$current latest=$latest"
  if [ "$current" = "$latest" ]; then
    log "already up to date"
    exit 0
  fi

  update_to "$latest"
  if [ "$verify" = true ]; then
    log "verifying: nix build .#perles"
    (cd "$repo_root" && nix build .#perles --no-link --print-build-logs) ||
      die "build verification failed"
    log "build ok"
  fi
  log "perles $current -> $latest"
}

main "$@"
