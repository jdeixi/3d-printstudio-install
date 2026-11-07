#!/bin/sh
# Update-Container (Dienst "updater" in docker-compose.yml). Nur dieser kleine Container hat Zugriff
# auf Docker - die App selbst bewusst nicht (Docker-Zugriff ist faktisch Root auf der NAS). Die App
# legt einen Auftrag als Datei in das gemeinsame Volume (update-ctl), der Updater führt ihn aus:
#
#   1. Image ghcr.io/...:<version> laden (öffentliches Image ohne Anmeldung, sonst docker login ghcr.io)
#   2. docker-compose.yml (nur mit COMPOSE_IN_IMAGE, Installation beim Kunden) und dieses Skript aus dem
#      neuen Image übernehmen (falls geändert)
#   3. APP_VERSION in .env setzen, App-Container neu starten
#   4. warten, bis /api/health die neue Version meldet - sonst zurück auf die vorige Version
#
# Außerdem prüft er die App jede Minute (/api/health): hängt sie dreimal hintereinander, wird sie neu
# gestartet; jeder Ausfall wird in outages.log protokolliert, die App meldet ihn danach per Push.
#
# Status für die App: status.json (state: pulling|restarting|checking|done|rolled-back|failed),
# Lebenszeichen: updater.json (alle 5 s), Protokoll: update.log.
set -u

CTL=/ctl
IMAGE="${IMAGE:-ghcr.io/jdeixi/3d-printstudio}"
PROJECT_DIR="${PROJECT_DIR:?PROJECT_DIR fehlt}"
PROJECT="${COMPOSE_PROJECT_NAME:-3d-printstudio}"
SERVICE="${APP_SERVICE:-app}"
HEALTH_URL="${HEALTH_URL:-http://app:3000/api/health}"
ENV_FILE="$PROJECT_DIR/.env"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
SELF="$PROJECT_DIR/updater/updater.sh"
APP_CONTAINER="${APP_CONTAINER:-$PROJECT-$SERVICE-1}"
# Dateien im Image (siehe Dockerfile, Ordner install/). Ohne COMPOSE_IN_IMAGE bleibt die
# docker-compose.yml unverändert (Betreiber-NAS: kommt per scripts/deploy-nas.sh).
COMPOSE_IN_IMAGE="${COMPOSE_IN_IMAGE:-}"
UPDATER_IN_IMAGE="${UPDATER_IN_IMAGE:-/app/install/updater.sh}"
OVERRIDE_FILE="$PROJECT_DIR/docker-compose.override.yml"
UPDATER_VERSION=2

ID=""
FROM=""
TO=""

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$CTL/update.log"
}

status() { # state message
  msg=$(printf '%s' "$2" | tr '"\\' "''")
  printf '{"id":"%s","state":"%s","message":"%s","from":"%s","to":"%s","at":%s}\n' \
    "$ID" "$1" "$msg" "$FROM" "$TO" "$(date +%s)" > "$CTL/status.json.tmp" && mv "$CTL/status.json.tmp" "$CTL/status.json"
}

heartbeat() {
  printf '{"version":%s,"at":%s}\n' "$UPDATER_VERSION" "$(date +%s)" > "$CTL/updater.json.tmp" && mv "$CTL/updater.json.tmp" "$CTL/updater.json"
}

compose() {
  if [ -f "$OVERRIDE_FILE" ]; then
    docker compose -p "$PROJECT" --project-directory "$PROJECT_DIR" -f "$COMPOSE_FILE" -f "$OVERRIDE_FILE" --env-file "$ENV_FILE" "$@"
  else
    docker compose -p "$PROJECT" --project-directory "$PROJECT_DIR" -f "$COMPOSE_FILE" --env-file "$ENV_FILE" "$@"
  fi
}

current_version() {
  sed -n 's/^APP_VERSION=//p' "$ENV_FILE" | tail -1
}

set_version() {
  if grep -q '^APP_VERSION=' "$ENV_FILE"; then
    sed -i "s/^APP_VERSION=.*/APP_VERSION=$1/" "$ENV_FILE"
  else
    echo "APP_VERSION=$1" >> "$ENV_FILE"
  fi
}

healthy() { # version - bis zu 3 Minuten warten (Migrationen beim Start)
  i=0
  while [ "$i" -lt 36 ]; do
    body=$(wget -qO- -T 5 "$HEALTH_URL" 2>/dev/null || true)
    case "$body" in
      *'"ok":true'*"\"version\":\"$1\""*) return 0 ;;
    esac
    i=$((i + 1))
    sleep 5
  done
  return 1
}

