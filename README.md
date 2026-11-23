# Apache Superset for NS8

This module runs Apache Superset 6.1.0 with a dedicated PostgreSQL database behind
NS8 Traefik. Configure a DNS hostname and HTTPS certificate in Settings.
Retrieve the generated first-start password on the instance node.

```sh
runagent -m superset1 superset-initial-credentials
```

Sign in as `admin`. Both data volumes and credentials are included in NS8
backup. The backup stops the application and database briefly for consistency.
Restore into empty volumes using the same module version before upgrading.

This deployment supports interactive SQL queries and dashboards. Features that
require Celery workers, including scheduled reports, require additional services.
