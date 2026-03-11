#!/bin/bash
# CyIRIS Source Build Script
# Build CyIRIS from source with custom branding already in place

set -e

VERSION="1.0.0"
IMAGE_NAME="cyiris"
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

echo "========================================"
echo "Building CyIRIS FROM SOURCE"
echo "========================================"
echo ""
echo "📦 Image: $IMAGE_NAME:$VERSION"
echo "📦 Also tagging as: $IMAGE_NAME:latest"
echo "📅 Build date: $BUILD_DATE"
echo "🏗️  Build method: From source (not overlay)"
echo ""

# Check if we're in the right directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📂 Project root: $PROJECT_ROOT"
echo ""

# Go to project root
cd "$PROJECT_ROOT"

# Verify source structure
echo "🔍 Verifying source structure..."
if [ ! -d "ui/public/assets/img" ]; then
    echo "❌ Error: ui/public/assets/img not found"
    exit 1
fi

if [ ! -d "source" ]; then
    echo "❌ Error: source directory not found"  
    exit 1
fi

if [ ! -f "docker/webApp/Dockerfile.cyiris" ]; then
    echo "❌ Error: docker/webApp/Dockerfile.cyiris not found"
    exit 1
fi

echo "✅ Source structure verified"
echo ""

# Check if custom logos are in place
echo "🎨 Checking custom branding..."
if [ -f "ui/public/assets/img/logo-white.png" ]; then
    LOGO_SIZE=$(wc -c < "ui/public/assets/img/logo-white.png")
    echo "✅ logo-white.png: $LOGO_SIZE bytes"
fi

if [ -f "ui/public/assets/css/cyiris-custom.css" ]; then
    echo "✅ custom CSS found"
fi

echo ""
echo "🔨 Building from source..."
echo "   This will compile the UI, build Python environment,"
echo "   and create the final image with your custom branding."
echo ""

# Build using the source-based Dockerfile
docker build \
    --file docker/webApp/Dockerfile.cyiris \
    --tag $IMAGE_NAME:$VERSION \
    --tag $IMAGE_NAME:latest \
    --build-arg BUILD_DATE="$BUILD_DATE" \
    --progress=plain \
    .

BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -ne 0 ]; then
    echo ""
    echo "❌ Build failed with exit code $BUILD_EXIT_CODE"
    exit $BUILD_EXIT_CODE
fi

echo ""
echo "========================================"
echo "✅ Build Complete!"
echo "========================================"
echo ""
echo "📋 Image Details:"
echo "   Name: $IMAGE_NAME"
echo "   Tags: $VERSION, latest"
echo "   Size: $(docker images $IMAGE_NAME:latest --format '{{.Size}}')"
echo ""
echo "🔍 Verify the image:"
echo "   docker images $IMAGE_NAME"
echo ""
echo "🔬 Test logo files in image:"
echo "   docker run --rm $IMAGE_NAME:latest ls -lh /iriswebapp/static/assets/img/logo*.png"
echo ""
echo "🚀 Deploy locally:"
echo "   cd docker-custom"
echo "   docker-compose -f docker-compose.custom.yml up -d"
echo "   open http://localhost:8001"
echo ""
echo "💡 View logs:"
echo "   docker-compose -f docker-compose.custom.yml logs -f app"
echo ""
echo "📝 Note: Make sure to clear browser cache (Cmd+Shift+R) to see new logos!"
echo ""
