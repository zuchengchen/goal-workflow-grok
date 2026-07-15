#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SOURCE_DIR="$REPO_ROOT/skills/goal-workflow"
VALIDATOR="$SCRIPT_DIR/validate.py"

rename_path() {
  python3 -c 'import os, sys; os.rename(sys.argv[1], sys.argv[2])' "$1" "$2"
}

usage() {
  printf '%s\n' \
    "Usage: scripts/install-local.sh [--dest PATH] [--replace]" \
    "" \
    "Install the canonical goal-workflow skill from this checkout." \
    "" \
    "Options:" \
    "  --dest PATH  Destination (default: \${GROK_HOME:-\$HOME/.grok}/skills/goal-workflow)" \
    "  --replace    Transactionally replace an existing installation (no backup retained)" \
    "  -h, --help   Show this help"
}

DEST=""
REPLACE=0
while (($#)); do
  case "$1" in
    --dest)
      if (($# < 2)); then
        printf 'ERROR: --dest requires a path\n' >&2
        exit 2
      fi
      DEST=$2
      shift 2
      ;;
    --replace)
      REPLACE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$DEST" ]]; then
  if [[ -n "${GROK_HOME:-}" ]]; then
    DEST="$GROK_HOME/skills/goal-workflow"
  elif [[ -n "${HOME:-}" ]]; then
    DEST="$HOME/.grok/skills/goal-workflow"
  else
    printf 'ERROR: neither GROK_HOME nor HOME is set; use --dest\n' >&2
    exit 2
  fi
fi

if [[ "$(basename "$DEST")" != "goal-workflow" ]]; then
  printf 'ERROR: destination directory must be named goal-workflow: %s\n' "$DEST" >&2
  exit 2
fi
if [[ ! -d "$SOURCE_DIR" ]]; then
  printf 'ERROR: canonical skill is missing: %s\n' "$SOURCE_DIR" >&2
  exit 1
fi
if [[ -L "$DEST" ]]; then
  printf 'ERROR: refusing to replace a symbolic-link destination: %s\n' "$DEST" >&2
  exit 1
fi

DEST_PARENT="$(dirname "$DEST")"
if [[ "$DEST_PARENT" == "/" || "$(basename "$DEST_PARENT")" != "skills" ]]; then
  printf 'ERROR: destination must be directly inside a non-root skills directory: %s\n' "$DEST" >&2
  exit 2
fi
python3 "$VALIDATOR" --skill-dir "$SOURCE_DIR" --installed-only >/dev/null

mkdir -p "$DEST_PARENT"
DEST_PARENT="$(cd "$DEST_PARENT" && pwd -P)"
DEST="$DEST_PARENT/goal-workflow"
if [[ "$DEST_PARENT" == "/" || "$(basename "$DEST_PARENT")" != "skills" ]]; then
  printf 'ERROR: destination must be directly inside a non-root skills directory: %s\n' "$DEST" >&2
  exit 2
fi
if [[ -L "$DEST" ]]; then
  printf 'ERROR: refusing to replace a symbolic-link destination: %s\n' "$DEST" >&2
  exit 1
fi

if [[ -e "$DEST" && $REPLACE -eq 0 ]]; then
  printf 'ERROR: destination already exists; rerun with --replace: %s\n' "$DEST" >&2
  exit 1
fi
if [[ -e "$DEST" && ! -d "$DEST" ]]; then
  printf 'ERROR: destination exists but is not a directory: %s\n' "$DEST" >&2
  exit 1
fi
if [[ -e "$DEST" && $REPLACE -eq 1 ]]; then
  if ! python3 "$VALIDATOR" --skill-dir "$DEST" --identity-only >/dev/null; then
    printf 'ERROR: refusing to replace a directory that is not the goal-workflow skill: %s\n' "$DEST" >&2
    exit 1
  fi
fi

STAGE_ROOT=""
OLD_PATH=""
OLD_MOVED=0
COMMITTED=0
cleanup() {
  local status=$?
  trap - EXIT
  if [[ $status -ne 0 && $OLD_MOVED -eq 1 && $COMMITTED -eq 0 ]]; then
    if [[ ! -e "$DEST" && -n "$OLD_PATH" && -e "$OLD_PATH" ]]; then
      if ! rename_path "$OLD_PATH" "$DEST"; then
        printf 'ERROR: install failed and rollback also failed; recover from %s\n' "$OLD_PATH" >&2
      fi
    elif [[ -n "$OLD_PATH" && -e "$OLD_PATH" ]]; then
      printf 'ERROR: install failed after moving the previous installation; recover from %s\n' "$OLD_PATH" >&2
    fi
  fi
  if [[ $COMMITTED -eq 1 && -n "$OLD_PATH" && -e "$OLD_PATH" ]]; then
    rm -rf "$OLD_PATH"
  fi
  if [[ -n "$STAGE_ROOT" && -d "$STAGE_ROOT" ]]; then
    rm -rf "$STAGE_ROOT"
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

STAGE_ROOT="$(mktemp -d "$DEST_PARENT/.goal-workflow.install.XXXXXX")"
STAGED_SKILL="$STAGE_ROOT/goal-workflow"
mkdir "$STAGED_SKILL"
cp -R "$SOURCE_DIR/." "$STAGED_SKILL/"
python3 "$VALIDATOR" --skill-dir "$STAGED_SKILL" --installed-only >/dev/null

if [[ -e "$DEST" ]]; then
  # Temporary side path for atomic swap only; deleted after a successful replace.
  OLD_PATH="$(mktemp -d "$DEST_PARENT/.goal-workflow.replace-old.XXXXXX")"
  rmdir "$OLD_PATH"
  rename_path "$DEST" "$OLD_PATH"
  OLD_MOVED=1
fi

rename_path "$STAGED_SKILL" "$DEST"
COMMITTED=1

printf 'Installed goal-workflow at %s\n' "$DEST"
if [[ $OLD_MOVED -eq 1 ]]; then
  printf 'Previous installation replaced (no backup retained)\n'
fi
