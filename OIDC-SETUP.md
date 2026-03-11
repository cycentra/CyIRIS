# CyIRIS OIDC Authentication Setup Guide

This guide explains how to configure OIDC (OpenID Connect) authentication for CyIRIS.

## Overview

CyIRIS supports two OIDC authentication modes:

1. **Direct OIDC Authentication** (`oidc`) - CyIRIS handles OIDC flow directly
2. **OIDC Proxy Authentication** (`oidc_proxy`) - CyIRIS sits behind an authentication proxy (e.g., Keycloak Gatekeeper)

## Prerequisites

- An OIDC-compliant identity provider (Keycloak, Auth0, Azure AD, etc.)
- Client ID and Client Secret from your identity provider
- OIDC Issuer URL (discovery endpoint)

## Configuration Files

CyIRIS OIDC configuration is managed through:

1. **`.env` file** - Environment variables (not committed to git)
2. **`docker-compose.custom.yml`** - Docker service configuration

**Location:** `~/Documents/GitHub/Custom-Tools/CyIRIS/docker-custom/`

## Option 1: Direct OIDC Authentication (Recommended)

Use this when CyIRIS directly handles OIDC authentication.

### Step 1: Configure Identity Provider

In your identity provider (e.g., Keycloak):

1. Create a new OIDC client (e.g., `cyiris`)
2. Set redirect URIs:
   - `http://localhost:8001/login/oidc_callback` (local testing)
   - `https://cyiris.cycentra.com/login/oidc_callback` (production)
3. Enable the following client capabilities:
   - Client authentication: ON
   - Authorization Code Flow: ON
   - Client credentials: ON
4. Configure client scopes:
   - `openid` (required)
   - `email` (required)
   - `profile` (required)
5. Note your:
   - Client ID (e.g., `cyiris`)
   - Client Secret (e.g., `abc123...`)
   - Issuer URL (e.g., `https://keycloak.cycentra.com/realms/cycentra`)

### Step 2: Edit `.env` File

```bash
cd ~/Documents/GitHub/Custom-Tools/CyIRIS/docker-custom
nano .env
```

Update the following variables:

```bash
# ═══════════════════════════════════════════════════════════════════════════
# AUTHENTICATION TYPE
# ═══════════════════════════════════════════════════════════════════════════

# Set to 'oidc' to enable direct OIDC authentication
IRIS_AUTHENTICATION_TYPE=oidc

# ═══════════════════════════════════════════════════════════════════════════
# OIDC DIRECT AUTHENTICATION
# ═══════════════════════════════════════════════════════════════════════════

# REQUIRED: OIDC Issuer URL
# Example: https://keycloak.cycentra.com/realms/cycentra
OIDC_ISSUER_URL=https://your-keycloak-server.com/realms/your-realm

# REQUIRED: OIDC Client ID
OIDC_CLIENT_ID=cyiris

# REQUIRED: OIDC Client Secret
OIDC_CLIENT_SECRET=your-secret-here

# OPTIONAL: OIDC Endpoints (auto-discovered if not set)
# Only set these if auto-discovery fails
OIDC_AUTH_ENDPOINT=
OIDC_TOKEN_ENDPOINT=
OIDC_END_SESSION_ENDPOINT=

# OPTIONAL: OIDC Scopes (default: "openid email profile")
OIDC_SCOPES=openid email profile

# OPTIONAL: OIDC Attribute Mapping
# These map OIDC claims to CyIRIS user attributes
OIDC_MAPPING_USERNAME=preferred_username
OIDC_MAPPING_EMAIL=email
```

### Step 3: Deploy/Restart CyIRIS

**For local testing:**

```bash
cd ~/Documents/GitHub/Custom-Tools/CyIRIS
docker-compose -f docker-custom/docker-compose.custom.yml down
docker-compose -f docker-custom/docker-compose.custom.yml up -d
```

**Check logs:**

```bash
docker logs cyiris-app -f
```

Look for:
```
OIDC configuration properly parsed
Authentication mechanism configured: oidc
```

### Step 4: Test OIDC Login

1. Open browser: `http://localhost:8001`
2. Click **"Sign in with SSO"** (or similar button)
3. You'll be redirected to your identity provider
4. Log in with your identity provider credentials
5. You'll be redirected back to CyIRIS

**First-time users:**
- CyIRIS will auto-create an account based on OIDC claims
- Username from: `preferred_username` claim (or custom mapping)
- Email from: `email` claim (or custom mapping)
- Default role: Standard user (not admin)

### Step 5: Grant Admin Access

To make a user admin:

```bash
# Method 1: Via psql
docker exec -it cyiris-db psql -U postgres -d iris_db

SELECT user_id, user_name, user_email, user_active FROM "user";

UPDATE "user" SET user_active = true WHERE user_name = 'your-username';

# Assign admin role (you'll need to check role IDs)
SELECT * FROM user_roles;
INSERT INTO "user_roles" (user_id, role_id) VALUES (YOUR_USER_ID, 1);

\q
```

## Option 2: OIDC Proxy Authentication

Use this when CyIRIS is behind an authentication proxy (e.g., Keycloak Gatekeeper, oauth2-proxy).

### Step 1: Configure `.env`

