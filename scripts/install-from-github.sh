#!/usr/bin/env bash
# Install or update goal-workflow from a GitHub (or local git) repository URL.
# Intended for Grok: user says "安装 skill <url>" or "更新 skill <url>".
set -euo pipefail

DEFAULT_REPO_URL="https://github.com/zuchengchen/goal-workflow-grok"
DEFAULT_REF="master"
SKILL_NAME="goal-workflow"

rename_path() {
  python3 -c 'import os, sys; os.rename(sys.argv[1], sys.argv[2])' "$1" "$2"
}

usage() {
  printf '%s\n' \
    "Usage: scripts/install-from-github.sh <install|update> [REPO_URL] [options]" \
    "" \
    "Clone REPO_URL, then install skills/${SKILL_NAME}/ into a Grok skills directory." \
    "" \
    "Modes:" \
    "  install   Fresh install (fails if destination already exists)" \
    "  update    Replace an existing install and keep a backup" \
    "" \
    "Arguments:" \
    "  REPO_URL  Default: ${DEFAULT_REPO_URL}" \
    "            Accepts repo root, .git URL, or .../tree/<ref>/... path" \
    "" \
    "Options:" \
    "  --dest PATH  Destination (default: \${GROK_HOME:-\$HOME/.grok}/skills/${SKILL_NAME})" \
    "  --ref REF    Git ref when not encoded in the URL (default: ${DEFAULT_REF})" \
    "  -h, --help   Show this help"
}

normalize_repo() {
  local raw=$1
  raw="${raw%%#*}"
  raw="${raw%/}"
  raw="${raw%.git}"
  # Strip GitHub tree/blob paths: .../tree/<ref>/... or .../blob/<ref>/...
  if [[ "$raw" =~ ^(https?://github\.com/[^/]+/[^/]+)/(tree|blob)/([^/]+)(/.*)?$ ]]; then
    REPO_URL="${BASH_REMATCH[1]}"
    REF="${BASH_REMATCH[3]}"
  elif [[ "$raw" =~ ^(git@github\.com:[^/]+/[^/]+)/(tree|blob)/([^/]+)(/.*)?$ ]]; then
    REPO_URL="${BASH_REMATCH[1]}"
    REF="${BASH_REMATCH[3]}"
  else
    REPO_URL=$raw
  fi
}

MODE=""
REPO_URL=""
REF="$DEFAULT_REF"
DEST=""
EXPLICIT_REF=0

while (($#)); do
  case "$1" in
    install|update)
      if [[ -n "$MODE" ]]; then
        printf 'ERROR: mode already set to %s\n' "$MODE" >&2
        exit 2
      fi
      MODE=$1
      shift
      ;;
    --dest)
      if (($# < 2)); then
        printf 'ERROR: --dest requires a path\n' >&2
        exit 2
      fi
      DEST=$2
      shift 2
      ;;
    --ref)
      if (($# < 2)); then
        printf 'ERROR: --ref requires a value\n' >&2
        exit 2
      fi
      REF=$2
      EXPLICIT_REF=1
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    https://*|http://*|git@*|/*|file://*)
      if [[ -n "$REPO_URL" ]]; then
        printf 'ERROR: REPO_URL already set\n' >&2
        exit 2
      fi
      normalize_repo "$1"
      shift
      ;;
    *)
      if [[ -z "$REPO_URL" && "$1" != -* ]]; then
        normalize_repo "$1"
        shift
      else
        printf 'ERROR: unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 2
      fi
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  printf 'ERROR: specify install or update\n' >&2
  usage >&2
  exit 2
fi

if [[ -z "$REPO_URL" ]]; then
  REPO_URL=$DEFAULT_REPO_URL
fi

if [[ -z "$DEST" ]]; then
  if [[ -n "${GROK_HOME:-}" ]]; then
    DEST="$GROK_HOME/skills/$SKILL_NAME"
  elif [[ -n "${HOME:-}" ]]; then
    DEST="$HOME/.grok/skills/$SKILL_NAME"
  else
    printf 'ERROR: neither GROK_HOME nor HOME is set; use --dest\n' >&2
    exit 2
  fi
fi

if ! command -v git >/dev/null 2>&1; then
  printf 'ERROR: git is required\n' >&2
  exit 1
fi

CLONE_URL=$REPO_URL
if [[ "$CLONE_URL" == https://github.com/* || "$CLONE_URL" == http://github.com/* || "$CLONE_URL" == git@github.com:* ]]; then
  if [[ "$CLONE_URL" != *.git ]]; then
    CLONE_URL="${CLONE_URL}.git"
  fi
fi

STAGE_ROOT=""
cleanup() {
  local status=$?
  trap - EXIT
  if [[ -n "$STAGE_ROOT" && -d "$STAGE_ROOT" ]]; then
    rm -rf "$STAGE_ROOT"
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

STAGE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/goal-workflow.github.XXXXXX")"
SOURCE_DIR="$STAGE_ROOT/src"

printf 'Cloning %s (ref %s) ...\n' "$CLONE_URL" "$REF"
if ! git clone --depth 1 --branch "$REF" "$CLONE_URL" "$SOURCE_DIR" >/dev/null 2>&1; then
  # Fallback: clone default branch then checkout (shallow may not have the ref)
  rm -rf "$SOURCE_DIR"
  git clone --depth 1 "$CLONE_URL" "$SOURCE_DIR" >/dev/null
  if [[ $EXPLICIT_REF -eq 1 || "$REF" != "$DEFAULT_REF" ]]; then
    git -C "$SOURCE_DIR" fetch --depth 1 origin "$REF" >/dev/null 2>&1 || true
    git -C "$SOURCE_DIR" checkout --detach "$REF" >/dev/null
  fi
fi

INSTALLER="$SOURCE_DIR/scripts/install-local.sh"
if [[ ! -x "$INSTALLER" && -f "$INSTALLER" ]]; then
  chmod +x "$INSTALLER" "$SOURCE_DIR/scripts/"*.sh 2>/dev/null || true
fi
if [[ ! -f "$INSTALLER" ]]; then
  printf 'ERROR: repository is missing scripts/install-local.sh\n' >&2
  exit 1
fi
if [[ ! -f "$SOURCE_DIR/skills/$SKILL_NAME/SKILL.md" ]]; then
  printf 'ERROR: repository is missing skills/%s/SKILL.md\n' "$SKILL_NAME" >&2
  exit 1
fi

REPLACE_FLAG=()
if [[ "$MODE" == "update" ]]; then
  REPLACE_FLAG=(--replace)
fi

"$INSTALLER" --dest "$DEST" "${REPLACE_FLAG[@]+"${REPLACE_FLAG[@]}"}"

printf 'OK: goal-workflow %s at %s\n' "$MODE" "$DEST"
printf 'Use in Grok: /goal-workflow <task>\n'
