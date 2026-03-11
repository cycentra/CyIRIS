#!/bin/bash
# CyIRIS Build and Push Script
# Build multi-architecture images and push to GitHub Container Registry

set -e

cd "$(dirname "$0")"

VERSION="1.0.0"
IMAGE_NAME="ghcr.io/cycentra/cyiris"
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

echo "========================================"
echo "Building CyIRIS Custom Image v$VERSION"
echo "========================================"
echo ""
echo "📦 Image: $IMAGE_NAME:$VERSION"
echo "📦 Also tagging as: $IMAGE_NAME:latest"
echo "📅 Build date: $BUILD_DATE"
echo ""

# Check if branding assets exist
echo "🔍 Checking branding assets..."
if [ ! -f "branding/logo.ico" ]; then
    echo "❌ Error: branding/logo.ico not found"
    echo "   Please add custom branding assets before publishing to GHCR"
    exit 1
fi

if [ ! -f "branding/logo.png" ]; then
    echo "❌ Error: branding/logo.png not found"
    echo "   Please add custom branding assets before publishing to GHCR"
    exit 1
fi

if [ ! -f "branding/logo-alone.png" ]; then
    echo "⚠️  Warning: branding/logo-alone.png not found, using logo.png"
    cp branding/logo.png branding/logo-alone.png
fi

echo "✅ All branding assets found"
echo ""

# Check Docker buildx
echo "🔍 Checking Docker buildx..."
if ! docker buildx version >/dev/null 2>&1; then
    echo "❌ Error: Docker buildx not available"
    echo "   Install with: docker buildx create --use"
    exit 1
fi

# Create buildx builder if not exists
if ! docker buildx ls | grep -q "multiarch"; then
    echo "📦 Creating multi-architecture builder..."
    docker buildx create --name multiarch --use
else
    echo "✅ Multi-architecture builder exists"
    docker buildx use multiarch
fi

echo ""
echo "🔨 Building multi-architecture image (amd64, arm64)..."
echo ""

# Build and push for multiple architectures
docker buildx build \
    --file Dockerfile.custom \
    --platform linux/amd64,linux/arm64 \
    --tag $IMAGE_NAME:$VERSION \
    --tag $IMAGE_NAME:latest \
    --build-arg BUILD_DATE="$BUILD_DATE" \
    --build-arg VERSION="$VERSION" \
    --push \
    .

echo ""
echo "========================================"
echo "✅ Build and Push Complete!"
echo "========================================"
echo ""
echo "📋 Image Details:"
echo "   Name: $IMAGE_NAME"
echo "   Tags: $VERSION, latest"
echo "   Pushed to: GitHub Container Registry (GHCR)"
echo ""
echo "🔍 Verify the image:"
echo "   docker pull $IMAGE_NAME:latest"
echo "   docker inspect $IMAGE_NAME:latest"
echo ""
echo "🌐 View on GitHub:"
echo "   https://github.com/orgs/cycentra/packages?repo_name=CyIRIS"
echo ""
echo "🚀 Deploy on Server:"
echo "   ssh user@server"
echo "   docker pull $IMAGE_NAME:latest"
echo "   cd /opt/cycentra/modules/cyiris"
echo "   docker-compose -f docker-compose.custom.yml up -d"
echo ""
echo "💡 Verify deployment:"
echo "   docker-compose logs -f app"
echo "   curl https://cyiris.yourdomain.com/login"
echo ""