```bash
# Authentication Type
IRIS_AUTHENTICATION_TYPE=oidc_proxy

# OIDC Discovery URL (Required)
OIDC_IRIS_DISCOVERY_URL=https://keycloak.cycentra.com/realms/cycentra/.well-known/openid-configuration

# OIDC Client ID (Required)
OIDC_CLIENT_ID=cyiris

# OIDC Client Secret (Required)
OIDC_CLIENT_SECRET=your-secret-here

# OIDC Admin Role (Required)
# Users with this role will have admin access
OIDC_IRIS_ADMIN_ROLE_NAME=cyiris-admin

# Token Verification (Optional)
OIDC_IRIS_AUDIENCE=
OIDC_IRIS_VERIFY_TOKEN_EXPIRATION=True
OIDC_IRIS_TOKEN_VERIFY_MODE=userinfo
OIDC_IRIS_INIT_ADMINISTRATOR_EMAIL=admin@cycentra.local
```

### Step 2: Deploy Authentication Proxy

Configure your authentication proxy (e.g., Keycloak Gatekeeper) to:
- Intercept all requests to CyIRIS
- Validate tokens with your identity provider
- Pass user information in headers to CyIRIS

## Troubleshooting

### Issue: "OIDC configuration not found"

**Solution:** Check that `IRIS_AUTHENTICATION_TYPE=oidc` is set in `.env`

```bash
docker exec cyiris-app env | grep IRIS_AUTHENTICATION_TYPE
```

### Issue: "OIDC discovery failed"

**Solution:** Verify your issuer URL is accessible and correct:

```bash
# Test discovery endpoint
curl https://your-issuer-url/.well-known/openid-configuration
```

Should return JSON with endpoints like `authorization_endpoint`, `token_endpoint`, etc.

### Issue: "Invalid client credentials"

**Solution:** Verify client ID and secret are correct:

1. Check `.env` file has correct values
2. Verify client exists in identity provider
3. Ensure client secret hasn't expired
4. Check docker logs: `docker logs cyiris-app -f`

### Issue: Users can't log in after OIDC setup

**Solution:** Ensure redirect URI is configured in identity provider:

- Local: `http://localhost:8001/login/oidc_callback`
- Production: `https://your-domain.com/login/oidc_callback`

### Issue: "Authentication mechanism configured: local" (but expected oidc)

**Solution:** Environment variable not being passed to container

```bash
# Check if variable is in container
docker exec cyiris-app env | grep AUTHENTICATION

# Should see:
# IRIS_AUTHENTICATION_TYPE=oidc

# If missing, restart with:
docker-compose -f docker-custom/docker-compose.custom.yml down
docker-compose -f docker-custom/docker-compose.custom.yml up -d
```

### View OIDC Debug Logs

```bash
docker logs cyiris-app 2>&1 | grep -i oidc
```

## Reverting to Local Authentication

To disable OIDC and return to local username/password:

```bash
# Edit .env
IRIS_AUTHENTICATION_TYPE=local

# Restart
docker-compose -f docker-custom/docker-compose.custom.yml restart app
```

## Security Considerations

1. **Always use HTTPS in production** - OIDC should never run over HTTP (except localhost testing)
2. **Secure `.env` file** - Contains sensitive credentials
   ```bash
   chmod 600 .env
   ```
3. **Use strong secrets** - Generate with:
   ```bash
   openssl rand -base64 32
   ```
4. **Regularly rotate client secrets** - Update in both identity provider and `.env`
5. **Limit token lifetime** - Configure in your identity provider
6. **Enable token validation** - Ensure `OIDC_IRIS_VERIFY_TOKEN_EXPIRATION=True`

## Production Deployment

For production deployment on cy360.cycentra.com:

### Step 1: Update `.env` for Production

```bash
# Use production GHCR image
CYIRIS_IMAGE=ghcr.io/cycentra/cyiris:latest

# Use production port (not 8001)
CYIRIS_PORT=8002

# Use production OIDC issuer
OIDC_ISSUER_URL=https://cy360.cycentra.com/oidc

# Use secure passwords (generate new ones)
SECRET_KEY=$(openssl rand -base64 48)
PASSWORD_SALT=$(openssl rand -base64 48)
DB_PASS=$(openssl rand -base64 32)
RABBITMQ_PASS=$(openssl rand -base64 32)
```

### Step 2: Configure Nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/cyiris
server {
    listen 443 ssl http2;
    server_name cy360.cycentra.com;

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/cy360.cycentra.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cy360.cycentra.com/privkey.pem;

    # CyIRIS location
    location /cyiris/ {
        proxy_pass http://localhost:8002/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }
}
```

### Step 3: Deploy on Server

```bash
# On cy360.cycentra.com server
ssh deepak@cy360.cycentra.com

# Create directory
sudo mkdir -p /opt/cycentra/modules/cyiris
cd /opt/cycentra/modules/cyiris

# Copy files from local machine
scp docker-compose.custom.yml deepak@cy360.cycentra.com:/opt/cycentra/modules/cyiris/docker-compose.yml
scp .env deepak@cy360.cycentra.com:/opt/cycentra/modules/cyiris/.env

# Deploy
docker-compose pull
docker-compose up -d

# Check logs
docker logs cyiris-app -f
```

## References

- [DFIR-IRIS Authentication Documentation](https://docs.dfir-iris.org/latest/operations/access_control/authentication/)
- [OIDC Specification](https://openid.net/specs/openid-connect-core-1_0.html)
- [Keycloak Documentation](https://www.keycloak.org/documentation)

## Support

For issues or questions:
- Check CyIRIS logs: `docker logs cyiris-app -f`
- Check identity provider logs
- Verify network connectivity between CyIRIS and identity provider
- Ensure time synchronization (OIDC tokens are time-sensitive)
