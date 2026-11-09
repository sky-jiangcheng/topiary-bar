#!/usr/bin/env bash
set -euo pipefail

# Upload the MAS package to App Store Connect.
#
# What this replaces: an inline `if xcrun --find iTMSTransporter && xcrun
# iTMSTransporter -m upload …  || fallback to altool`. Measured on macOS 27.2 +
# Xcode 27.2 (no Transporter.app installed):
#
#   xcrun --find iTMSTransporter -> Xcode.app/Contents/Developer/usr/bin/iTMSTransporter
#   that binary with -m upload   -> prints "iTMSTransporter is now part of
#                                    Transporter … install it" and exits 1
#   the same binary with -version-> the same notice, but exits 0
#
# So the old fallback did fire for `-m upload` (by design since 09ce8ef), and
# this script is NOT fixing a live silent-success bug. What it does fix:
#
#   1. The stub can never upload anything, on either machine. Running it on
#      every release just to lose to a misleading error is the reason
#      `iTMSTransporter` is only used when a real Transporter.app is present.
#      On GitHub runners the same stub dies with OSStatus -10814 (LaunchServices
#      cannot find Transporter) - one scary log line per release, zero uploads.
#   2. The old code treated "exit 0" as proof that a build reached App Store
#      Connect. `-version` already shows that assumption is fragile for this
#      binary family, so success is now decided by the uploader's own evidence
#      lines (measured wording: "No errors uploading", "UPLOAD SUCCEEDED",
#      "Delivery UUID:") and a clean exit with no evidence fails.
#   3. A non-zero exit no longer silently reroutes: it fails the job, so an
#      authentication problem cannot masquerade as "the other uploader's error".
#
# ⚑ The Transporter branch is unmeasured here (this machine has no
#   Transporter.app); its success wording comes from Apple's documented output.
#   The altool branch IS measured, against this project's v1.28.2 runner log.
#
# Usage: asc-upload.sh <package.pkg>
# Environment: API_KEY_ID, API_ISSUER_ID (required)
#              TRANSPORTER_BIN - override the Transporter binary path (also used
#                                by the tests to drive both branches)

PKG="${1:?usage: asc-upload.sh <package.pkg>}"
: "${API_KEY_ID:?API_KEY_ID is required}"
: "${API_ISSUER_ID:?API_ISSUER_ID is required}"

if [ ! -f "$PKG" ]; then
  echo "asc-upload: package not found: $PKG" >&2
  exit 1
fi

TRANSPORTER=""
for candidate in "${TRANSPORTER_BIN:-}" \
                 "/Applications/Transporter.app/Contents/MTIFramework/usr/bin/iTMSTransporter"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    TRANSPORTER="$candidate"
    break
  fi
done

if [ -n "$TRANSPORTER" ]; then
  echo "asc-upload: using Transporter at $TRANSPORTER"
  UPLOADER=("$TRANSPORTER" -m upload -assetFile "$PKG" \
            -apiKey "$API_KEY_ID" -apiIssuer "$API_ISSUER_ID")
else
  # Not probing `xcrun iTMSTransporter` at all: a stub that only prints an
  # install notice is indistinguishable from a working uploader by exit code.
  echo "asc-upload: Transporter.app absent — using altool (deprecated but the only uploader measured to work on this runner)"
  UPLOADER=(xcrun altool --upload-app --type macos --file "$PKG" \
            --apiKey "$API_KEY_ID" --apiIssuer "$API_ISSUER_ID")
fi

OUTPUT="$("${UPLOADER[@]}" 2>&1)" && RC=0 || RC=$?
printf '%s\n' "$OUTPUT"

if [ "$RC" -ne 0 ]; then
  echo "asc-upload: uploader exited $RC — failing the release instead of falling back" >&2
  exit "$RC"
fi

# Exit code 0 is not proof of an upload, so look for the uploader's own success
# lines. altool's wording is from this project's v1.28.2 runner log.
if printf '%s' "$OUTPUT" | grep -qE "UPLOAD SUCCEEDED|No errors uploading|Delivery UUID:|successfully completed|Upload Succeeded"; then
  echo "asc-upload: upload evidence found"
else
  echo "asc-upload: uploader exited 0 but showed no upload evidence — treating as failure" >&2
  echo "asc-upload: did the CLI turn into a notice-only stub again?" >&2
  exit 1
fi
