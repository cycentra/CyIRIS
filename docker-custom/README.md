# CyIRIS Custom Docker Image

## Overview
CyIRIS (Cycentra Incident Response & Investigation System) is a custom-branded version of DFIR-IRIS.

**Base:** DFIR-IRIS v2.4.20  
**Custom Image:** ghcr.io/cycentra/cyiris:latest  
**Version:** 1.0.0

## Structure

```
docker-custom/
├── branding/              # Custom branding assets
│   ├── logo.ico          # Favicon
│   ├── logo.png          # Main logo
│   ├── logo-alone.png    # Logo mark only
│   └── custom.css        # Custom CSS overrides
├── Dockerfile.custom     # Custom Docker build
├── build-local.sh        # Build for local testing
├── build-and-push.sh     # Build and push to GHCR
└── docker-compose.custom.yml  # Compose file with custom images
```

## Build Instructions

### Local Testing

Build custom images locally for testing:

```bash
cd ~/Documents/GitHub/Custom-Tools/CyIRIS/docker-custom

# Build webapp image
./build-local.sh

# Test locally with custom images
cd ..
docker-compose -f docker-compose.custom.yml up -d

# Access CyIRIS at https://localhost
```

### Production Build & Publish

Publish to GitHub Container Registry:

```bash
cd ~/Documents/GitHub/Custom-Tools/CyIRIS/docker-custom

# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# Build and push multi-arch images
./build-and-push.sh

# On server, use:
docker pull ghcr.io/cycentra/cyiris:latest
docker-compose -f docker-compose.custom.yml up -d
```

## Customization

### Branding Assets

Replace files in `branding/` folder:

- **logo.ico**: Favicon (16x16, 32x32, 48x48 px)
- **logo.png**: Main logo for login/header (recommended: 200x50 px)
-  **logo-alone.png**: Logo mark without text (recommended: 48x48 px)
- **custom.css**: CSS overrides for colors, fonts, etc.

### Colors

Edit `branding/custom.css` to change color scheme:

```css
:root {
    --cyiris-primary: #b06eff;      /* Purple */
    --cyiris-secondary: #28a745;    /* Green */
    --cyiris-accent: #f5c518;       /* Gold */
}
```

### Version

Update version in:
- `Dockerfile.custom` - ENV CYIRIS_VERSION
- `build-local.sh` - VERSION variable
- `build-and-push.sh` - VERSION variable

## Deployment

### Via cy360 Portal

The cy360 portal handles CyIRIS installation automatically:
1. Set `USE_CUSTOM_IMAGES=yes` in `/opt/cycentra/.env`
2. Update cyiris image config to use `ghcr.io/cycentra/cyiris:latest`
3. Install via portal → Plugins → CyIRIS

### Manual Deployment

```bash
# On server
cd /opt/cycentra/modules/cyiris

# Pull custom image
docker pull ghcr.io/cycentra/cyiris:latest

# Use docker-compose.custom.yml
cp docker-compose.custom.yml docker-compose.yml

# Start services
docker-compose up -d

# Check logs
docker-compose logs -f app
```

## Technical Details

### Base Image Changes

The custom Dockerfile:
1. Starts from official DFIR-IRIS image
2. Copies custom branding assets
3. Replaces logos and favicons
4. Injects custom CSS
5. Updates application name/version

### Image Layers

```
ghcr.io/dfir-iris/iriswebapp_app:v2.4.20 (base)
  └── Copy branding assets
      └── Replace logos
          └── Inject custom CSS
              └── ghcr.io/cycentra/cyiris:1.0.0
```

### Environment Variables

Custom variables:
- `CYIRIS_BRANDING`: Enable/disable branding (default: enabled)
- `CYIRIS_THEME`: Theme name (default: cycentra)
- `CYIRIS_VERSION`: Display version (default: 1.0.0)

## Architecture

CyIRIS consists of 5 Docker containers:

1. **app**: Flask web application (custom branded)
2. **db**: PostgreSQL database
3. **rabbitmq**: Message queue for background jobs
4. **worker**: Background job processor (custom branded)
5. **nginx**: Reverse proxy

Only `app` and `worker` containers use the custom image. Others use standard images.

## Maintenance

### Updating Base Version

When DFIR-IRIS releases a new version:

```bash
# Update Dockerfile.custom
sed -i 's/v2.4.20/v2.5.0/g' Dockerfile.custom

# Rebuild and test
./build-local.sh
docker-compose -f docker-compose.custom.yml up -d

# If successful, push to GHCR
./build-and-push.sh
```

### Updating Branding

```bash
# Update branding assets
cp new-logo.png branding/logo.png

# Rebuild
./build-local.sh

# Test changes
docker-compose -f docker-compose. custom.yml up -d --force-recreate
```

## Troubleshooting

### Build Fails

Check Docker buildx is enabled:
```bash
docker buildx ls
docker buildx create --use
```

### Image Tag Issues

Verify image tag matches compose file:
```bash
docker images | grep cyiris
# Should show: ghcr.io/cycentra/cyiris:1.0.0 or :latest
```

### Branding Not Applied

Force rebuild without cache:
```bash
./build-local.sh --no-cache
docker-compose up -d --force-recreate
```

### Push to GHCR Fails

Check authentication:
```bash
docker logout ghcr.io
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
./build-and-push.sh
```

## License

Based on DFIR-IRIS (LGPL v3)  
Custom branding © 2026 Cycentra

## Support

For issues with:
- **Base functionality**: https://github.com/dfir-iris/iris-web
- **Custom branding**: Contact Cycentra support
- **Deployment**: See cy360 backend documentation
