# Superset runtime image: the official image plus the PostgreSQL driver, which
# the upstream image does not ship. Keep the tag fully pinned for Renovate.
FROM docker.io/apache/superset:6.1.0
USER root
RUN uv pip install --python /app/.venv/bin/python psycopg2-binary==2.9.11
USER superset
