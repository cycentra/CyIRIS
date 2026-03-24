# ─────────────────────────────────────────────────────────────────────────────
# CyIRIS — CyCentra custom DFIR-IRIS image
# ghcr.io/cycentra/cyiris
# ─────────────────────────────────────────────────────────────────────────────
FROM ghcr.io/dfir-iris/iriswebapp_app:latest

ARG BUILD_DATE
ARG BUILD_VERSION
ARG BUILD_REF

LABEL org.opencontainers.image.title="CyIRIS"
LABEL org.opencontainers.image.description="CyCentra Incident Response & Investigation System"
LABEL org.opencontainers.image.vendor="CyCentra"
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${BUILD_REF}"
LABEL org.opencontainers.image.source="https://github.com/cycentra/CyIRIS"

USER root

# Install psycopg2 for credential reset + curl for healthcheck
RUN pip install psycopg2-binary --quiet \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

# Copy branding assets
COPY custom-theme/logo.png       /home/iris/iriswebapp/app/static/assets/img/logo-alone-2-black.png
COPY custom-theme/logo.png       /home/iris/iriswebapp/app/static/assets/img/logo-white.png
COPY custom-theme/logo.png       /home/iris/iriswebapp/app/static/assets/img/logo-alone-2-white.png
COPY custom-theme/logo-login.png /home/iris/iriswebapp/app/static/assets/img/logo.png
COPY custom-theme/favicon.png    /home/iris/iriswebapp/app/static/assets/img/favicon.png

# Patch page title
RUN find /home/iris/iriswebapp -name "*.html" -exec \
    sed -i 's|IRIS - Incident Response Investigation System|CyIRIS — Incident Response|g' {} \; \
    2>/dev/null || true

# Copy credential-reset entrypoint
COPY cycentra-entrypoint.sh /cycentra/cycentra-entrypoint.sh
RUN chmod +x /cycentra/cycentra-entrypoint.sh

USER 1000
EXPOSE 8000

ENTRYPOINT ["/cycentra/cycentra-entrypoint.sh"]
CMD ["app"]
