# CyIRIS Branding Assets

This folder contains custom branding assets for CyIRIS.

## Required Files

### 1. logo.ico
Favicon displayed in browser tabs and bookmarks.
- **Format:** ICO (multi-resolution)
- **Sizes:** 16x16, 32x32, 48x48 px
- **Location:** Replaces `/iriswebapp/static/assets/img/logo.ico`

### 2. logo.png
Main CyIRIS logo with text, used in login page and header.
- **Format:** PNG (transparent background recommended)
- **Size:** 200x50 px (recommended)
- **Location:** `/iriswebapp/static/assets/img/branding/cyiris-logo.png`
- **Usage:** Login page, navigation bar header

### 3. logo-alone.png
CyIRIS icon/mark without text, used for small spaces.
- **Format:** PNG (transparent background)
- **Size:** 48x48 px (square, recommended)
- **Location:** `/iriswebapp/static/assets/img/branding/cyiris-icon.png`
- **Usage:** Sidebar, mobile view, notifications

### 4. custom.css
Custom CSS theme with Cycentra colors (purple/green).
- **Format:** CSS
- **Purpose:** Override default IRIS styling
- **Location:** `/iriswebapp/static/assets/css/cyiris-custom.css`
- **Status:** ✅ Already included

## Placeholder Files

If branding assets are missing during build:
- **Local build (`build-local.sh`)**: Uses DFIR-IRIS default logos as fallback
- **Production build (`build-and-push.sh`)**: Fails with error message

## Adding Custom Branding Assets

### Option 1: Create from Scratch

Use design software (Figma, Adobe Illustrator, Inkscape):

```bash
# Example using ImageMagick to create favicon
convert logo.png -define icon:auto-resize=48,32,16 logo.ico

# Example to resize logos
convert source-logo.png -resize 200x50 logo.png
convert source-icon.png -resize 48x48 logo-alone.png
```

### Option 2: Copy from Cycentra Assets

```bash
# If Cycentra already has branding assets
cp ~/cycentra360-backend/assets/logos/cyiris-logo.png branding/logo.png
cp ~/cycentra360-backend/assets/logos/cyiris-icon.png branding/logo-alone.png
cp ~/cycentra360-backend/assets/favicons/cyiris.ico branding/logo.ico
```

### Option 3: Use Existing IRIS Logos (Temporary)

For testing only - do not publish to GHCR with IRIS branding:

```bash
# Copy from original IRIS
cp ../ui/public/assets/img/logo.ico branding/logo.ico
cp ../ui/public/assets/img/logo-alone-2-black.png branding/logo.png
cp ../ui/public/assets/img/logo-alone-2-black.png branding/logo-alone.png
```

## Current Status

- ✅ **custom.css**: Custom Cycentra theme (purple/green)
- ⏳ **logo.ico**: **PLACEHOLDER NEEDED**
- ⏳ **logo.png**: **PLACEHOLDER NEEDED**
- ⏳ **logo-alone.png**: **PLACEHOLDER NEEDED**

## Build Behavior

### Local Build (`./build-local.sh`)
- **If assets missing**: Uses IRIS logos as fallback + warning
- **Purpose**: Quick testing, development
- **OK to use**: IRIS logos temporarily for local testing

### Production Build (`./build-and-push.sh`)
- **If assets missing**: Build fails with error
- **Purpose**: Publish to GHCR
- **Requirement**: Custom branding MUST be present

## Color Scheme

Cycentra brand colors (defined in custom.css):

```css
--cyiris-primary: #b06eff       /* Purple - Primary brand */
--cyiris-secondary: #28a745     /* Green - Cycentra accent */
--cyiris-accent: #f5c518        /* Gold - Highlights */
--cyiris-dark: #1a1a1a         /* Dark mode background */
```

Ensure logos work well with these colors.

## Testing Branding

After adding assets:

```bash
# Build locally
cd docker-custom
./build-local.sh

# Test in browser
cd ..
docker-compose -f docker-custom/docker-compose.custom.yml up -d

# Open in browser
open https://localhost

# Verify:
# 1. Favicon appears in browser tab
# 2. Logo shows on login page
# 3. Icon appears in header
# 4. Purple/green theme applied
```

## Notes

- Keep logo files small (<100KB each) for fast loading
- Use transparent backgrounds for PNG files
- Test on both light and dark backgrounds
- Ensure logos are readable at small sizes (favicon)
- Favicon should be square (1:1 aspect ratio)
- Header logo can be wide (4:1 aspect ratio)

## Next Steps

1. **Obtain or create** CyIRIS branding assets
2. **Place files** in this `branding/` folder
3. **Test locally** with `build-local.sh`
4. **Verify branding** by opening https://localhost
5. **Publish to GHCR** with `build-and-push.sh` (after testing)
