#!/bin/bash

CONFIG_FILE="../Config.xcconfig"

echo "Create new ${CONFIG_FILE}…"

# Keep version numbers.
EXTRACTED_MARKETING_VERSION=$(grep "MARKETING_VERSION" "$CONFIG_FILE" | awk -F '=' '{print $2}' | xargs)
EXTRACTED_CURRENT_PROJECT_VERSION=$(grep "CURRENT_PROJECT_VERSION" "$CONFIG_FILE" | awk -F '=' '{print $2}' | xargs)

# Include FaceTecSDK only, when not testing. Testing is done on a simulator
# and FaceTecSDK doesn't contain binaries for simulators.
FACETEC_CONFIG=""
if [ "$CI_XCODEBUILD_ACTION" != "build-for-testing" ]; then
    FACETEC_CONFIG=$(cat <<EOF
APP_OTHER_LDFLAGS = -framework FaceTecSDK
FACETEC_API_BASE_URL = ${RELEASE_FACETEC_API_BASE_URL}
FACETEC_API_BEARER_TOKEN = ${RELEASE_FACETEC_API_BEARER_TOKEN}
EOF
)
fi

# Write a new Config.xcconfig file which ensures a release build.
cat <<EOF > "$CONFIG_FILE"

APP_BUNDLE_ID = ${RELEASE_APP_BUNDLE_ID}
EAF_BUNDLE_ID = ${RELEASE_EAF_BUNDLE_ID}
APP_GROUP = ${RELEASE_APP_GROUP}
DEVELOPMENT_TEAM = ${RELEASE_DEVELOPMENT_TEAM}
CODE_SIGN_STYLE = Automatic
BASE_DOMAIN1 = ${RELEASE_BASE_DOMAIN1}

FRAMEWORK_SEARCH_PATHS = "\$(PROJECT_DIR)/Vendor/FaceTecSDK/Frameworks/FaceTecSDK.xcframework/ios-arm64" "\$(PROJECT_DIR)/Vendor/FaceTecSDK/Frameworks/FaceTecSDK.xcframework/ios-arm64_x86_64-simulator"
${FACETEC_CONFIG}

MARKETING_VERSION = ${EXTRACTED_MARKETING_VERSION}
CURRENT_PROJECT_VERSION = ${EXTRACTED_CURRENT_PROJECT_VERSION:=$CI_BUILD_NUMBER}

GCC_PREPROCESSOR_DEFINITIONS = \$(inherited) APP_GROUP="\$(APP_GROUP)" BASE_DOMAIN1="\$(BASE_DOMAIN1)" FACETEC_API_BASE_URL="\$(FACETEC_API_BASE_URL)" FACETEC_API_BEARER_TOKEN="\$(FACETEC_API_BEARER_TOKEN)"

EOF

if [ "$CI_XCODEBUILD_ACTION" != "build-for-testing" ]; then
    echo "Fetching vendor libraries…"
    ../Vendor/FaceTecSDK/fetch.sh
else
    echo "Skiping vendor libraries for testing"
fi

echo "CI post-clone preparation complete."
