#!/bin/bash
# Build and push CyCentra CyIRIS image to GHCR
# Usage: ./build-and-push.sh [version]
# Example: ./build-and-push.sh 1.0.0

set -e

VERSION="${1:-latest}"
IMAGE="ghcr.io/cycentra/cyiris-app"

echo "Building ${IMAGE}:${VERSION} ..."

# Login to GHCR (needs a PAT with packages:write)
echo "Logging in to ghcr.io..."
echo "$GHCR_PAT" | docker login ghcr.io -u cycentra --password-stdin

# Build for linux/amd64 (server architecture)
docker buildx build \
  --platform linux/amd64 \
  --tag "${IMAGE}:${VERSION}" \
  --tag "${IMAGE}:latest" \
  --push \
  .

echo ""
echo "✅ Done — pushed:"
echo "   ${IMAGE}:${VERSION}"
echo "   ${IMAGE}:latest"
echo ""
echo "Now update app.py CYIRIS_IMAGE_APP to: ${IMAGE}:latest"