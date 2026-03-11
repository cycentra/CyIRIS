#!/bin/bash
# Build and push CyIRIS custom Docker image from source
# Builds from source with branding baked in + OIDC support

set -e

VERSION="1.0.0"
IMAGE_NAME="ghcr.io/cycentra/cyiris"
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

echo "========================================"
echo "Building CyIRIS FROM SOURCE v$VERSION"
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

if [ ! -f "ui/public/assets/css/cyiris-custom.css" ]; then
    echo "❌ Error: ui/public/assets/css/cyiris-custom.css not found"
    exit 1
fi

echo "✅ Source structure verified"
echo ""

# Verify custom logos are in place
echo "🔍 Verifying custom logos..."
LOGO_COUNT=$(find ui/public/assets/img -name "logo*.png" -o -name "logo*.ico" | wc -l | tr -d ' ')
if [ "$LOGO_COUNT" -lt 5 ]; then
    echo "❌ Error: Custom logos not found in ui/public/assets/img"
    echo "   Expected at least 5 logo files (found $LOGO_COUNT)"
    exit 1
fi

echo "✅ Found $LOGO_COUNT custom logo files"
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
echo "   This will take 5-10 minutes (compiling from source)..."
echo ""

# Build and push for multiple architectures
docker buildx build \
    --file docker/webApp/Dockerfile.cyiris \
    --platform linux/amd64,linux/arm64 \
    --tag $IMAGE_NAME:$VERSION \
    --tag $IMAGE_NAME:latest \
    --build-arg BUILD_DATE="$BUILD_DATE" \
    --build-arg CYIRIS_VERSION="$VERSION" \
    --push \
    --progress=plain \
    .

echo ""
echo "========================================"
echo "✅ Build and Push Complete!"
echo "========================================"
echo ""
echo "📋 Image Details:"
echo "   Name: $IMAGE_NAME"
echo "   Tags: $VERSION, latest"
echo "   Size: ~2.0 GB (includes Python + Node.js runtime)"
echo "   Platforms: linux/amd64, linux/arm64"
echo "   Pushed to: GitHub Container Registry (GHCR)"
echo ""
echo "✨ Features Included:"
echo "   ✅ Custom Cycentra branding (logos, colors)"
echo "   ✅ Minimal safe CSS (purple/green theme)"
echo "   ✅ OIDC authentication support (env-controlled)"
echo "   ✅ LDAP authentication support"
echo "   ✅ Based on DFIR-IRIS v2.4.20"
echo ""
echo "🔍 Verify the image:"
echo "   docker pull $IMAGE_NAME:latest"
echo "   docker inspect $IMAGE_NAME:latest | grep -A5 Labels"
echo ""
echo "🌐 View on GitHub:"
echo "   https://github.com/orgs/cycentra/packages"
echo ""
echo "🚀 Deploy on Server:"
echo "   1. SSH to server: ssh deepak@cy360.cycentra.com"
echo "   2. Create directory: sudo mkdir -p /opt/cycentra/modules/cyiris"
echo "   3. Copy files:"
echo "      cd /opt/cycentra/modules/cyiris"
echo "      # Copy docker-compose.yml and .env from local machine"
echo "   4. Edit .env for production:"
echo "      - Set CYIRIS_IMAGE=ghcr.io/cycentra/cyiris:latest"
echo "      - Set CYIRIS_PORT=8002 (or appropriate port)"
echo "      - Configure OIDC (optional):"
echo "        IRIS_AUTHENTICATION_TYPE=oidc"
echo "        OIDC_ISSUER_URL=https://your-keycloak.com/realms/cycentra"
echo "        OIDC_CLIENT_ID=cyiris"
echo "        OIDC_CLIENT_SECRET=your-secret"
echo "      - Generate secure passwords (openssl rand -base64 32)"
echo "   5. Pull and start:"
echo "      docker-compose pull"
echo "      docker-compose up -d"
echo "   6. Check logs:"
echo "      docker-compose logs -f app"
echo ""
echo "💡 OIDC Configuration:"
echo "   See OIDC-SETUP.md for complete OIDC setup instructions"
echo "   OIDC is environment-controlled - no rebuild needed"
echo ""
echo "📖 Documentation:"
echo "   - OIDC Setup: OIDC-SETUP.md"
echo "   - Docker Compose: docker-custom/docker-compose.custom.yml"
echo "   - Environment: docker-custom/.env.model"
echo ""
