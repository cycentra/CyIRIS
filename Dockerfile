# ──────────────────────────────────────────────────────────────────────────────
# CyCentra CyIRIS image
# Based on official iriswebapp_app. Adds:
# Published: ghcr.io/cycentra/cyiris-app:latest
# ──────────────────────────────────────────────────────────────────────────────
FROM ghcr.io/dfir-iris/iriswebapp_app:latest

USER root

# Install psycopg2 (needed by entrypoint to reset credentials)
# and curl (needed for healthcheck ping)
RUN pip install psycopg2-binary --quiet \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

# Copy our credential-fix entrypoint
COPY cycentra-entrypoint.sh /cycentra/cycentra-entrypoint.sh
RUN chmod +x /cycentra/cycentra-entrypoint.sh

# ── CyCentra branding ─────────────────────────────────────────────────────────
# Page title patch
RUN find /home/iris/iriswebapp -name "*.html" -exec \
    sed -i 's|IRIS - Incident Response Investigation System|CyIRIS - Incident Response|g' {} \; 2>/dev/null || true

# Copy logo if provided (optional — add logo.png to this build folder)
COPY --chown=1000:1000 branding/ /home/iris/iriswebapp/app/static/assets/img/branding/ 2>/dev/null || true

USER 1000
EXPOSE 8000

ENTRYPOINT ["/cycentra/cycentra-entrypoint.sh"]
CMD ["app"]