#!/bin/sh
# Runs before every start of the web service: migrate the metadata database,
# initialize roles and permissions, create the admin user if it does not exist.
# Every step is idempotent, so the same script serves first install, restart
# and upgrade.
set -eu
superset db upgrade
superset init
python - <<'ADMIN'
import os
from superset.app import create_app

app = create_app()
with app.app_context():
    manager = app.appbuilder.sm
    if manager.find_user(username="admin") is None:
        if not manager.add_user("admin", "NS8", "Administrator", "admin@example.org",
                                manager.find_role("Admin"), os.environ["NS8_ADMIN_PASSWORD"]):
            raise SystemExit("Could not create the Superset administrator")
ADMIN
