#!/usr/bin/env bash
# Build PenguinOS Container Image locally
set -euo pipefail

IMAGE_NAME="penguinos:latest"

echo "==> Building PenguinOS container image: ${IMAGE_NAME}..."

if command -v docker >/dev/null 2>&1; then
    docker build --network=host -t "${IMAGE_NAME}" -f Containerfile .
elif command -v podman >/dev/null 2>&1; then
    podman build --network=host -t "${IMAGE_NAME}" -f Containerfile .
else
    echo "Error: Neither docker nor podman was found on the system." >&2
    exit 1
fi

echo "==> Build complete: ${IMAGE_NAME}"