# docker-compose.yml und updater.sh aus dem neuen Image holen (nach $CTL/*.new). Fehlen sie im Image,
# bleiben die bisherigen Dateien (nur Hinweis im Protokoll).
fetch_files() {
  rm -f "$CTL/compose.new" "$CTL/updater.new"
  cid=$(docker create "$IMAGE:$1" 2>>"$CTL/update.log") || return 1
  if [ -n "$COMPOSE_IN_IMAGE" ]; then
    docker cp "$cid:$COMPOSE_IN_IMAGE" "$CTL/compose.new" >/dev/null 2>&1 || log "Hinweis: keine docker-compose.yml im Image"
  fi
  docker cp "$cid:$UPDATER_IN_IMAGE" "$CTL/updater.new" >/dev/null 2>&1 || log "Hinweis: kein updater.sh im Image"
  docker rm "$cid" >/dev/null 2>&1
  return 0
}

run_update() {
  FROM=$(current_version)
  if ! printf '%s' "$TO" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    status failed "Ungültige Version: $TO"
    return
  fi
  if [ "$TO" = "$FROM" ]; then
    status done "Version $TO ist bereits installiert."
    return
  fi

  log "Update $FROM -> $TO"
  status pulling "Lade Version $TO ..."
  if ! docker pull "$IMAGE:$TO" >>"$CTL/update.log" 2>&1; then
    log "Image $IMAGE:$TO nicht ladbar"
    status failed "Version $TO konnte nicht geladen werden (Internetverbindung? Siehe update.log)."
    return
  fi
  if ! fetch_files "$TO"; then
    status failed "Dateien aus dem Image $TO nicht lesbar (siehe update.log)."
    return
  fi

  cp "$COMPOSE_FILE" "$CTL/compose.prev"
  if [ -s "$CTL/compose.new" ] && ! cmp -s "$CTL/compose.new" "$COMPOSE_FILE"; then
    log "docker-compose.yml aus Version $TO übernommen"
    cp "$CTL/compose.new" "$COMPOSE_FILE"
  fi
  set_version "$TO"

  status restarting "Starte Version $TO ..."
  compose up -d --no-deps "$SERVICE" >>"$CTL/update.log" 2>&1
  status checking "Prüfe Version $TO ..."
  if healthy "$TO"; then
    log "Version $TO läuft"
    # Optionaler Slicer-Dienst: läuft er, mit der (evtl. neuen) Version aus der Compose-Datei neu
    # starten. Ein Fehler hier rollt die App nicht zurück.
    if [ -n "$(docker ps -q --filter "label=com.docker.compose.project=$PROJECT" --filter "label=com.docker.compose.service=slicer")" ]; then
      compose up -d --no-deps slicer >>"$CTL/update.log" 2>&1 || log "Slicer-Dienst konnte nicht aktualisiert werden"
    fi
    status done "Version $TO ist installiert."
    if [ -s "$CTL/updater.new" ] && ! cmp -s "$CTL/updater.new" "$SELF"; then
      # Neues Updater-Skript: übernehmen und beenden - Docker startet den Container damit neu.
      log "Updater-Skript aus Version $TO übernommen, Neustart"
      cp "$CTL/updater.new" "$SELF"
      exit 0
    fi
    return
  fi

  log "Version $TO meldet sich nicht - zurück auf $FROM"
  cp "$CTL/compose.prev" "$COMPOSE_FILE"
  set_version "$FROM"
  compose up -d --no-deps "$SERVICE" >>"$CTL/update.log" 2>&1
  if healthy "$FROM"; then
    status rolled-back "Version $TO startete nicht korrekt - Version $FROM läuft wieder (siehe update.log)."
  else
    status failed "Version $TO startete nicht, und $FROM meldet sich ebenfalls nicht - bitte auf der NAS prüfen."
  fi
}

# --- Registry-Anmeldung ---------------------------------------------------------------------------
# Einmal täglich: Ist der Token für ghcr.io noch gültig, und wann läuft er ab? Das Ablaufdatum
# meldet GitHub im Header "github-authentication-token-expiration". Der Token selbst wird weder
# protokolliert noch weitergegeben; Ergebnis nach registry.json für den Update-Reiter.
LAST_REGISTRY=0

