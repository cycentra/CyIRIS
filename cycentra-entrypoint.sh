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
    from flask_bcrypt import Bcrypt
    import psycopg2

    email    = os.environ.get("IRIS_ADMIN_EMAIL",    "administrator@cycentra.com")
    password = os.environ.get("IRIS_ADMIN_PASSWORD", "CyIRIS@Change2024!")

    # Use flask_bcrypt — exactly what IRIS uses to verify passwords
    _bcrypt = Bcrypt()
    pw_hash = _bcrypt.generate_password_hash(password).decode('utf-8')

    conn = psycopg2.connect(
        host     = os.environ.get("POSTGRES_SERVER",   "cyiris-db"),
        port     = int(os.environ.get("POSTGRES_PORT", "5432")),
        dbname   = os.environ.get("POSTGRES_DB",       "iris_db"),
        user     = os.environ.get("POSTGRES_USER",     "iris"),
        password = os.environ.get("POSTGRES_PASSWORD", "iris_pg_pass"),
    )
    cur = conn.cursor()

    cur.execute('SELECT id, "user" FROM "user" WHERE id = 1')
    row = cur.fetchone()

    if row:
        current_username = row[1]
        print(f"[CyCentra] Found admin user: {current_username}")
        cur.execute(
            'UPDATE "user" SET password = %s, email = %s, "user" = %s WHERE id = 1',
            (pw_hash, email, email)
        )
        rows = cur.rowcount
        conn.commit()
        cur.close()
        conn.close()
        if rows > 0:
            print(f"[CyCentra] ✅ Credentials set successfully")
            print(f"[CyCentra]    Username : {email}")
            print(f"[CyCentra]    Email    : {email}")
            print(f"[CyCentra]    Password : as entered in CyCentra portal")
        else:
            print(f"[CyCentra] ⚠️  No rows updated")
    else:
        print("[CyCentra] ⚠️  No user found with id=1")
        cur.execute('SELECT id, "user", email FROM "user" LIMIT 5')
        users = cur.fetchall()
        print(f"[CyCentra]    Users in DB: {users}")
        cur.close()
        conn.close()

except Exception as e:
    print(f"[CyCentra] ⚠️  Credential reset failed: {e}", file=sys.stderr)
PYEOF
else
    echo "[CyCentra] ⚠️  IRIS did not respond in 120s"
fi

wait $IRIS_PID
