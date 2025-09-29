#!/bin/bash
set -euo pipefail

# Custom Airflow image build script with OAuth support
echo "🚀 Building custom Airflow image with OAuth dependencies..."

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${APP_DIR}/.env.local"

if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
    echo "✅ Loaded environment from $ENV_FILE"
else
    echo "❌ Environment file not found: $ENV_FILE"
    exit 1
fi

# Set image details
BASE_IMAGE="${HARBOR_URL}/${HARBOR_PROJECT}/airflow:${AIRFLOW_TAG}"
CUSTOM_IMAGE="${HARBOR_URL}/${HARBOR_PROJECT}/airflow:${AIRFLOW_TAG}-oauth"
BUILD_DATE=$(date +%Y%m%d-%H%M%S)

echo "📋 Build configuration:"
echo "  Base image: $BASE_IMAGE"
echo "  Custom image: $CUSTOM_IMAGE"
echo "  Build date: $BUILD_DATE"

# Login to Harbor registry
echo "🔑 Logging into Harbor registry..."
echo "$HARBOR_ADMIN_PASSWORD" | docker login "$HARBOR_URL" -u "$HARBOR_USER" --password-stdin

# Build the custom image
echo "🔨 Building custom Airflow image..."
cd "$SCRIPT_DIR"
docker build \
    --tag "$CUSTOM_IMAGE" \
    --label "build-date=$BUILD_DATE" \
    --label "base-image=$BASE_IMAGE" \
    --label "oauth-enabled=true" \
    .

echo "✅ Custom image built successfully: $CUSTOM_IMAGE"

# Push the custom image to Harbor
echo "📤 Pushing custom image to Harbor..."
docker push "$CUSTOM_IMAGE"

echo "🎉 Custom Airflow image with OAuth support ready!"
echo "📍 Image location: $CUSTOM_IMAGE"
echo ""
echo "Next steps:"
echo "1. Update airflow-values.yaml to use: $CUSTOM_IMAGE"
echo "2. Deploy updated Airflow configuration"