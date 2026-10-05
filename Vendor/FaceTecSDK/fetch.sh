#!/usr/bin/env bash
#
# Fetches the FaceTec SDK xcframeworks from the private vendor-swift-packages
# GitHub Release and unzips them into Frameworks/.
#
# The API endpoint needs the asset's numeric
# ID rather than its name, so we look that up first via the release-by-tag
# call.
#
# To provide the Github Personal Access Token (PAT) that has read
# access to sirosfoundation/vendor-swift-packages, there are 2 ways:
#
# 1. environment variable `$GITHUB_PAT`.
# 2. A `machine github.com` entry in ~/.netrc with a PAT, e.g.:
#
#   machine github.com
#   login <your-github-username>
#   password <your-PAT>
#
set -euo pipefail

cd "$(dirname "$0")"

REPO="sirosfoundation/vendor-swift-packages"
RELEASE_TAG="facetec-10.1.17"

if [ -n "${GITHUB_PAT:-}" ]; then
    echo "Using GITHUB_PAT from environment..."
    PAT="$GITHUB_PAT"
else
    echo "GITHUB_PAT not found in environment, checking ~/.netrc..."
    PAT=$(awk '/machine github\.com/{f=1} f && /password/{print $2; exit}' ~/.netrc 2>/dev/null || true)
fi

if [ -z "${PAT:-}" ]; then
    echo "error: No GitHub PAT found in environment variable GITHUB_PAT or in ~/.netrc" >&2
    exit 1
fi

echo "Looking up release ${RELEASE_TAG}..."
RELEASE_JSON=$(curl -fsL -H "Authorization: Bearer ${PAT}" \
    "https://api.github.com/repos/${REPO}/releases/tags/${RELEASE_TAG}")

rm -rf Frameworks
mkdir -p Frameworks
cd Frameworks

for FRAMEWORK in FaceTecSDK FaceTecSDKForDevelopment; do
    ASSET_NAME="${FRAMEWORK}.xcframework.zip"

    ASSET_ID=$(printf '%s' "${RELEASE_JSON}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for a in data['assets']:
    if a['name'] == '${ASSET_NAME}':
        print(a['id'])
        break
")
    if [ -z "${ASSET_ID}" ]; then
        echo "error: no asset named ${ASSET_NAME} found on release ${RELEASE_TAG}" >&2
        exit 1
    fi

    echo "Fetching ${ASSET_NAME} (asset ${ASSET_ID})..."
    curl -fL -H "Authorization: Bearer ${PAT}" -H "Accept: application/octet-stream" \
        -o "${ASSET_NAME}" \
        "https://api.github.com/repos/${REPO}/releases/assets/${ASSET_ID}"
    unzip -q "${ASSET_NAME}"
    rm "${ASSET_NAME}"
done

echo "Done. Frameworks/FaceTecSDK.xcframework and Frameworks/FaceTecSDKForDevelopment.xcframework are ready."
