#!/usr/bin/env bash
set -euo pipefail

# Derives the MAS entitlements from the committed sandbox entitlements.
#
# App Store Connect wants the app's full code-signing identifier alongside the
# sandbox. Uploads without it come back as altool warning 90886, and the
# resulting builds can stall in TestFlight. The two keys are DERIVED here rather
# than hard-coded in topiary-bar.entitlements because both values already live
# elsewhere: BUNDLE_ID is what release.sh writes into Info.plist, and the team
# ID is the parenthesised suffix of the signing identity. Copying either into
# the plist would create a third place to keep in sync and would let a
# `vars.BUNDLE_ID` override silently produce an identifier the provisioning
# profile does not cover.
#
# Usage: mas-entitlements.sh <base.plist> <out.plist> <bundle-id> <signing-identity> [profile]
# Environment: TEAM_ID - overrides team parsing from the signing identity.
#
# Exits non-zero when the team ID cannot be determined, or when a readable
# provisioning profile covers a different identifier than the one we produce.

BASE="${1:?usage: mas-entitlements.sh <base> <out> <bundle-id> <signing-identity> [profile]}"
OUT="${2:?missing output path}"
BUNDLE_ID="${3:?missing bundle id}"
SIGNING_IDENTITY="${4:?missing signing identity}"
PROFILE="${5:-}"

if [ ! -f "$BASE" ]; then
  echo "mas-entitlements: base entitlements not found: $BASE" >&2
  exit 1
fi
if [ -z "$BUNDLE_ID" ]; then
  echo "mas-entitlements: empty bundle id" >&2
  exit 1
fi

# Apple team IDs are exactly 10 uppercase alphanumeric characters and every
# signing identity name ends with "(TEAMID)".
TEAM_ID="${TEAM_ID:-$(printf '%s' "$SIGNING_IDENTITY" | sed -nE 's/.* \(([A-Z0-9]{10})\)$/\1/p')}"
if [ -z "$TEAM_ID" ]; then
  echo "mas-entitlements: cannot read a 10-character Team ID from SIGNING_IDENTITY='$SIGNING_IDENTITY'." >&2
  echo "mas-entitlements: pass TEAM_ID=<TEAMID> to override." >&2
  exit 1
fi

EXPECTED="$TEAM_ID.$BUNDLE_ID"

cp "$BASE" "$OUT"
# plutil reads dots in a key path as separators, so both key names are escaped.
plutil -replace 'com\.apple\.application-identifier' -string "$EXPECTED" "$OUT"
plutil -replace 'com\.apple\.developer\.team-identifier' -string "$TEAM_ID" "$OUT"
plutil -lint "$OUT" >/dev/null
# Read the file back: a silently missing key here is exactly the defect this
# script exists to fix, so verify rather than trust the write.
APPLIED_ID="$(plutil -extract 'com\.apple\.application-identifier' raw -o - "$OUT")"
APPLIED_TEAM="$(plutil -extract 'com\.apple\.developer\.team-identifier' raw -o - "$OUT")"
if [ "$APPLIED_ID" != "$EXPECTED" ] || [ "$APPLIED_TEAM" != "$TEAM_ID" ]; then
  echo "mas-entitlements: wrote $OUT but read back id='$APPLIED_ID' team='$APPLIED_TEAM' (expected '$EXPECTED' / '$TEAM_ID')" >&2
  exit 1
fi

# Cross-check against the profile when one is readable. This check exists to
# explain an incoming failure, not to invent one: an unreadable or incomplete
# profile is reported and skipped.
if [ -n "$PROFILE" ] && [ -f "$PROFILE" ]; then
  PROFILE_XML="$(security cms -D -i "$PROFILE" 2>/dev/null || true)"
  if [ -z "$PROFILE_XML" ]; then
    echo "mas-entitlements: WARNING profile at $PROFILE is unreadable, identifier not cross-checked" >&2
  else
    # Quoted: an unquoted path here loses the backslashes to the shell, plutil
    # then reads the dots as separators, the lookup comes back empty and this
    # check silently degrades to "not cross-checked".
    PROFILE_ID="$(printf '%s' "$PROFILE_XML" \
      | plutil -extract 'Entitlements.com\.apple\.application-identifier' raw -o - - 2>/dev/null || true)"
    if [ -z "$PROFILE_ID" ]; then
      echo "mas-entitlements: WARNING profile carries no application-identifier, not cross-checked" >&2
    elif [ "$PROFILE_ID" != "$EXPECTED" ] && [ "$PROFILE_ID" != "$TEAM_ID.*" ]; then
      echo "mas-entitlements: profile covers '$PROFILE_ID', which matches neither '$EXPECTED'" >&2
      echo "mas-entitlements: nor the wildcard '$TEAM_ID.*' — check vars.BUNDLE_ID against the" >&2
      echo "mas-entitlements: App Store record and this provisioning profile." >&2
      exit 1
    else
      echo "mas-entitlements: $EXPECTED (profile: $PROFILE_ID)" >&2
    fi
  fi
else
  echo "mas-entitlements: $EXPECTED (no profile supplied, identifier not cross-checked)" >&2
fi

printf '%s\n' "$EXPECTED"
