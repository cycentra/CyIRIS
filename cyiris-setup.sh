#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# CyIRIS — Incident Response & Intelligence Platform  Setup & Update Wizard
# v1.0.0 — 2026-04-24
#
# FRESH INSTALL:
#   sudo bash cyiris-setup.sh
#
# UPDATE EXISTING SERVER (pull latest image, rolling restart):
#   sudo bash cyiris-setup.sh --update
#
# UPGRADE TO SPECIFIC VERSION:
#   sudo bash cyiris-setup.sh --upgrade v2.5.0
#
# WITH REGISTRY TOKEN (required for private GHCR):
#   GHCR_PAT=ghp_... sudo bash cyiris-setup.sh
#
# REQUIRED ENV VARS (set before running, or edit .env post-install):
#   CYCENTRA_PORTAL_URL   — CyCentra 360 portal URL  (e.g. https://cysoc.domain.com)
#   CYIRIS_OIDC_SECRET    — OIDC client secret shared with CyCentra 360
#   IRIS_ADM_EMAIL        — Admin email for CyIRIS
#
# What this script does:
#   fresh install  → installs Docker, creates /opt/cyiris, generates .env,
#                    pulls image, starts postgres + app, health check
#   --update       → pulls latest image, rolling restart, health check
#   --upgrade vX   → pulls specific version tag, restarts, health check
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colours & helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; DIM='\033[2m'; NC='\033[0m'; BOLD='\033[1m'

info()    { echo -e "${CYAN}  ▸ ${NC}$*"; }
success() { echo -e "${GREEN}  ✓ ${NC}$*"; }
warn()    { echo -e "${YELLOW}  ⚠ ${NC}$*"; }
error()   { echo -e "${RED}  ✗ ${NC}$*"; }
divider() { echo -e "${DIM}  ────────────────────────────────────────────────${NC}"; }

gen_secret() { openssl rand -hex 24; }
gen_pass()   { openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 20; }

# ── Parse flags ───────────────────────────────────────────────────────────────
MODE="full"
UPGRADE_VERSION=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --update)  MODE="update";  shift ;;
        --upgrade) MODE="upgrade"; shift; UPGRADE_VERSION="${1:-latest}"; shift ;;
        *) shift ;;
    esac
done

# ── Constants ─────────────────────────────────────────────────────────────────
_SCRIPT_VERSION="v1.0.0"
DEPLOY_DIR="/opt/cyiris"
GH_ORG="cycentra"
IMAGE_BASE="ghcr.io/${GH_ORG}/cyiris"
COMPOSE_FILE="${DEPLOY_DIR}/docker-compose.yml"
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

step=0
_LAST_STEP="(initializing)"
ERRORS=()

step_header() {
    step=$((step+1))
    _LAST_STEP="$1"
    echo -e "\n${BOLD}${CYAN}  ── STEP ${step}: $1${NC}"
    divider
}

# ── Error trap ────────────────────────────────────────────────────────────────
trap '
    ec=$?
    echo ""
    echo -e "\n${RED}${BOLD}  ✗ FATAL: Setup aborted during STEP ${step} \"${_LAST_STEP}\"${NC}"
    echo -e "  ${RED}  Failed command : ${BASH_COMMAND}${NC}"
    echo -e "  ${RED}  Exit code      : ${ec}  |  Line: ${BASH_LINENO[0]}${NC}"
    echo -e "  ${DIM}  Fix the issue above, then re-run: sudo bash cyiris-setup.sh${NC}"
    echo ""
' ERR

[[ $EUID -ne 0 ]] && { error "Run as root: sudo bash cyiris-setup.sh"; exit 1; }

# ── Banner ────────────────────────────────────────────────────────────────────
[[ -t 1 ]] && clear; echo ""
echo -e "${CYAN}${BOLD}"
echo "  ██████╗██╗   ██╗██╗██████╗ ██╗███████╗"
echo " ██╔════╝╚██╗ ██╔╝██║██╔══██╗██║██╔════╝"
echo " ██║      ╚████╔╝ ██║██████╔╝██║███████╗"
echo " ██║       ╚██╔╝  ██║██╔══██╗██║╚════██║"
echo " ╚██████╗   ██║   ██║██║  ██║██║███████║"
echo "  ╚═════╝   ╚═╝   ╚═╝╚═╝  ╚═╝╚═╝╚══════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Incident Response & Intelligence Platform${NC}"
echo -e "  ${DIM}Setup & Update Wizard — ${_SCRIPT_VERSION} — $(date -u +"%Y-%m-%d %H:%M UTC")${NC}"
echo ""; divider

