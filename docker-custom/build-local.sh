#!/bin/bash
# CyIRIS Local Build Script
# Build custom-branded DFIR-IRIS image for local testing

set -e

cd "$(dirname "$0")"

VERSION="1.0.0"
IMAGE_NAME="cyiris"
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

echo "========================================"
echo "Building CyIRIS Custom Image (Local)"
echo "========================================"
echo ""
echo "📦 Image: $IMAGE_NAME:$VERSION"
echo "📦 Also tagging as: $IMAGE_NAME:latest"
echo "📅 Build date: $BUILD_DATE"
echo ""

# Check if branding assets exist
echo "🔍 Checking branding assets..."
if [ ! -f "branding/logo.ico" ]; then
    echo "⚠️  Warning: branding/logo.ico not found"
    echo "   Creating placeholder favicon..."
    # Copy from existing IRIS logo as fallback
    mkdir -p branding
    cp ../ui/public/assets/img/logo.ico branding/logo.ico 2>/dev/null || echo "   Placeholder will be created during build"
fi

if [ ! -f "branding/logo.png" ]; then
    echo "⚠️  Warning: branding/logo.png not found"
    echo "   Creating placeholder logo..."
    cp ../ui/public/assets/img/logo-alone-2-black.png branding/logo.png 2>/dev/null || echo "   Placeholder will be created during build"
fi

if [ ! -f "branding/logo-alone.png" ]; then
    echo "⚠️  Warning: branding/logo-alone.png not found"
    echo "   Using logo.png as fallback..."
    cp branding/logo.png branding/logo-alone.png 2>/dev/null || echo "   Placeholder will be created during build"
fi

echo ""
echo "🔨 Building image..."
docker build \
    --file Dockerfile.custom \
    --tag $IMAGE_NAME:$VERSION \
    --tag $IMAGE_NAME:latest \
    --build-arg BUILD_DATE="$BUILD_DATE" \
    --build-arg VERSION="$VERSION" \
    .

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
echo "🚀 Test locally:"
echo "   cd .."
echo "   docker-compose -f docker-compose.custom.yml up -d"
echo "   open https://localhost"
echo ""
echo "💡 View logs:"
echo "   docker-compose -f docker-compose.custom.yml logs -f app"
echo ""