# Ohne gespeicherte Anmeldung: ist das Image öffentlich ladbar? (anonymer Token + Manifest von "latest")
image_public() {
  case "$IMAGE" in ghcr.io/*) ;; *) return 1 ;; esac
  repo=${IMAGE#ghcr.io/}
  tok=$(wget -qO- -T 10 "https://ghcr.io/token?scope=repository:$repo:pull" 2>/dev/null | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
  [ -n "$tok" ] || return 1
  wget -q -O /dev/null -T 10 --header "Authorization: Bearer $tok" \
    --header "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json" \
    "https://ghcr.io/v2/$repo/manifests/latest" 2>/dev/null
}

check_registry() {
  cfg=/root/.docker/config.json
  auth=$(tr -d '\n\t\r ' < "$cfg" 2>/dev/null | sed -n 's/.*"ghcr.io":{"auth":"\([^"]*\)".*/\1/p')
  if [ -z "$auth" ]; then
    if image_public; then
      printf '{"ok":true,"public":true,"expires":"","message":"","at":%s}\n' "$(date +%s)" > "$CTL/registry.json"
    else
      printf '{"ok":false,"expires":"","message":"Keine Anmeldung bei ghcr.io gespeichert","at":%s}\n' "$(date +%s)" > "$CTL/registry.json"
    fi
    return
  fi
  token=$(printf '%s' "$auth" | base64 -d 2>/dev/null | cut -d: -f2-)
  headers=$(wget -S -q -O /dev/null --header "Authorization: Bearer $token" https://api.github.com/user 2>&1)
  token=""
  status=$(printf '%s' "$headers" | sed -n 's/^ *HTTP\/[0-9.]* \([0-9]*\).*/\1/p' | tail -1)
  expires=$(printf '%s' "$headers" | sed -n 's/^ *[Gg]ithub-[Aa]uthentication-[Tt]oken-[Ee]xpiration: *\(.*\)$/\1/p' | tr -d '\r' | head -1)
  if [ "$status" = "200" ]; then
    printf '{"ok":true,"expires":"%s","message":"","at":%s}\n' "$expires" "$(date +%s)" > "$CTL/registry.json"
  else
    printf '{"ok":false,"expires":"%s","message":"Token für ghcr.io ungültig oder abgelaufen (HTTP %s)","at":%s}\n' "$expires" "${status:-?}" "$(date +%s)" > "$CTL/registry.json"
  fi
}

# --- Überwachung -------------------------------------------------------------------------------
FAILS=0
OUTAGE_START=""
LAST_WATCH=0

watch_app() {
  state=$(docker inspect -f '{{.State.Status}}' "$APP_CONTAINER" 2>/dev/null || echo missing)
  case "$state" in
    running | restarting) ;;
    *) # bewusst gestoppt oder (noch) nicht angelegt - nichts tun
      FAILS=0
      return ;;
  esac
  if [ "$state" = "running" ] && wget -qO- -T 10 "$HEALTH_URL" 2>/dev/null | grep -q '"ok":true'; then
    if [ -n "$OUTAGE_START" ]; then
      echo "$OUTAGE_START $(date +%s)" >> "$CTL/outages.log"
      log "App wieder erreichbar"
      OUTAGE_START=""
    fi
    FAILS=0
    return
  fi
  FAILS=$((FAILS + 1))
  [ -z "$OUTAGE_START" ] && OUTAGE_START=$(date +%s) && log "App antwortet nicht ($state)"
  if [ "$FAILS" -ge 3 ] && [ "$state" = "running" ]; then
    log "App hängt seit 3 Prüfungen - Neustart"
    docker restart "$APP_CONTAINER" >>"$CTL/update.log" 2>&1
    FAILS=0
  fi
}

mkdir -p "$CTL"
touch "$CTL/update.log"
# Protokoll klein halten
tail -n 500 "$CTL/update.log" > "$CTL/update.log.tmp" && mv "$CTL/update.log.tmp" "$CTL/update.log"
log "Updater bereit (Projekt $PROJECT, Image $IMAGE)"

while true; do
  heartbeat
  if [ -f "$CTL/request" ]; then
    TO=$(head -c 40 "$CTL/request" | tr -cd '0-9.')
    ID=$(date +%s)
    rm -f "$CTL/request"
    run_update
    LAST_WATCH=$(date +%s)
  fi
  now=$(date +%s)
  if [ $((now - LAST_REGISTRY)) -ge 86400 ]; then
    LAST_REGISTRY=$now
    check_registry
  fi
  if [ $((now - LAST_WATCH)) -ge 60 ]; then
    LAST_WATCH=$now
    watch_app
  fi
  sleep 5
done
