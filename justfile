# justfile — common tasks for atuin-server-snap

# Run all linters
lint: lint-shell lint-yaml lint-snap-schema

# Lint shell scripts and hooks with shellcheck
lint-shell:
    shellcheck snap/local/wrapper-server snap/local/wrapper-postgres snap/local/postgres-initdb snap/local/postgres-daemon snap/local/get-db-password snap/hooks/configure snap/hooks/install

# Lint snapcraft.yaml with yamllint
lint-yaml:
    yamllint -c .yamllint.yaml snap/snapcraft.yaml

# Validate snapcraft.yaml against the upstream snapcraft JSON schema
lint-snap-schema:
    check-jsonschema \
        --schemafile "https://raw.githubusercontent.com/canonical/snapcraft/main/schema/snapcraft.json" \
        snap/snapcraft.yaml

# Install lint dependencies (requires apt)
lint-setup:
    sudo apt-get install -y shellcheck yamllint python3-check-jsonschema

# Build the snap (requires snapcraft to be installed)
build *ARGS:
    snapcraft pack {{ARGS}}

# Install the locally built snap
install:
    sudo snap install --dangerous $(ls -t atuin-server_*.snap | head -1)

# Remove the installed snap
remove:
    sudo snap remove --purge atuin-server

# Quick end-to-end test with bundled postgres
test-bundled-postgres:
    sudo snap set atuin-server postgres.enable=true
    sudo snap start atuin-server.postgres
    sudo snap start atuin-server.server
    @echo "Waiting for server to come up…"
    sleep 5
    curl -sf http://localhost:8888/

# Show snap status
status:
    snap services atuin-server

# Show snap logs
logs:
    snap logs atuin-server -n=50

# Show snap config
config:
    snap get atuin-server

# Clean build artefacts
clean *ARGS:
    rm -f atuin-server_*.snap
    snapcraft clean {{ARGS}}