case "$MODE" in
    update)  echo -e "  ${YELLOW}MODE: UPDATE${NC} — pulling latest image, rolling restart" ;;
    upgrade) echo -e "  ${YELLOW}MODE: UPGRADE${NC} — target version: ${BOLD}${UPGRADE_VERSION}${NC}" ;;
    *)       echo -e "  ${DIM}MODE: FULL INSTALL${NC} — Docker + CyIRIS stack + first-run config" ;;
esac
divider; echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# INFRASTRUCTURE BLOCK — skipped on --update / --upgrade
# ═══════════════════════════════════════════════════════════════════════════════

if [[ "$MODE" == "full" ]]; then

# ── Step 1: System packages ───────────────────────────────────────────────────
step_header "SYSTEM DEPENDENCIES"
apt-get update -y -qq 2>/dev/null || { warn "apt-get update failed — continuing"; }
apt-get install -y -qq curl wget ca-certificates gnupg lsb-release openssl jq 2>/dev/null
success "System packages installed"

# ── Step 2: Docker ────────────────────────────────────────────────────────────
step_header "DOCKER"

if command -v docker >/dev/null 2>&1 && docker --version | grep -qE "2[4-9]\.|[3-9][0-9]\."; then
    success "Docker already installed — $(docker --version)"
else
    info "Installing Docker ..."
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        apt-get remove -y "$pkg" 2>/dev/null || true
    done
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
        https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y -qq
    apt-get install -y -qq \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    systemctl enable docker
    systemctl start docker
    success "Docker installed — $(docker --version)"
fi

docker compose version >/dev/null 2>&1 \
    || { error "docker compose plugin not found"; exit 1; }
success "Docker Compose: $(docker compose version --short)"

fi  # end INFRA block

# ═══════════════════════════════════════════════════════════════════════════════
# APP BLOCK — runs in all modes
# ═══════════════════════════════════════════════════════════════════════════════

# ── Step 3: Deploy directory ──────────────────────────────────────────────────
step_header "DEPLOY DIRECTORY"

mkdir -p "${DEPLOY_DIR}"
mkdir -p "${DEPLOY_DIR}/db-init"

# Copy docker-compose.yml if not already deployed
if [[ ! -f "${COMPOSE_FILE}" ]]; then
    if [[ -f "${_SCRIPT_DIR}/docker-compose.yml" ]]; then
        cp "${_SCRIPT_DIR}/docker-compose.yml" "${COMPOSE_FILE}"
        success "docker-compose.yml deployed to ${DEPLOY_DIR}"
    else
        error "docker-compose.yml not found alongside setup script at ${_SCRIPT_DIR}"
        exit 1
    fi
else
    success "docker-compose.yml already present"
fi

# Copy db-init SQL if present
if [[ -d "${_SCRIPT_DIR}/docker/db" && ! "$(ls -A ${DEPLOY_DIR}/db-init 2>/dev/null)" ]]; then
    cp -r "${_SCRIPT_DIR}/docker/db/." "${DEPLOY_DIR}/db-init/"
    success "DB init scripts deployed to ${DEPLOY_DIR}/db-init"
fi

# Copy custom-theme branding if present
if [[ -d "${_SCRIPT_DIR}/custom-theme" && ! -d "${DEPLOY_DIR}/custom-theme" ]]; then
    cp -r "${_SCRIPT_DIR}/custom-theme" "${DEPLOY_DIR}/custom-theme"
    success "custom-theme deployed to ${DEPLOY_DIR}"
fi

# Self-copy
_SELF="$(realpath "${BASH_SOURCE[0]:-$0}")"
_SCRIPT_DEST="${DEPLOY_DIR}/cyiris-setup.sh"
if [[ "$_SELF" != "$_SCRIPT_DEST" ]]; then
    cp "$_SELF" "$_SCRIPT_DEST"
    chmod 750  "$_SCRIPT_DEST"
    success "Setup script deployed to ${_SCRIPT_DEST}"
fi

