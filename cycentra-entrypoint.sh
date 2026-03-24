#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# CyCentra CyIRIS entrypoint
# Starts CyIRIS, then sets admin credentials to env-var values.
# This guarantees IRIS_ADMIN_EMAIL + IRIS_ADMIN_PASSWORD always work —
# regardless of whether the DB was pre-seeded or freshly initialised.
# ──────────────────────────────────────────────────────────────────────────────
set -e

echo "======================================"
echo " CyCentra CyIRIS — Starting"
echo " Admin email:    ${IRIS_ADMIN_EMAIL:-admin@cycentra.com}"
echo "======================================"

# ── Launch original IRIS entrypoint in background ────────────────────────────
/iriswebapp/iris-entrypoint.sh "$@" &
IRIS_PID=$!

# ── Wait up to 120s for IRIS HTTP to be ready ────────────────────────────────
echo "[CyCentra] Waiting for IRIS to initialise..."
READY=0
for i in $(seq 1 24); do
    sleep 5
    if curl -sf http://localhost:8000/api/ping >/dev/null 2>&1; then
        echo "[CyCentra] IRIS is up after $((i * 5))s"
        READY=1
        break
    fi
    echo "[CyCentra] Still waiting... ($((i * 5))s / 120s)"
done

# ── Reset admin credentials via direct DB update ─────────────────────────────
if [ "$READY" = "1" ]; then
    python3 << 'PYEOF'
import os, sys

try:
    from werkzeug.security import generate_password_hash
    import psycopg2

    admin_email    = os.environ.get("IRIS_ADMIN_EMAIL",    "admin@cycentra.com")
    admin_password = os.environ.get("IRIS_ADMIN_PASSWORD", "CyIRIS@Change2024!")

    # Generate hash
    pw_hash = generate_password_hash(admin_password, method="pbkdf2:sha256")

    # Connect to postgres
    conn = psycopg2.connect(
        host     = os.environ.get("POSTGRES_SERVER",   "cyiris-db"),
        port     = int(os.environ.get("POSTGRES_PORT", "5432")),
        dbname   = os.environ.get("POSTGRES_DB",       "iris_db"),
        user     = os.environ.get("POSTGRES_USER",     "iris"),
        password = os.environ.get("POSTGRES_PASSWORD", "iris_pg_pass"),
    )
    cur = conn.cursor()

    # Update admin account
    cur.execute(
        'UPDATE "User" SET password = %s, email = %s WHERE login = %s',
        (pw_hash, admin_email, "admin")
    )
    rows = cur.rowcount
    conn.commit()
    cur.close()
    conn.close()

    if rows > 0:
        print(f"[CyCentra] ✅ Admin credentials set successfully")
        print(f"[CyCentra]    Username : admin")
        print(f"[CyCentra]    Email    : {admin_email}")
        print(f"[CyCentra]    Password : (as configured)")
    else:
        print(f"[CyCentra] ⚠️  No rows updated — admin user not found yet")

except Exception as e:
    print(f"[CyCentra] ⚠️  Credential reset failed: {e}", file=sys.stderr)
    print(f"[CyCentra]    IRIS is still running — check logs for auto-generated password", file=sys.stderr)
PYEOF
else
    echo "[CyCentra] ⚠️  IRIS did not respond in 120s — skipping credential reset"
    echo "[CyCentra]    Check: docker logs <container> | grep 'password >>>'"
fi

# ── Hand off to IRIS foreground process ──────────────────────────────────────
echo "[CyCentra] Credential setup complete — running IRIS"
wait $IRIS_PID