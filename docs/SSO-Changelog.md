# CyIRIS — SSO Integration Changelog

All changes below were applied during the April 2026 CyCentra 360 SSO integration
sprint. CyIRIS operates in `oidc_proxy` mode: oauth2-proxy (cy-proxy) handles
authentication; CyIRIS trusts the `X-Forwarded-Email` header forwarded by nginx
and auto-provisions local user accounts on first login.

---

## v1.0.15 — 2026-04-19

### Bug Fix: Fatal `exit(0)` on OIDC discovery failure (crash-loop)

**File:** `source/app/configuration.py`

**Symptom:** CyIRIS container starts and immediately exits with exit code 0.
`docker logs` shows an OIDC/OpenID Connect discovery URL request failed, then the
process terminates. Systemd/Docker marks the container as stopped and restarts it
in a loop.

**Root cause:** In `oidc_proxy` mode, the configuration module attempted an HTTP
request to the OIDC discovery URL at import time. Any failure (DNS error, service
not yet up, malformed URL from a missing `BASE_DOMAIN` env var) called `exit(0)`
at module level — fatal for the container process.

**Fix:** Made OIDC discovery fully optional in `oidc_proxy` mode. The discovery
call is now wrapped in an `if oidc_discovery_url:` guard and any failure logs a
`WARNING` only — no `exit()` call. CyIRIS starts successfully regardless of
discovery URL availability at boot time.

---

## v1.0.14 — 2026-04-19

### Bug Fix: Logout URL relative — 404 on wrong domain

**File:** `source/app/configuration.py`

**Symptom:** Clicking "Logout" in CyIRIS sends the browser to
`https://cyiris.DOMAIN/oauth2/sign_out` — a 404 — instead of revoking the
oauth2-proxy session on `cysoc.DOMAIN`.

**Root cause:** `AUTHENTICATION_PROXY_LOGOUT_URL` was set to the relative path
`/oauth2/sign_out?rd=/dashboard`. The browser resolved it against the current
host (`cyiris.DOMAIN`), but oauth2-proxy runs on `cysoc.DOMAIN`. Result: 404.

**Fix:** Changed to an absolute URL:
```
https://cysoc.{BASE_DOMAIN}/oauth2/sign_out?rd=https://cysoc.{BASE_DOMAIN}/
```
Uses `BASE_DOMAIN` environment variable (injected by cycentra360 compose generator).

---

## v1.0.13 — 2026-04-19

### Bug Fix: New SSO users get no permissions (no group assignment)

**File:** `source/app/blueprints/access_controls.py`

**Symptom:** A user logs in via SSO for the first time. Account is created
successfully but the dashboard is empty / all API calls return permission denied.
User can log in but cannot do anything.

**Root cause:** `_authenticate_with_email()` called `create_user()` to auto-provision
the account but never called `add_user_to_group()`. The user was created with no
group membership — no roles, no permissions.

**Fix:** After `create_user()`, immediately call:
```python
add_user_to_group(user.id, initial_group.group_id)
```
where `initial_group` is resolved from the `IRIS_NEW_USERS_DEFAULT_GROUP` config
key (set to `Administrators` by cycentra360's compose generator via
`IRIS_NEW_USERS_DEFAULT_GROUP: "Administrators"` in the container environment).

**Also requires:** cycentra360 v1.0.222 — adds `IRIS_NEW_USERS_DEFAULT_GROUP: "Administrators"`
to the CyIRIS Docker Compose environment block.

---

## v1.0.10 — 2026-04-18

### Bug Fix: Logout `KeyError: 'current_case'`

**File:** `source/app/blueprints/rest/dashboard_routes.py`

**Symptom:** Clicking logout raises a 500 Internal Server Error when no case was
open in the current session.

**Root cause:** `session['current_case']` raises `KeyError` if the key was never
set (e.g. user navigated directly to logout without opening a case).

**Fix:** Changed to `session.get('current_case')` — returns `None` safely.

---

### Bug Fix: Logout re-logs user in (oidc_proxy mode — OIDC block skipped)

**File:** `source/app/blueprints/rest/dashboard_routes.py`

**Symptom:** After clicking logout, user is redirected back to CyIRIS and is still
logged in. The oauth2-proxy session cookie is never revoked.

**Root cause:** `is_authentication_oidc()` returns `False` for `oidc_proxy` mode.
The existing logout code only redirected to the OIDC sign-out endpoint when
`is_authentication_oidc()` was `True` — leaving `oidc_proxy` mode with no
sign-out call at all.

**Fix:** Added an explicit check for `AUTHENTICATION_PROXY_LOGOUT_URL` config key.
When set (as it is in `oidc_proxy` mode), the logout route redirects to it
immediately, revoking the oauth2-proxy cookie on `cysoc.DOMAIN`.

---

## v1.0.8 — 2026-04-18

### Bug Fix: ruff CI failure — spurious f-string prefix (F541)

**File:** `source/app/blueprints/rest/dashboard_routes.py`

**Symptom:** CI pipeline fails with `ruff F541: f-string without any placeholders`.

**Root cause:** A string literal `f"/oauth2/sign_out?rd=/dashboard"` had an
`f` prefix with no `{}` interpolation expressions.

**Fix:** Removed the `f` prefix: `"/oauth2/sign_out?rd=/dashboard"`.

---

## Architecture Notes

### How CyIRIS SSO Works (oidc_proxy mode)

```
Browser → nginx (cyiris.DOMAIN)
        → auth_request /oauth2/auth → cy-proxy (cysoc.DOMAIN:4180)
        → cy-proxy validates session cookie
        → returns 200 + X-Forwarded-Email: user@domain

nginx passes X-Forwarded-Email to CyIRIS Flask app

CyIRIS _authenticate_with_email():
  1. Look up user by email in local DB
  2. If not found: create_user() + add_user_to_group(Administrators)
  3. Login the user (Flask-Login session)

Logout:
  CyIRIS → redirects to https://cysoc.DOMAIN/oauth2/sign_out
         → cy-proxy clears cookie → redirects back to cysoc.DOMAIN
```

### Required Environment Variables (injected by cycentra360)

| Variable | Value | Purpose |
|----------|-------|---------|
| `BASE_DOMAIN` | `cycentra.com` | Used to build absolute OIDC/logout URLs |
| `IRIS_NEW_USERS_DEFAULT_GROUP` | `Administrators` | Group assigned to new SSO users |
| `AUTHENTICATION_TYPE` | `oidc_proxy` | Activates proxy header auth mode |
| `OIDC_IRIS_DISCOVERY_URL` | `https://cyasm.DOMAIN/oidc/...` | Optional — non-fatal if unreachable |
