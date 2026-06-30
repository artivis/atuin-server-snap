# atuin-server snap

Snap package for [atuin-server](https://github.com/atuinsh/atuin) — the
self-hosted backend that syncs encrypted shell history across machines.

## What's inside

| App | Description |
|-----|-------------|
| `atuin-server.server` | The atuin sync daemon — **starts automatically at install** |
| `atuin-server.postgres` | Bundled PostgreSQL 18 service (disabled at install, started automatically when `postgres.enable=true`) |
| `atuin-server.get-db-password` | Print the generated PostgreSQL password (requires `sudo`) |

The server starts immediately after install using the default SQLite database.
The postgres service must be started manually if needed.

## Installation

```bash
sudo snap install atuin-server
```

On first install the snap writes a documented `server.toml` to
`/var/snap/atuin-server/common/server.toml` with SQLite enabled by default,
then **starts the server automatically**. No manual configuration is
required for a basic single-machine setup.

## Option A — SQLite (simplest, default)

SQLite requires no external service and is enabled out of the box. The
server starts automatically after install.

```bash
sudo snap install atuin-server
# Server is already running — connect your Atuin clients straight away.
```

To customise (host, port, open_registration, etc.):

```bash
sudoedit /var/snap/atuin-server/common/server.toml
sudo snap restart atuin-server.server
```

The default `db_uri` in `server.toml`:

```toml
db_uri = "sqlite:///var/snap/atuin-server/common/atuin.db"
```

## Option B — external PostgreSQL

Connect to any existing PostgreSQL instance over TCP. Unix-socket
connections to a host PostgreSQL instance are **not** supported under
strict snap confinement — use `localhost` or a hostname.

```bash
# Edit server.toml and set db_uri
sudoedit /var/snap/atuin-server/common/server.toml

# Restart to pick up the new database URI
sudo snap restart atuin-server.server
```

Example `server.toml` entry:

```toml
db_uri = "postgres://atuin:password@localhost:5432/atuin"
```

## Option C — bundled PostgreSQL 18

The snap ships PostgreSQL 18. A single `snap set` command is all that is
needed: the configure hook starts postgres and restarts the server.

```bash
sudo snap set atuin-server atuin-server.use-postgres=true
# Starts bundled postgres, restarts the server, injects the connection URI.
```

The bundled postgres connection string (`postgres://atuin:<password>@localhost:<port>/atuin`)
is injected automatically via environment variable and overrides any
`db_uri` present in `server.toml`.

To revert to SQLite:

```bash
sudo snap set atuin-server atuin-server.use-postgres=false
```

## Snap configuration reference

| Key | Default | Description |
|-----|---------|-------------|
| `atuin-server.use-postgres` | `false` | Start and use the bundled PostgreSQL |

All other settings live in `server.toml` (atuin-server) or `postgres.conf`
(bundled PostgreSQL).

Bundled PostgreSQL connection settings live in
`/var/snap/atuin-server/common/postgres.conf`:

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_PORT` | `5432` | Port the bundled PostgreSQL listens on |

The database password is generated randomly on first install and stored in
`/var/snap/atuin-server/common/postgres.secret` (mode 600, root-only). It
is never exposed via snap config or shown in any output.

To retrieve it (e.g. for an external psql session):

```bash
sudo snap run atuin-server.get-db-password

# One-liner:
PGPASSWORD=$(sudo snap run atuin-server.get-db-password) \
  psql -h localhost -U atuin atuin
```

## server.toml reference

Full path: `/var/snap/atuin-server/common/server.toml`

| Key | Default | Description |
|-----|---------|-------------|
| `host` | `0.0.0.0` | Address the HTTP server binds to |
| `port` | `8888` | Port the HTTP server listens on |
| `open_registration` | `false` | Allow new account sign-ups |
| `db_uri` | *(unset)* | Database URI — required unless bundled postgres is enabled |
| `max_history_length` | `8192` | Maximum size (bytes) of a history entry |
| `max_record_size` | `1073741824` | Maximum size (bytes) of a record |
| `page_size` | `1100` | Default page size for paginated responses |
| `sync_v1_enabled` | `true` | Enable legacy history-based sync routes |
| `metrics.enable` | `false` | Expose Prometheus `/metrics` endpoint |
| `metrics.host` | `127.0.0.1` | Bind address for the metrics endpoint |
| `metrics.port` | `9001` | Port for the metrics endpoint |

Changes to `server.toml` take effect after restarting the server:

```bash
sudo snap restart atuin-server.server
```

## Client setup

Add the server to your Atuin client config (`~/.config/atuin/config.toml`):

```toml
sync_address = "http://<your-host>:8888"
```

Then register an account:

```bash
atuin register -u <username> -e <email> -p <password>
```

## Concurrent clients

`atuin-server` is built on [axum](https://github.com/tokio-rs/axum) / tokio
and handles many concurrent connections from a single process. With
PostgreSQL (external or bundled) the server is suitable for teams of any
size. SQLite serialises writes and is best suited for personal or small-team
use.

## Linting

```bash
just lint          # shellcheck + yamllint + snapcraft schema validation
just lint-setup    # install lint tools (shellcheck, yamllint, check-jsonschema)
```

## Build from source

Requires [snapcraft](https://snapcraft.io/snapcraft):

```bash
just build                       # build on the local host
just build --destructive-mode    # build without a VM/container
just install                     # install the newest .snap
just remove                      # remove and purge all snap data
just clean                       # delete built .snap files
just clean --destructive-mode    # also clean the snapcraft build cache
```

## File layout

```
/var/snap/atuin-server/common/    ← persists across snap upgrades
├── server.toml                   # atuin-server configuration
├── postgres.conf                 # bundled PostgreSQL settings (port)
├── postgres.secret               # generated DB password (mode 600)
└── atuin.db                      # SQLite database (if db_uri = sqlite://…)

/var/snap/atuin-server/current/   ← revision-scoped runtime state
└── postgres/
    ├── data/                     # PostgreSQL cluster data directory
    ├── run/                      # Unix socket directory (internal)
    └── postgres.log              # PostgreSQL startup log
```

```
