#!/bin/bash
set -e

echo "======================================"
echo " CyCentra CyIRIS Starting"
echo " Admin: ${IRIS_ADMIN_EMAIL:-administrator@cycentra.com}"
echo "======================================"

/iriswebapp/iris-entrypoint.sh "$@" &
IRIS_PID=$!

echo "[CyCentra] Waiting for IRIS to initialise..."
READY=0
for i in $(seq 1 24); do
    sleep 5
    if curl -sf http://localhost:8000/login >/dev/null 2>&1; then
        echo "[CyCentra] IRIS is up after $((i * 5))s"
        READY=1
        break
    fi
    echo "[CyCentra] Still waiting... ($((i * 5))s / 120s)"
done

if [ "$READY" = "1" ]; then
    python3 << 'PYEOF'
import os, sys
try:
    from werkzeug.security import generate_password_hash
    import psycopg2

    email    = os.environ.get("IRIS_ADMIN_EMAIL",    "administrator@cycentra.com")
    password = os.environ.get("IRIS_ADMIN_PASSWORD", "CyIRIS@Change2024!")
    pw_hash  = generate_password_hash(password, method="pbkdf2:sha256")

    conn = psycopg2.connect(
        host     = os.environ.get("POSTGRES_SERVER",   "cyiris-db"),
        port     = int(os.environ.get("POSTGRES_PORT", "5432")),
        dbname   = os.environ.get("POSTGRES_DB",       "iris_db"),
        user     = os.environ.get("POSTGRES_USER",     "iris"),
        password = os.environ.get("POSTGRES_PASSWORD", "iris_pg_pass"),
    )
    cur = conn.cursor()
    cur.execute(
        'UPDATE "user" SET password = %s, email = %s WHERE login = %s',
        (pw_hash, email, "administrator")
    )
    rows = cur.rowcount
    conn.commit()
    cur.close()
    conn.close()
    if rows > 0:
        print(f"[CyCentra] ✅ Credentials set — username: administrator | email: {email}")
    else:
        print(f"[CyCentra] ⚠️  No rows updated — check DB connection")
except Exception as e:
    print(f"[CyCentra] ⚠️  Credential reset failed: {e}", file=sys.stderr)
PYEOF
else
    echo "[CyCentra] ⚠️  IRIS did not respond in 120s"
fi

wait $IRIS_PID
