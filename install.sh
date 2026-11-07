#!/bin/sh
# 3D Print Studio – Installation mit Docker / installation with Docker
#
#   mkdir 3d-printstudio && cd 3d-printstudio
#   curl -fsSL https://raw.githubusercontent.com/jdeixi/3d-printstudio-install/main/install.sh | sh
#
# Lädt docker-compose.yml und den Update-Container in den aktuellen Ordner, legt eine .env mit neuem
# Schlüssel an (eine vorhandene .env bleibt unverändert) und startet die App.
# Downloads docker-compose.yml and the update container into the current folder, creates a .env with
# a new key (an existing .env is left untouched) and starts the app.
set -eu

BASE="${INSTALL_BASE:-https://raw.githubusercontent.com/jdeixi/3d-printstudio-install/main}"
DIR="$(pwd)"

say() { printf '%s\n' "$*"; }
fail() { say "FEHLER / ERROR: $*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || fail "Docker ist nicht installiert / Docker is not installed."
docker compose version >/dev/null 2>&1 || fail "\"docker compose\" fehlt (Docker Compose v2) / \"docker compose\" missing (Docker Compose v2)."
if command -v curl >/dev/null 2>&1; then
  get() { curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
  get() { wget -qO "$2" "$1"; }
else
  fail "curl oder wget wird benötigt / curl or wget is required."
fi

say "==> Lade Dateien nach $DIR / downloading files to $DIR"
mkdir -p updater backups
get "$BASE/docker-compose.yml" docker-compose.yml
get "$BASE/updater/updater.sh" updater/updater.sh
get "$BASE/.env.example" .env.example

if [ -f .env ]; then
  say "==> .env vorhanden, bleibt unverändert / .env exists, left unchanged"
else
  if command -v openssl >/dev/null 2>&1; then
    KEY="$(openssl rand -hex 32)"
    SLICER="$(openssl rand -hex 24)"
  else
    KEY="$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')"
    SLICER="$(od -An -tx1 -N24 /dev/urandom | tr -d ' \n')"
  fi
  # Einrichtungscode für den ersten Benutzer (8 Zeichen ohne 0/O/1/I) / setup code for the first user
  CODE="$(LC_ALL=C tr -dc 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' < /dev/urandom | head -c 8)"
  CODE="$(printf '%s-%s' "$(printf '%s' "$CODE" | cut -c1-4)" "$(printf '%s' "$CODE" | cut -c5-8)")"
  sed -e "s|^DB_ENCRYPTION_KEY=.*|DB_ENCRYPTION_KEY=$KEY|" -e "s|^PROJECT_DIR=.*|PROJECT_DIR=$DIR|" \
    -e "s|^SETUP_CODE=.*|SETUP_CODE=$CODE|" -e "s|^SLICER_TOKEN=.*|SLICER_TOKEN=$SLICER|" .env.example > .env
  chmod 600 .env
  say "==> .env mit neuem Schlüssel angelegt – bitte zusätzlich sicher aufbewahren"
  say "    .env created with a new key – please also keep a safe copy"
fi

say "==> Starte / starting 3D Print Studio"
docker compose pull --quiet || say "Hinweis: Images nicht aktualisiert / note: images not refreshed"
docker compose up -d

PORT="$(sed -n 's/^APP_PORT=//p' .env | tail -1)"
say ""
say "Fertig / done: http://<server>:${PORT:-3000}/admin"
say "Beim ersten Aufruf legst du den ersten Benutzer an. / On first visit you create the first user."
SETUP="$(sed -n 's/^SETUP_CODE=//p' .env | tail -1)"
if [ -n "$SETUP" ]; then
  say "Einrichtungscode / setup code: $SETUP"
else
  say "Einrichtungscode / setup code: docker compose logs app | grep -i setup"
fi
