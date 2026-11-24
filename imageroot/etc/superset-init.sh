#!/bin/sh
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
