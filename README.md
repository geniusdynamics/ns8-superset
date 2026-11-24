# ns8-superset

[Apache Superset](https://superset.apache.org/) for [NethServer 8](https://github.com/NethServer/ns8-core):
explore data, run SQL queries and build dashboards from a web interface.

Each instance runs as a rootless Podman pod with two containers:

- `superset-web`: Superset 6.1.0 served by gunicorn, reachable through Traefik
- `superset-db`: a dedicated PostgreSQL 17 database holding the Superset metadata

Not deployed: Celery workers, Redis and a results backend. Interactive queries,
charts and dashboards work; alerts, scheduled reports, thumbnails and
asynchronous queries do not.

## Install

Install the module from the NS8 Software Center, or from the command line of the leader node:

```sh
add-module ghcr.io/geniusdynamics/superset:latest 1
```

The command prints the new instance name, for example `superset1`.

## Configuration

Open the instance in the NS8 admin interface, page Settings:

| Field | Meaning |
|---|---|
| Hostname (FQDN) | Public name of Superset, for example `superset.example.org`. It must resolve to the node and must not be used by another Traefik route. |
| Request Let's Encrypt certificate | Ask Traefik for a valid certificate. Needs a public DNS name reachable on port 80. |
| Force HTTPS | Redirect HTTP to HTTPS (default). When disabled, session cookies are no longer marked `Secure`. |

The same settings from the command line:

```sh
api-cli run module/superset1/configure-module --data '{"host":"superset.example.org","lets_encrypt":true,"http2https":true}'
api-cli run module/superset1/get-configuration
```

Saving the settings restarts the application. The first start runs the
database migrations and can take a few minutes.

## Credentials

The administrator password, the database password and the Superset `SECRET_KEY`
are generated once at installation. They are stored with mode 0600 in the
module state directory (`postgres.env`, `superset.env`, `admin.env`), are
included in the backup and are never returned by any action or written to the logs.

Read the initial administrator account on the node, as root:

```sh
runagent -m superset1 superset-initial-credentials
```

Sign in as `admin`, then change the password from *Settings > User Info > Reset my password*.
The command keeps showing the installation password, which stops working after a change.
To create additional users or roles, use *Settings > List Users* in Superset.

## Adding databases and data sources

In Superset open *Settings > Database Connections > + Database* and enter a SQLAlchemy URI.

- The runtime image ships the PostgreSQL driver (`postgresql+psycopg2://user:password@host:5432/dbname`).
  Other databases need their Python driver in the image: extend `Containerfile`
  and rebuild the module.
- Superset runs in a pod with its own network namespace. Reach a database on the
  same node through the node address and the published port of the other module, not `localhost`.
  `localhost:5432` inside the pod is the Superset metadata database: do not use it as a data source.
- SQLite connections are blocked by Superset (`PREVENT_UNSAFE_DB_CONNECTIONS`).
- Create a read-only database user for Superset on the data source.

## Backup and restore

Backup is configured from the NS8 Backup page. It includes:

- a consistent PostgreSQL dump (`pg_dump`, taken online, no downtime), removed from the state directory after the backup
- the `superset-data` volume (uploaded files)
- the three secret files and the module environment

Restore creates a new instance from the backup: the secrets come back with it,
so the existing `SECRET_KEY` still decrypts the stored database passwords,
the dump is loaded into an empty database and the web service migrates it on start.
Let's Encrypt is not requested on restore: enable it again in Settings once the DNS points to the new node.

## Upgrade

Update the module from the Software Center. The new images are pulled, the
services restart and the web service runs `superset db upgrade` and `superset init`
before it accepts traffic. Take a backup first.
The PostgreSQL image is pinned to major version 17: a major PostgreSQL upgrade
requires a dump and restore and is not done automatically.

## Troubleshooting

```sh
runagent -m superset1 systemctl --user status superset.service superset-db.service superset-web.service
runagent -m superset1 journalctl --user -n 100
runagent -m superset1 podman ps
curl -k --resolve superset.example.org:443:127.0.0.1 https://superset.example.org/health
```

- **Web service keeps restarting at first start**: the migrations run before gunicorn starts. Follow `journalctl` of `superset-web.service` and wait up to 15 minutes.
- **Cannot sign in over plain HTTP**: with *Force HTTPS* enabled, cookies are `Secure`. Use HTTPS.
- **Hostname rejected**: use a fully qualified name, not an IP address, not already used by another module.
- **Forgot the administrator password**: the installation password is still in `superset-initial-credentials` unless it was changed in Superset. Otherwise reset it from inside the container, typing the new password when prompted: `runagent -m superset1 podman exec -it superset-web superset fab reset-password --username admin`.

## Development

```sh
cd ui && yarn install && yarn build     # build the UI
./build-images.sh                       # build the module and runtime images with buildah
./test-module.sh <node-address> ghcr.io/geniusdynamics/superset:<tag>   # Robot Framework tests
```

Translations: edit `ui/public/i18n/en/translation.json` only, the other languages come from Weblate.

## License

GPL-3.0-or-later, see [LICENSE](LICENSE).
