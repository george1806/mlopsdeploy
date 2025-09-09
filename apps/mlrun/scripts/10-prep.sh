#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env.local"
CHARTS_DIR="${ROOT_DIR}/charts"
LOG_FILE="${ROOT_DIR}/images-list.txt"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "❌ Missing .env file at $ENV_FILE"
    exit 1
fi

# Load environment variables
set -a; source "$ENV_FILE"; set +a

mkdir -p "$CHARTS_DIR"
> "$LOG_FILE"

prepare_images_local() {
    echo "=============================="
    echo "🔹 Stage 1: Clone MLRun CE & Save Charts Locally"
    echo "=============================="

    cd "$CHARTS_DIR"

    # Clone MLRun CE repo if not exists
    if [[ ! -d "mlrun-ce" ]]; then
        echo "🔹 Cloning MLRun CE repository..."
        git clone https://github.com/mlrun/ce.git mlrun-ce
    fi

    cd mlrun-ce
    git fetch --tags
    LATEST_TAG=$(git tag -l "mlrun-ce-[0-9]*" | grep -v "rc" | sort -V | tail -n1)
    echo "ℹ️ Using tag: ${LATEST_TAG}"
    git checkout "${LATEST_TAG}"

    CHART_PATH="charts/mlrun-ce"
    if [[ ! -d "$CHART_PATH" ]]; then
        echo "❌ Helm chart path not found: $CHART_PATH"
        exit 1
    fi

    echo "🔹 Updating chart dependencies..."
    helm dependency update "$CHART_PATH"

# ==============================
# Execute stages
# ==============================

prepare_images_local