#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# build-and-push.sh — Build and push CyIRIS to ghcr.io/cycentra/cyiris
#
# Usage:
#   ./build-and-push.sh           # builds v1.0 (default)
#   ./build-and-push.sh v1.1      # builds specific version
#
# Prerequisites:
#   export GITHUB_TOKEN=ghp_xxxxxxxxxxxx   (needs write:packages scope)
#   export GITHUB_USER=your-github-username
# ─────────────────────────────────────────────────────────────────────────────
set -e

cd "$(dirname "$0")"

IMAGE_NAME="ghcr.io/cycentra/cyiris"
VERSION="${1:-v1.0}"
VERSION_NUM="${VERSION#v}"
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
BUILD_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "local")

echo "========================================"
echo "  Building CyIRIS $VERSION"
echo "========================================"
echo "  Image : $IMAGE_NAME:$VERSION_NUM"
echo "  Also  : $IMAGE_NAME:latest"
echo "  Date  : $BUILD_DATE"
echo "  Ref   : $BUILD_REF"
echo "========================================"
echo ""

if [ -z "$GITHUB_TOKEN" ]; then
  echo "❌  GITHUB_TOKEN not set."
  echo "    export GITHUB_TOKEN=ghp_xxxx"
  exit 1
fi
if [ -z "$GITHUB_USER" ]; then
  echo "❌  GITHUB_USER not set."
  echo "    export GITHUB_USER=your-github-username"
  exit 1
fi

echo "🔐 Logging in to ghcr.io..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin

docker buildx create --name cyiris-builder --use 2>/dev/null || \
  docker buildx use cyiris-builder 2>/dev/null || true

echo ""
echo "🔨 Building (linux/amd64)..."
echo ""

docker buildx build \
  --platform linux/amd64 \
  --file docker/Dockerfile \
  --tag "$IMAGE_NAME:$VERSION_NUM" \
  --tag "$IMAGE_NAME:latest" \
  --build-arg BUILD_DATE="$BUILD_DATE" \
  --build-arg BUILD_VERSION="$VERSION_NUM" \
  --build-arg BUILD_REF="$BUILD_REF" \
  --push \
  .

echo ""
echo "========================================"
echo "✅ Done!"
echo "========================================"
echo ""
echo "📋 Published:"
echo "   $IMAGE_NAME:$VERSION_NUM"
echo "   $IMAGE_NAME:latest"
echo ""
echo "🔍 Verify:"
echo "   docker pull $IMAGE_NAME:latest"
