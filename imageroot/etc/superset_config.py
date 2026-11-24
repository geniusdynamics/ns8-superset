# Apache Superset configuration for the NS8 module.
# Loaded through SUPERSET_CONFIG_PATH. Secrets come from the environment,
# which podman fills from the 0600 files in the module state directory.
import os

# SECRET_KEY is generated once at module creation. Superset refuses to start
# with its built-in default key, so a missing value fails loudly instead of
# falling back to an insecure one.
SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]
SQLALCHEMY_DATABASE_URI = os.environ["SUPERSET_DATABASE_URI"]

# Traefik terminates TLS and forwards X-Forwarded-* headers: trust one proxy hop
ENABLE_PROXY_FIX = True
PROXY_FIX_CONFIG = {"x_for": 1, "x_proto": 1, "x_host": 1, "x_port": 0, "x_prefix": 0}

# Secure cookies need HTTPS. When the administrator disables the HTTP to HTTPS
# redirection, plain HTTP stays usable and the cookies must not be marked secure.
SESSION_COOKIE_SECURE = os.environ.get("NS8_HTTP2HTTPS", "True").lower() == "true"
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"

# Keep the default Content Security Policy and security headers
TALISMAN_ENABLED = True
WTF_CSRF_ENABLED = True

# No Celery workers, Redis cache or results backend are deployed by this
# module, so none is configured: Superset uses its built-in null cache.
# Alerts, reports and asynchronous queries are therefore not available.
