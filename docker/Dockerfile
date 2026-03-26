# ─────────────────────────────────────────────────────────────────────────────
# CyIRIS — CyCentra custom DFIR-IRIS image (built from source)
# ghcr.io/cycentra/cyiris
# Logos are baked in from ui/public/assets/img/ at build time
# ─────────────────────────────────────────────────────────────────────────────

####################
# COMPILE JS IMAGE #
####################
FROM node:20-alpine AS compile-js-image

COPY ui/ /ui
RUN rm -rf /ui/{node_modules,dist}
WORKDIR /ui
RUN npm ci
RUN npm run build

#################
# COMPILE IMAGE #
#################
FROM python:3.12 AS compile-image
RUN apt-get update
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY source/dependencies /dependencies
COPY source/requirements.txt /
RUN pip3 install -r requirements.txt

###############
# BUILD IMAGE #
###############
FROM python:3.12 AS iriswebapp
ENV PYTHONUNBUFFERED=1 DOCKERIZED=1

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

COPY --from=compile-image /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN apt-get update && apt-get install -y \
    p7zip-full pgp rsync postgresql-client curl \
    && rm -rf /var/lib/apt/lists/*

# Install psycopg2 for CyCentra credential reset
RUN pip install psycopg2-binary bcrypt --quiet \

RUN mkdir -p /iriswebapp \
    /home/iris/certificates/{rootCA,web_certificates} \
    /home/iris/user_templates \
    /home/iris/server_data/{backup,updates,custom_assets,datastore}

WORKDIR /iriswebapp

COPY docker/webApp/iris-entrypoint.sh .
COPY docker/webApp/wait-for-iriswebapp.sh .
COPY ./source .

# Compile JS — logos from ui/public/assets/img/ are baked in here
COPY --from=compile-js-image /ui/dist/ /iriswebapp/static/

RUN chmod +x dependencies/evtxdump_binaries/linux/x64/fd \
             dependencies/evtxdump_binaries/linux/x64/evtx_dump \
             iris-entrypoint.sh \
             wait-for-iriswebapp.sh

# ── CyCentra customisations ───────────────────────────────────────────────────
# Patch page title
RUN find /iriswebapp -name "*.html" -exec \
    sed -i 's|IRIS - Incident Response Investigation System|CyIRIS — Incident Response|g' {} \; \
    2>/dev/null || true

# Copy CyCentra credential-reset entrypoint
COPY cycentra-entrypoint.sh /cycentra/cycentra-entrypoint.sh
RUN chmod +x /cycentra/cycentra-entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/cycentra/cycentra-entrypoint.sh"]
CMD ["app"]