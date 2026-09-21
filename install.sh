#!/usr/bin/env bash
#
# Install the quality-gate skill, and optionally Cloudflare's security-audit skill
# alongside it.
#
#   curl -fsSL https://raw.githubusercontent.com/captainkie/agent-quality-skills/main/install.sh | bash
#
# or, from a clone:
#
#   ./install.sh                 # both skills, user scope
#   ./install.sh --gate-only     # skip the security-audit fetch (no network needed)
#   ./install.sh --project       # install into ./.claude/skills instead of ~/.claude/skills
#   ./install.sh --dir <path>    # install into an explicit directory
#
# Idempotent: re-running updates in place. Nothing outside the chosen skills
# directory is written, and no shell profile is modified.

set -euo pipefail

AUDIT_REPO="https://github.com/cloudflare/security-audit-skill"
AUDIT_SKILL_PATH="skills/security-audit"

GATE_ONLY=0
DEST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --gate-only) GATE_ONLY=1 ;;
    --project)   DEST="$(pwd)/.claude/skills" ;;
    --dir)       shift; DEST="${1:-}" ;;
    -h|--help)   sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

# Default to the user scope. `CLAUDE_CONFIG_DIR` is honoured when the host sets it.
if [ -z "$DEST" ]; then
  DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
fi

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Where this script lives — used when running from a clone rather than a pipe.
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

mkdir -p "$DEST"

# ── 1. the quality gate ──────────────────────────────────────────────────────
if [ -n "$SRC" ] && [ -d "$SRC/skills/quality-gate" ]; then
  say "→ quality-gate  (from this clone)"
  rm -rf "$DEST/quality-gate"
  cp -R "$SRC/skills/quality-gate" "$DEST/quality-gate"
else
  command -v git >/dev/null 2>&1 || die "git is required to install from the network"
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  say "→ quality-gate  (cloning)"
  git clone --depth 1 --quiet https://github.com/captainkie/agent-quality-skills "$TMP/repo" \
    || die "could not clone agent-quality-skills"
  rm -rf "$DEST/quality-gate"
  cp -R "$TMP/repo/skills/quality-gate" "$DEST/quality-gate"
fi

# ── 2. Cloudflare's security-audit skill, fetched from upstream ──────────────
#
# Fetched rather than vendored, deliberately: it stays current, and its MIT licence
# and attribution travel with the files instead of being restated second-hand here.
if [ "$GATE_ONLY" -eq 0 ]; then
  if ! command -v git >/dev/null 2>&1; then
    say "!  git not found — skipping security-audit. Re-run with git installed, or use --gate-only."
  else
    AUDIT_TMP="$(mktemp -d)"
    # Announce AFTER the clone lands, and name the repo actually used — an
    # up-front "installed (MIT)" is a claim the next two lines can contradict.
    if git clone --depth 1 --quiet "$AUDIT_REPO" "$AUDIT_TMP/audit" 2>/dev/null; then
      if [ -d "$AUDIT_TMP/audit/$AUDIT_SKILL_PATH" ]; then
        rm -rf "$DEST/security-audit"
        cp -R "$AUDIT_TMP/audit/$AUDIT_SKILL_PATH" "$DEST/security-audit"
        # Keep the licence with the files it covers.
        [ -f "$AUDIT_TMP/audit/LICENSE" ] && cp "$AUDIT_TMP/audit/LICENSE" "$DEST/security-audit/LICENSE"
        say "→ security-audit  ($AUDIT_REPO, MIT)"
      else
        say "!  upstream layout changed — '$AUDIT_SKILL_PATH' not found. Skipped."
        say "   Install it yourself from $AUDIT_REPO and the gate will still find it."
      fi
    else
      say "!  could not reach $AUDIT_REPO — skipped."
      say "   The gate works without it; its security axis just loses the domain references."
    fi
    rm -rf "$AUDIT_TMP"
  fi
fi

say ""
say "installed into: $DEST"
ls -1 "$DEST" | sed 's/^/  /'
say ""
say "Next: copy templates/QUALITY-GATE.md into your repo root and fill it in (optional)."
