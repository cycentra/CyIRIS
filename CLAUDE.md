# CyIRIS — Claude Code Reference

## What This Repo Is

CyIRIS is the **CyCentra Incident Response & Investigation System** — a web-based collaborative platform for incident responders to track cases, IOCs, assets, alerts, tasks, timelines, and evidence. It is a CyCentra-branded fork of the open-source [DFIR-IRIS](https://github.com/dfir-iris/iris-web) project (upstream version v2.5.0-beta.1).

Within the CyCentra product suite it runs as a standalone service behind the CyCentra portal, authenticated via OIDC (the portal acts as the identity provider for the `cyiris` OIDC client). It is exposed as a Docker container (`ghcr.io/cycentra/cyiris`) on port 4433.

## Tech Stack

**Backend**
- Python 3.12, Flask 3.x (Gunicorn WSGI, 4 workers, unix socket)
- Flask-SQLAlchemy 3 + Alembic migrations (PostgreSQL 15 database)
- Flask-SocketIO 5 (real-time collaboration via Socket.IO)
- Celery 5 + RabbitMQ (background/async job processing)
- Graphene 3 + graphql-server (GraphQL API)
- Marshmallow 3 (serialisation/validation schemas)
- Authentication: local (bcrypt), LDAP (ldap3), OIDC (oic + PyJWT)
- Azure Key Vault support (azure-identity, azure-keyvault-secrets) for secrets

**Frontend**
- Svelte 4 + Vite 5 (component-based UI layer, built into `source/static/`)
- Tailwind CSS 3 + PostCSS
- Legacy jQuery/Bootstrap 4 stack still used for most pages (the Svelte layer is a newer addition)
- Socket.IO client for real-time updates

**Infrastructure**
- Docker Compose (5 services: app, worker, db, rabbitmq, nginx)
- Nginx reverse proxy with TLS termination
- Kubernetes manifests in `deploy/`
- CI via GitHub Actions (ruff lint, Docker builds, pytest API tests, Playwright e2e)

## Directory Structure

```
CyIRIS/
├── source/                    # All Python application code
│   ├── run.py                 # Gunicorn entrypoint (imports app + socket_io)
│   ├── requirements.txt       # Python dependencies (incl. bundled .whl modules)
│   ├── dependencies/          # Bundled IRIS extension modules (.whl files)
│   ├── tests/                 # Source-level unit/integration test stubs
│   ├── spectaql/              # GraphQL documentation config (spectaql)
│   └── app/
│       ├── __init__.py        # Flask app factory, db/cache/socketio init
│       ├── configuration.py   # IrisConfig class (env vars, Azure KV, config files)
│       ├── views.py           # Blueprint registration (register_blusprints)
│       ├── post_init.py       # DB bootstrap, admin user, module registration
│       ├── forms.py           # WTForms definitions
│       ├── util.py            # Shared utility functions
│       ├── models/            # SQLAlchemy models
│       │   ├── models.py      # Core domain models (Cases, IOCs, Assets, Events…)
│       │   ├── alerts.py      # Alert model
│       │   ├── cases.py       # Cases model (thin, mostly in models.py)
│       │   └── authorization.py  # Users, Groups, Orgs, Permissions enum
│       ├── schema/
│       │   └── marshables.py  # Marshmallow serialisation schemas
│       ├── blueprints/
│       │   ├── access_controls.py  # Auth decorators: ac_api_requires, ac_requires, ac_requires_case_identifier
│       │   ├── responses.py        # response_success / response_error helpers
│       │   ├── pages/             # Server-rendered HTML page routes (Jinja2)
│       │   ├── rest/              # REST API routes
│       │   │   ├── api_routes.py  # /api/ping, /api/versions
│       │   │   ├── case/          # /case/* endpoints
│       │   │   ├── manage/        # /manage/* admin endpoints
│       │   │   ├── alerts_routes.py
│       │   │   └── v2/            # /api/v2/* (newer REST API)
│       │   ├── graphql/           # GraphQL endpoint (/graphql)
│       │   └── socket_io_event_handlers/  # SocketIO event handlers
│       ├── datamgmt/          # Database access layer (thin DB query functions)
│       │   ├── case/          # case_db.py, case_assets_db.py, case_iocs_db.py…
│       │   ├── alerts/        # alerts_db.py
│       │   ├── manage/        # Users, groups, customers, ACL DB functions
│       │   └── …              # activities, dashboard, datastore, reporter, filters
│       ├── iris_engine/       # Core engine services
│       │   ├── access_control/    # utils.py (AC helpers), ldap_handler.py, oidc_handler.py
│       │   ├── module_handler/    # module_handler.py — loads/registers IRIS extension modules
│       │   ├── tasker/            # celery.py, tasks.py — async task definitions
│       │   ├── backup/            # Backup utilities
│       │   ├── reporter/          # Report generation helpers
│       │   └── utils/             # tracker.py (activity tracking), misc utils
│       ├── alembic/           # DB migrations (44 version files)
│       ├── business/          # Business logic layer (cases.py, alerts.py…)
│       ├── templates/         # Jinja2 HTML templates
│       ├── static/            # Compiled JS/CSS assets (Vite build output)
│       └── resources/         # Static resources (report templates etc.)
├── ui/                        # Svelte frontend source
│   ├── src/
│   │   ├── App.svelte
│   │   ├── pages/             # Per-page JS modules (case.js, alerts.js, manage.users.js…)
│   │   └── lib/               # Shared components and utilities
│   ├── package.json
│   ├── vite.config.js         # Multi-entry Vite build (one bundle per page)
│   └── tailwind.config.js
├── docker/
│   ├── Dockerfile             # Multi-stage: node build → python venv → final image
│   ├── db/                    # PostgreSQL init scripts
│   ├── nginx/                 # Nginx config
│   └── webApp/                # iris-entrypoint.sh, wait-for-iriswebapp.sh
├── docker-compose.yml         # CyCentra production compose (2 services: db + app)
├── docker-compose.base.yml    # Full upstream compose (5 services incl. rabbitmq, worker, nginx)
├── docker-compose.dev.yml     # Dev compose (mounts local source)
├── .env.model                 # Template for .env — copy and fill before running
├── cyiris-setup.sh            # One-shot install/update/upgrade wizard script
├── cycentra-entrypoint.sh     # Docker ENTRYPOINT — wraps iris-entrypoint.sh
├── scripts/gunicorn-cfg.py    # Gunicorn config (4 workers, unix:sock, 3000s timeout)
├── deploy/
│   ├── kubernetes/            # K8s manifests
│   └── eks_manifest/          # EKS-specific manifests
├── e2e/                       # Playwright end-to-end tests
├── tests/                     # API integration tests (pytest + requests)
├── .bumpversion.cfg           # Version management config
├── pyproject.toml             # Ruff lint config (ignores E402, E711, E712, E721…)
└── .github/workflows/
    ├── ci.yml                 # CI: ruff, docker builds, API tests, e2e tests
    └── publish.yml            # Image publish workflow
```

## Key Files

| File | Purpose |
|---|---|
| `source/app/__init__.py` | Flask app factory — creates `app`, `db`, `bc`, `cache`, `socket_io`, `celery` globals |
| `source/app/configuration.py` | `IrisConfig` class — reads from Azure KV → env vars → config file (in that priority order) |
| `source/app/views.py` | `register_blusprints()` — single place where all Flask blueprints are registered |
| `source/app/post_init.py` | First-boot DB init: creates admin user, registers bundled modules, runs Alembic |
| `source/app/models/models.py` | Core ORM models: Cases, Client, UserActivity, IOCs, Assets, Events, Tasks, Evidence |
| `source/app/models/authorization.py` | `User`, `Group`, `Organisation`, `Permissions` enum, `CaseAccessLevel` enum |
| `source/app/blueprints/access_controls.py` | Auth decorators: `@ac_api_requires()`, `@ac_requires()`, `@ac_requires_case_identifier()` |
| `source/app/blueprints/rest/v2/__init__.py` | `/api/v2` blueprint assembly |
| `source/app/iris_engine/module_handler/module_handler.py` | IRIS extension module loader |
| `source/app/iris_engine/tasker/tasks.py` | Celery task definitions |
| `source/app/alembic/` | 44 DB migration files — run automatically by `post_init.py` at startup |
| `docker/Dockerfile` | Multi-stage build: Node 20 (UI) → Python 3.12 (venv) → final image |
| `cyiris-setup.sh` | Standalone install/update wizard; run with `--update` or `--upgrade vX` |
| `.env.model` | All configurable env vars with documentation |

## Development Commands

### Backend

```bash
# Install Python dependencies (from source/)
pip install -r source/requirements.txt

# Run locally (dev mode, port 8000)
cd source && python run.py

# Run with gunicorn
cd source && gunicorn --config scripts/gunicorn-cfg.py run:app

# Lint (from repo root)
ruff check source/

# Run API integration tests (requires Docker stack running)
cd tests && python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp tests/data/basic.env .env
docker compose --file docker-compose.dev.yml up --detach
python -m unittest --verbose
```

### Frontend (ui/)

```bash
cd ui
npm install       # install deps
npm run dev       # dev server (Vite, HMR)
npm run build     # production build → output to ui/dist/
npm run watch     # incremental dev build (watches for changes)
npm run lint      # ESLint
```

### Docker

```bash
# Copy and edit env file first
cp .env.model .env

# CyCentra production stack (2 services)
docker compose up -d

# Full upstream stack (5 services, for development)
docker compose --file docker-compose.dev.yml up --detach

# Build the app image
docker build -f docker/Dockerfile -t cyiris:local .

# One-shot setup on a new server
sudo bash cyiris-setup.sh                          # fresh install
sudo bash cyiris-setup.sh --update                 # pull latest image + rolling restart
sudo bash cyiris-setup.sh --upgrade v2.5.0         # upgrade to specific version
```

## Patterns and Conventions

### Architecture Layers
1. **blueprints/pages/** — Server-rendered Jinja2 HTML pages
2. **blueprints/rest/** — Legacy REST API (no `/api/v2` prefix, uses `cid` query param for case context)
3. **blueprints/rest/v2/** — Modern REST API (`/api/v2/...`) with proper pagination and resource-based URLs
4. **blueprints/graphql/** — GraphQL API at `/graphql`
5. **datamgmt/** — Raw DB query functions (no business logic)
6. **business/** — Business logic layer that orchestrates datamgmt calls
7. **iris_engine/** — Platform services (access control, modules, tasker, backup)

### Authentication / Access Control
- API auth via `X-IRIS-AUTH` header or `Authorization: Bearer <api_key>` header (checked in `views.load_user_from_request`)
- Three auth methods: `local`, `ldap`, `oidc` — set via `IRIS_AUTHENTICATION_TYPE` env var
- Permissions are bitmask enums in `authorization.Permissions`; use `@ac_api_requires(Permissions.some_perm)` on REST routes
- Case-level access is a separate bitmask (`CaseAccessLevel`) checked with `ac_fast_check_user_has_case_access()`
- Page routes use `@ac_requires()`, API routes use `@ac_api_requires()`

### Naming
- DB query functions live in `datamgmt/<domain>/<domain>_db.py`, named `get_X`, `create_X`, `update_X`, `delete_X`
- Blueprint names follow `<area>_rest_blueprint` for REST, `<area>_blueprint` for pages
- Model files: `models.py` (core), `authorization.py` (users/perms), `alerts.py`, `cases.py`
- Marshmallow schemas are in `schema/marshables.py`

### Response Helpers
- REST: `response_success(data)`, `response_error(msg, data, status)` from `blueprints/responses.py`
- v2 API: `response_api_success(data)`, `response_api_paginated(schema, paginated)`, `response_api_created(data)`, `response_api_deleted()` from `blueprints/rest/endpoints.py`

### Config Priority
`IrisConfig` reads settings in this order: **Azure Key Vault → environment variables → config file**. Never hard-code secrets; always use env vars or KV.

### IRIS Extension Modules
Bundled as `.whl` files in `source/dependencies/` (VirusTotal, MISP, Webhooks, IntelOwl, etc.). Loaded at runtime by `iris_engine/module_handler/module_handler.py`. Configured via Manage > Modules in the UI.

### Database Migrations
Alembic migrations run automatically at startup via `post_init.py`. Migration files are in `source/app/alembic/versions/`. To create a new migration: `alembic revision --autogenerate -m "description"` from `source/app/`.

### Frontend
The Svelte UI is a **multi-entry** Vite build — each page in `ui/src/pages/` becomes a separate JS bundle. The old jQuery/Bootstrap pages still dominate; Svelte is used for newer components. Built output lands in `source/static/` (via Docker) or served from `ui/dist/` in dev.

## Gotchas

- **Two docker-compose files with different scopes**: `docker-compose.yml` is the CyCentra production file (2 services, no rabbitmq/worker/nginx). `docker-compose.base.yml` / `docker-compose.dev.yml` are the full 5-service upstream stacks. Using the wrong one is a common mistake.
- **No Celery worker in production compose**: The CyCentra `docker-compose.yml` omits the `worker` service and RabbitMQ. Async tasks (module execution, bulk ops) may not work without a separate worker setup.
- **`cid` query parameter**: Legacy REST routes (v1) use `?cid=<case_id>` on nearly every request to establish case context. The v2 API uses path parameters instead.
- **Bundled `.whl` dependencies**: `source/dependencies/` contains pre-built wheels for IRIS modules. These are not on PyPI — do not remove them from `requirements.txt`.
- **`graphql-server[flask]==3.0.0b7`**: Still on a beta package. The requirements comment acknowledges this. Do not upgrade without testing.
- **Svelte build must precede Docker build**: The Dockerfile copies `ui/dist/` (compiled by Node stage) into `source/static/`. If you modify UI code and build locally, run `npm run build` first.
- **Version bumping**: Use `bumpversion` (configured in `.bumpversion.cfg`). It patches `configuration.py`, `docker-compose.yml` and commits + tags automatically. Current version: `v2.5.0-beta.1`.
- **OIDC integration**: In the CyCentra deployment, OIDC is always enabled. `OIDC_ISSUER` points to the CyCentra portal URL, `OIDC_CLIENT_ID=cyiris`, and `CYIRIS_OIDC_SECRET` must match what's configured in the portal.
- **Admin password**: On first boot, the admin password is auto-generated and logged once (`WARNING :: post_init :: create_safe_admin :: >>>`). Search the `app` container logs. Set `IRIS_ADM_PASSWORD` env var to pre-configure it.
- **GraphQL is beta**: Uses `graphene-sqlalchemy==3.0.0rc1` (release candidate). Treat the GraphQL schema as unstable.
- **Ruff ignores**: `pyproject.toml` globally suppresses `E402` (module-level import not at top), `E711/E712` (comparison to None/True/False), `E721` (type comparison), `E722` (bare except), `F821/F841` (undefined/unused names). These suppressions hide real issues in legacy code — be careful when refactoring.
- **Deploy directory**: `deploy/kubernetes/` and `deploy/eks_manifest/` contain K8s manifests; these may be out of date relative to the Docker Compose configuration.