# Deploy docker-maintenance.sh alongside setup script
_MAINT_SRC="${_SCRIPT_DIR}/docker-maintenance.sh"
_MAINT_DEST="${DEPLOY_DIR}/docker-maintenance.sh"
if [[ -f "$_MAINT_SRC" ]]; then
    cp "$_MAINT_SRC" "$_MAINT_DEST"
    chmod 750 "$_MAINT_DEST"
    success "docker-maintenance.sh deployed to ${_MAINT_DEST}"
fi

# Schedule Docker maintenance cron (every 15 days at 02:00) — idempotent
if crontab -l 2>/dev/null | grep -q "docker-maintenance.sh"; then
    success "Docker maintenance cron already scheduled — skipping"
else
    (crontab -l 2>/dev/null; echo "0 2 */15 * * ${_MAINT_DEST} >> ${DEPLOY_DIR}/docker-maintenance.log 2>&1") | crontab -
    success "Cron scheduled: docker-maintenance.sh runs every 15 days at 02:00"
fi

# ── Step 4: GHCR authentication ───────────────────────────────────────────────
step_header "REGISTRY AUTHENTICATION"

GHCR_PAT="${GHCR_PAT:-${GH_TOKEN:-}}"
if [[ -n "$GHCR_PAT" ]]; then
    echo "$GHCR_PAT" | docker login ghcr.io -u "${GH_USER:-cycentra}" --password-stdin \
        && success "Logged in to GHCR" \
        || warn "GHCR login failed — will attempt pull without auth"
else
    warn "GHCR_PAT not set — attempting pull without authentication"
    warn "If pull fails: export GHCR_PAT=ghp_... and re-run"
fi

# ── Step 5: Environment configuration ─────────────────────────────────────────
step_header "ENVIRONMENT CONFIGURATION"

_env="${DEPLOY_DIR}/.env"
if [[ -f "$_env" ]]; then
    success ".env already exists — preserving existing secrets"
    _get() { grep -m1 "^${1}=" "$_env" 2>/dev/null | cut -d= -f2- | tr -d '"' || true; }
    POSTGRES_PASSWORD=$(_get POSTGRES_PASSWORD)
    IRIS_SECRET_KEY=$(_get IRIS_SECRET_KEY)
    CYIRIS_OIDC_SECRET=$(_get CYIRIS_OIDC_SECRET)
    [[ -z "$POSTGRES_PASSWORD"  ]] && POSTGRES_PASSWORD=$(gen_pass)    && warn "POSTGRES_PASSWORD missing — generated"
    [[ -z "$IRIS_SECRET_KEY"    ]] && IRIS_SECRET_KEY=$(gen_secret)     && warn "IRIS_SECRET_KEY missing — generated"
    [[ -z "$CYIRIS_OIDC_SECRET" ]] && CYIRIS_OIDC_SECRET=$(gen_secret) && warn "CYIRIS_OIDC_SECRET missing — generated"
else
    info "Generating .env with secure random secrets ..."
    POSTGRES_PASSWORD=$(gen_pass)
    IRIS_SECRET_KEY=$(gen_secret)
    CYIRIS_OIDC_SECRET=$(gen_secret)

    cat > "$_env" << ENVEOF
# CyIRIS — Environment Configuration
# Generated by cyiris-setup.sh on $(date -u +"%Y-%m-%d %H:%M UTC")
# Edit this file then run: sudo bash ${_SCRIPT_DEST} --update

# ── Database ──────────────────────────────────────────────────────────────────
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# ── CyIRIS Application ────────────────────────────────────────────────────────
IRIS_SECRET_KEY=${IRIS_SECRET_KEY}
IRIS_ADM_EMAIL=${IRIS_ADM_EMAIL:-admin@cycentra.com}

