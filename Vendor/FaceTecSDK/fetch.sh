#!/usr/bin/env bash
#
# Fetches the FaceTec SDK xcframeworks from the private vendor-swift-packages
# GitHub Release and unzips them into Frameworks/, for use as a local
# binaryTarget (see Package.swift).
#
# This is a manual, one-time step rather than something SwiftPM does for you:
# SwiftPM's binaryTarget(url:) can't authenticate reliably against private
# GitHub release assets through Xcode's own package downloader. The plain
# web download URL (github.com/OWNER/REPO/releases/download/...) passes
# SwiftPM's required-file-extension check but Xcode's downloader fails to
# authenticate against it; the URL that does authenticate correctly
# (api.github.com/repos/OWNER/REPO/releases/assets/{id}) gets rejected by
# SwiftPM before any network request because it has no .zip extension.
# There's no single URL that satisfies both, so we fetch it here instead and
# point Package.swift at the local result.
#
# Requires a `machine github.com` entry in ~/.netrc with a PAT that has read
# access to sirosfoundation/vendor-swift-packages, e.g.:
#
#   machine github.com
#   login <your-github-username>
#   password <your-PAT>
#
set -euo pipefail

cd "$(dirname "$0")"

REPO="sirosfoundation/vendor-swift-packages"
RELEASE_TAG="facetec-10.1.6"

rm -rf Frameworks
mkdir -p Frameworks
cd Frameworks

for FRAMEWORK in FaceTecSDK FaceTecSDKForDevelopment; do
    echo "Fetching ${FRAMEWORK}.xcframework.zip..."
    curl -fL -n -o "${FRAMEWORK}.xcframework.zip" \
        "https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${FRAMEWORK}.xcframework.zip"
    unzip -q "${FRAMEWORK}.xcframework.zip"
    rm "${FRAMEWORK}.xcframework.zip"
done

echo "Done. Frameworks/FaceTecSDK.xcframework and Frameworks/FaceTecSDKForDevelopment.xcframework are ready."
