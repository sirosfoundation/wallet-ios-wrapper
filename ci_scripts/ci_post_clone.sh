#!/bin/bash

CONFIG_FILE="Config.xcconfig"

echo "Injecting Release secrets into $CONFIG_FILE…"

# We simply append the environment variables to the end of the file.
# Xcode's .xcconfig logic ensures the LAST definition of a variable wins.
cat <<EOF >> "$CONFIG_FILE"

// Xcode Cloud Secret Overrides
APP_BUNDLE_ID[config=Release] = ${RELEASE_APP_BUNDLE_ID}
EAF_BUNDLE_ID[config=Release] = ${RELEASE_EAF_BUNDLE_ID}
APP_GROUP[config=Release] = ${RELEASE_APP_GROUP}
DEVELOPMENT_TEAM[config=Release] = ${RELEASE_DEVELOPMENT_TEAM}
BASE_DOMAIN1[config=Release] = ${RELEASE_BASE_DOMAIN1}
APP_OTHER_LDFLAGS = -framework FaceTecSDK
FACETEC_API_BASE_URL = ${RELEASE_FACETEC_API_BASE_URL}
FACETEC_API_BEARER_TOKEN = ${RELEASE_FACETEC_API_BEARER_TOKEN}

EOF

echo "Fetching vendor libraries…"
./Vendor/FaceTecSDK/fetch.sh

echo "CI post-clone preparation complete."