# ── CyCentra 360 OIDC Integration ────────────────────────────────────────────
# CYCENTRA_PORTAL_URL: public HTTPS URL of CyCentra 360 portal
# CYIRIS_OIDC_SECRET: must match CYIRIS_OIDC_SECRET in CyCentra 360 .env
CYCENTRA_PORTAL_URL=${CYCENTRA_PORTAL_URL:-https://cysoc.your-domain.com}
CYIRIS_OIDC_SECRET=${CYIRIS_OIDC_SECRET}
ENVEOF
    chmod 600 "$_env"
    success ".env created at ${_env}"

    if [[ "${CYCENTRA_PORTAL_URL:-}" == "https://cysoc.your-domain.com" ]]; then
        warn "CYCENTRA_PORTAL_URL is a placeholder — edit ${_env} with the real value"
    fi
    warn "Copy CYIRIS_OIDC_SECRET to CyCentra 360 .env as CYIRIS_OIDC_SECRET and restart CyCentra"
fi

# ── Step 6: Pull image ─────────────────────────────────────────────────────────
step_header "PULL IMAGE"

cd "${DEPLOY_DIR}"

if [[ "$MODE" == "upgrade" && -n "$UPGRADE_VERSION" ]]; then
    info "Pulling ${IMAGE_BASE}:${UPGRADE_VERSION} ..."
    docker pull "${IMAGE_BASE}:${UPGRADE_VERSION}" \
        && success "Pulled ${IMAGE_BASE}:${UPGRADE_VERSION}" \
        || { error "Pull failed — check GHCR_PAT and version tag"; exit 1; }
    docker tag "${IMAGE_BASE}:${UPGRADE_VERSION}" "${IMAGE_BASE}:latest"
    success "Tagged ${UPGRADE_VERSION} as latest"
else
    info "Pulling latest image ..."
    docker compose --env-file "$_env" pull cyiris \
        && success "cyiris image updated" \
        || { error "Image pull failed — check GHCR_PAT"; ERRORS+=("image pull failed"); }
fi

# ── Step 7: Start / restart ────────────────────────────────────────────────────
step_header "START STACK"

cd "${DEPLOY_DIR}"

if [[ "$MODE" == "full" ]]; then
    info "Starting CyIRIS stack (database + app) ..."
    docker compose --env-file "$_env" up -d
    success "CyIRIS stack started"
    info "First-time startup may take 60–90 seconds for database initialisation ..."
else
    info "Rolling restart of app container (database kept running) ..."
    docker compose --env-file "$_env" up -d --no-deps cyiris
    success "cyiris container restarted"
fi

# ── Step 8: Health check ───────────────────────────────────────────────────────
step_header "HEALTH CHECK"

info "Waiting for CyIRIS to become ready on :4433 ..."
_healthy=false
for i in $(seq 1 30); do
    if curl -sf "http://localhost:4433/api/ping" >/dev/null 2>&1; then
        _healthy=true
        break
    fi
    echo -n "."
    sleep 3
done
echo ""

if [[ "$_healthy" == true ]]; then
    success "CyIRIS is healthy — http://localhost:4433"
else
    warn "Health check timed out — may still be initialising (DB migration can be slow on first run)"
    warn "Check: docker compose --env-file ${_env} -f ${COMPOSE_FILE} logs cyiris"
    ERRORS+=("health check timed out — verify manually")
fi

_INSTALLED_VER=$(docker inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' cyiris 2>/dev/null || echo "unknown")
echo "${_INSTALLED_VER}" > "${DEPLOY_DIR}/version"

# ── Final summary ─────────────────────────────────────────────────────────────
_CYCENTRA_URL=$(grep -m1 "^CYCENTRA_PORTAL_URL=" "$_env" 2>/dev/null | cut -d= -f2- || echo "not configured")
echo ""; divider
echo -e "  ${BOLD}${GREEN}  CyIRIS setup complete${NC}"
echo ""
echo -e "  URL          : ${CYAN}http://$(curl -sf ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):4433${NC}"
echo -e "  OIDC issuer  : ${_CYCENTRA_URL}/oidc"
echo -e "  Config       : ${DEPLOY_DIR}/.env"
echo -e "  Compose      : ${COMPOSE_FILE}"
echo -e "  Logs         : docker compose -f ${COMPOSE_FILE} logs -f"
echo -e "  Version      : ${_INSTALLED_VER}"
echo ""

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    warn "${#ERRORS[@]} item(s) need attention:"
    for e in "${ERRORS[@]}"; do echo -e "  ${YELLOW}⚠${NC} $e"; done
fi

echo ""; divider
echo -e "  ${DIM}Re-run anytime : sudo bash ${_SCRIPT_DEST}${NC}"
echo -e "  ${DIM}Update         : sudo bash ${_SCRIPT_DEST} --update${NC}"
echo -e "  ${DIM}Upgrade vX.Y.Z : sudo bash ${_SCRIPT_DEST} --upgrade v2.5.0${NC}"
echo ""
