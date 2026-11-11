# 3D Print Studio

**Deutsch** · [English](#english)

Kalkulation, Verwaltung und Abwicklung rund um den 3D-Druck als Dienstleistung – vom Kostenrechner
über Druckaufträge, Filament- und Lagerverwaltung bis zu Angeboten, Rechnungen, Versand,
Kundenportal und Online-Shop. Die App läuft im Browser: auf einem Server oder einer NAS mit Docker,
oder als Desktop-App für Windows, macOS und Linux.

**Demo ausprobieren:** <https://demo.customprints.deixler.space> – mit Beispieldaten, der Demo-Zugang steht
auf der Anmeldeseite, alles wird täglich zurückgesetzt.

Dieses Repository enthält nur die Dateien für die Installation. Das fertige Programm wird als
Docker-Image geladen (`ghcr.io/jdeixi/3d-printstudio`).

## Lizenz und Support

3D Print Studio ist kostenlos und steht unter der **Apache License 2.0** (Datei `LICENSE`) – ohne Lizenzschlüssel,
ohne Testphase, alle Funktionen frei. Copyright 2026 Jürgen Deixler; Hinweise zu Fremdsoftware in `NOTICE`.
Der Slicer-Dienst im Docker-Image enthält OrcaSlicer (AGPL-3.0, eigenes Programm; Lizenztext und
Quellcode-Hinweis im Image unter `/opt/orca`).

Fragen und Fehler: in der App unter Info → „Hilfe & Support“ (öffnet ein vorausgefülltes Issue) oder direkt
unter **Issues** in diesem Repository.

## Installation mit Docker (Server, NAS)

Voraussetzungen: Docker mit Docker Compose v2, ein 64-Bit-System (Intel/AMD oder ARM64), Internetzugang. ARM64 ist neu
und bisher nur mit Docker auf einem Apple-Silicon-Mac geprüft, nicht auf einem Raspberry Pi oder einer ARM-NAS. Rückmeldungen
dazu gern als Issue.

```bash
mkdir 3d-printstudio && cd 3d-printstudio
curl -fsSL https://raw.githubusercontent.com/jdeixi/3d-printstudio-install/main/install.sh | sh
```

Läuft Docker nur mit Administratorrechten (z. B. auf einer Synology NAS), am Ende `| sudo sh`
schreiben. Das Skript lädt `docker-compose.yml` und den Update-Container in den Ordner, legt eine
`.env` mit einem neuen Schlüssel an und startet die App.

Danach im Browser **http://\<server\>:3000/admin** öffnen und den ersten Benutzer anlegen. Dafür fragt die
Seite nach dem **Einrichtungscode**, den das Skript am Ende anzeigt (steht auch in der `.env` unter
`SETUP_CODE`) – so kann niemand anderes das erste Admin-Konto anlegen, falls der Server aus dem Internet
erreichbar ist.

> **Wichtig:** Die `.env` enthält den Schlüssel `DB_ENCRYPTION_KEY`, mit dem Zugangsdaten (E-Mail,
> Zahlungsanbieter …) verschlüsselt sind. Bitte zusätzlich sicher aufbewahren.

### Von Hand

1. `docker-compose.yml`, `updater/updater.sh` und `.env.example` aus diesem Repository in einen
   Ordner laden, `.env.example` als `.env` speichern.
2. In der `.env` setzen: `DB_ENCRYPTION_KEY` (erzeugen mit `openssl rand -hex 32`) und
   `PROJECT_DIR` (absoluter Pfad des Ordners).
3. `docker compose up -d`

### Updates

In der App unter **Grundeinstellungen → Update**: „Jetzt aktualisieren“ oder „Automatisch aktualisieren“ (nachts). Der
Update-Container lädt die neue Version, startet die App neu und kehrt zur vorigen Version zurück,
wenn die neue nicht startet. Von Hand: `APP_VERSION` in der `.env` setzen, dann
`docker compose up -d`.

### Daten und Sicherung

- Datenbank und hochgeladene Dateien liegen im Docker-Volume `3d-printstudio_app-data`.
- Die App sichert sich täglich selbst in den Ordner `backups/` (einstellbar unter Grundeinstellungen
  → Import / Export). Diesen Ordner zusätzlich auf ein anderes Laufwerk oder extern sichern.
- Eine Sicherung enthält alle Daten und die gespeicherten Zugangsdaten. Unter Grundeinstellungen → Import /
  Export → Verschlüsselung lässt sie sich mit einem Passwort verschlüsseln (Dateien `…zip.enc`). Das Passwort
  getrennt von den Sicherungen aufbewahren: Ohne es ist eine verschlüsselte Sicherung nicht mehr lesbar.
  Entschlüsseln geht auch ohne die App, mit `openssl` (fragt nach dem Passwort):
  `openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 -in sicherung.zip.enc -out sicherung.zip`
- Die Kopien der Datenbank in `backups/vor-migration/` (nächster Punkt) sind nicht verschlüsselt; sie bleiben
  auf dem Server und gehen nicht an den zweiten Speicherort.
- Bringt ein Update Änderungen an der Datenbank mit, legt die App beim Start vorher eine Kopie der
  Datenbank in `backups/vor-migration/` an (die letzten fünf bleiben). Klappt das nicht, startet die neue
  Version nicht und der Update-Container stellt die vorige wieder her. Zurückspielen (App gestoppt, mit der
  vorigen Version in `.env`):
  `docker run --rm -v 3d-printstudio_app-data:/data -v "$PWD/backups/vor-migration:/b:ro" alpine cp /b/<datei>.db /data/dev.db`
- Eigene Anpassungen (Port, zusätzliche Ordner) in eine `docker-compose.override.yml` schreiben – die
  `docker-compose.yml` wird bei Updates ersetzt.
- Die App läuft im Container ohne Root-Rechte als eigener Benutzer (Nummer 10002) und übernimmt beim Start ihre
  Ordner; die Dateien in `backups/` und `modell-eingang/` gehören danach diesem Benutzer. Gehört einer der Ordner
  einem Benutzer deines Servers oder ist ein zusätzlich eingehängter Ordner nur für root beschreibbar, läuft sie
  wie früher als root weiter und nennt den Grund im Protokoll (`docker compose logs app`). Wie sie läuft, steht
  auch in der App unter Info → System. Einstellen lässt es sich in der `.env` mit `APP_UID`/`APP_GID` (als
  dieser Benutzer laufen) oder `APP_RUN_AS_ROOT=1` (ausdrücklich als root).

### Sofort-Preis aus 3D-Modellen (optional)

Mit dem Slicer-Dienst (OrcaSlicer) berechnet die App Preise direkt aus 3D-Modellen (STL, 3MF, OBJ) – im
Kundenportal mit 3D-Vorschau. Einschalten: in der `.env` `COMPOSE_PROFILES=slicer` setzen (das Token
`SLICER_TOKEN` legt `install.sh` an; bei älteren Installationen mit `openssl rand -hex 24` erzeugen), dann
`docker compose up -d`. Danach in der App unter Grundeinstellungen → 3D Drucker Modelle die Profile wählen.
Der Dienst steckt im selben Image wie die App (kein zusätzlicher Download), läuft aber in einem eigenen
Container ohne Internetzugang und ist nur für die App erreichbar.

### Zugriff aus dem Internet

Für das Kundenportal und den Online-Shop die App hinter einen Reverse Proxy mit HTTPS stellen (z. B.
Caddy, Traefik, Nginx Proxy Manager oder den Reverse Proxy der Synology). Der Mitarbeiterbereich
liegt unter `/admin`; er sollte zusätzlich geschützt werden (z. B. Zwei-Faktor-Anmeldung vor dem
Proxy). Details im Handbuch, Kapitel 2.

Die App begrenzt Anmeldeversuche und Ähnliches je Besucher-Adresse. Dafür nimmt sie die Adresse, die der Proxy
im Header `X-Forwarded-For` anhängt; mit einem Proxy passt das von selbst. Steht davor ein weiterer mit
öffentlicher Adresse (z. B. Cloudflare), in der `.env` `TRUSTED_PROXY_HOPS=2` setzen, sonst zählen viele
Besucher gemeinsam (die App weist unter Info → System darauf hin). Der Port der App selbst (3000) sollte nicht
aus dem Internet erreichbar sein, nur der Proxy.

#### Eigenes Proxy-Netzwerk und eigener Datenordner

Beides geht über eine `docker-compose.override.yml`, die Updates nicht anfassen und der Update-Container
berücksichtigt. Sie muss **vor** der Installation im Ordner liegen. `proxy` ist der Name des vorhandenen Netzwerks:

```yaml
services:
  app:
    ports: !reset []          # kein Port auf dem Host (braucht Docker Compose 2.24 oder neuer)
    volumes:
      - ./data:/app/data      # Datenbank und Uploads im Ordner statt im Docker-Volume
    networks:
      - proxy

networks:
  proxy:
    external: true
```

Der Installationsordner kann dabei auf einer eigenen Platte liegen, z. B. `/storage/3dprintstudio`; `install.sh` trägt
ihn selbst als `PROJECT_DIR` ein. Im Reverse Proxy (z. B. Nginx Proxy Manager) als Ziel `http`,
`3d-printstudio-app-1`, Port `3000` eintragen. Die App läuft im Container als root, die Dateien im Ordner gehören also
meist root. `data/` nur bei gestoppter App kopieren.

Der Reverse Proxy muss die echte Adresse der Besucher weitergeben (Header `X-Forwarded-For`) – davon
hängen die Schutzgrenzen gegen Passwort-Raten und Missbrauch ab. Läuft er selbst als Docker-Container,
sehen manche Systeme (z. B. Synology Container Manager) statt der echten Adresse nur die interne
Docker-Adresse; die App warnt dann unter Info → System. Abhilfe: den Proxy-Container im Host-Netzwerk
betreiben (`network_mode: host`) oder den Reverse Proxy der NAS selbst verwenden.

## Desktop-App

Installationsdateien für Windows, macOS und Linux stehen unter
[Releases](https://github.com/jdeixi/3d-printstudio-install/releases). Die Desktop-App ist für eine
Person an einem Rechner gedacht; für mehrere Benutzer, Kundenportal und Shop die Docker-Installation
verwenden.

## Handbuch

Das Benutzerhandbuch (Deutsch, Englisch, Französisch und Italienisch, PDF) liegt bei jeder Version unter
[Releases](https://github.com/jdeixi/3d-printstudio-install/releases).

## Beispieldaten

Im Ordner [`beispieldaten`](beispieldaten) liegen Filament-Typen, Hersteller, 71 Filamente und Verbrauchsmaterial
zum Einlesen, als größere Auswahl neben den 13 Beispiel-Filamenten einer neuen Installation. Die Anleitung steht
dort in der `README.md`.

---

<a id="english"></a>

# 3D Print Studio (English)

Costing, management and handling for 3D printing as a service – from the cost calculator to print
jobs, filament and inventory management, quotes, invoices, shipping, customer portal and online
shop. The app runs in the browser: on a server or NAS with Docker, or as a desktop app for Windows,
macOS and Linux.

**Try the demo:** <https://demo.customprints.deixler.space> – with sample data, the demo login is shown on
the sign-in page, everything is reset daily.

This repository only contains the installation files. The app itself is pulled as a Docker image
(`ghcr.io/jdeixi/3d-printstudio`).

## License and support

3D Print Studio is free of charge and licensed under the **Apache License 2.0** (file `LICENSE`) – no license key, no
trial period, all features free. Copyright 2026 Jürgen Deixler; notices on third-party software in
`NOTICE`. The slicer service in the Docker image contains OrcaSlicer (AGPL-3.0, a separate program;
license text and source code notice in the image under `/opt/orca`).

Questions and bugs: in the app under Info → “Help & support” (opens a pre-filled issue) or directly under
**Issues** in this repository.

## Installation with Docker (server, NAS)

Requirements: Docker with Docker Compose v2, a 64-bit system (Intel/AMD or ARM64), internet access. ARM64 is new and has
only been checked with Docker on an Apple Silicon Mac so far, not on a Raspberry Pi or an ARM NAS. Feedback is welcome as an
issue.

```bash
mkdir 3d-printstudio && cd 3d-printstudio
curl -fsSL https://raw.githubusercontent.com/jdeixi/3d-printstudio-install/main/install.sh | sh
```

If Docker needs admin rights (e.g. on a Synology NAS), end with `| sudo sh`. The script downloads
`docker-compose.yml` and the update container into the folder, creates a `.env` with a new key and
starts the app.

Then open **http://\<server\>:3000/admin** in the browser and create the first user. The page asks for the
**setup code** shown at the end of the script (also in `.env` under `SETUP_CODE`) – so nobody else can
create the first admin account if the server is reachable from the internet.

> **Important:** the `.env` contains the key `DB_ENCRYPTION_KEY` that encrypts credentials (email,
> payment providers …). Please keep an additional safe copy.

### Manually

1. Download `docker-compose.yml`, `updater/updater.sh` and `.env.example` from this repository into a
   folder, save `.env.example` as `.env`.
2. In `.env` set `DB_ENCRYPTION_KEY` (create with `openssl rand -hex 32`) and `PROJECT_DIR`
   (absolute path of the folder).
3. `docker compose up -d`

### Updates

In the app under **Basic settings → Update**: “Update to v… now” or “Automatic updates” (at night). The update
container pulls the new version, restarts the app and returns to the previous version if the new one
doesn't start. Manually: set `APP_VERSION` in `.env`, then `docker compose up -d`.

### Data and backup

- Database and uploaded files live in the Docker volume `3d-printstudio_app-data`.
- The app backs itself up daily into the `backups/` folder (configurable under Basic settings →
  Import / Export). Also back this folder up to another drive or off-site.
- A backup contains all data and the stored credentials. Under Basic settings → Import / Export → Encryption
  you can encrypt it with a password (files `…zip.enc`). Keep the password separate from the backups: without
  it an encrypted backup can no longer be read. Decrypting also works without the app, with `openssl` (it asks
  for the password):
  `openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 -in backup.zip.enc -out backup.zip`
- The database copies in `backups/vor-migration/` (next item) are not encrypted; they stay on the server and
  are not sent to the second storage location.
- If an update changes the database, the app first saves a copy of the database to
  `backups/vor-migration/` on start (the last five are kept). If that fails, the new version does not
  start and the update container restores the previous one. To restore (app stopped, previous version in
  `.env`):
  `docker run --rm -v 3d-printstudio_app-data:/data -v "$PWD/backups/vor-migration:/b:ro" alpine cp /b/<file>.db /data/dev.db`
- Put your own changes (port, extra folders) into a `docker-compose.override.yml` – the
  `docker-compose.yml` is replaced on updates.
- The app runs inside the container without root as its own user (number 10002) and takes over its folders on
  start; the files in `backups/` and `modell-eingang/` then belong to that user. If one of the folders belongs
  to a user of your server, or an additionally mounted folder is writable for root only, it keeps running as
  root like before and states the reason in the log (`docker compose logs app`). How it runs is also shown in
  the app under Info → System. You can set it in `.env` with `APP_UID`/`APP_GID` (run as that user) or
  `APP_RUN_AS_ROOT=1` (root explicitly).

### Instant price from 3D models (optional)

With the slicer service (OrcaSlicer) the app calculates prices directly from 3D models (STL, 3MF, OBJ) – in
the customer portal with a 3D preview. To enable: set `COMPOSE_PROFILES=slicer` in `.env` (`install.sh`
creates the token `SLICER_TOKEN`; for older installations create it with `openssl rand -hex 24`), then
`docker compose up -d`. Then choose the profiles in the app under Basic settings → 3D printer models. The
service is part of the app image (no extra download) but runs in its own container without internet
access and can only be reached by the app.

### Access from the internet

For the customer portal and online shop, put the app behind a reverse proxy with HTTPS (e.g. Caddy,
Traefik, Nginx Proxy Manager or the Synology reverse proxy). The staff area is under `/admin`; protect
it additionally (e.g. two-factor sign-in in front of the proxy). Details in the manual, chapter 2.

The app limits sign-in attempts and the like per visitor address. It uses the address the proxy appends to the
`X-Forwarded-For` header; with a single proxy this works by itself. If another one with a public address sits in
front (e.g. Cloudflare), set `TRUSTED_PROXY_HOPS=2` in the `.env` file, otherwise many visitors count together
(the app points it out under Info → System). The port of the app itself (3000) should not be reachable from the
internet, only the proxy.

#### Own proxy network and own data folder

Both work with a `docker-compose.override.yml`, which updates leave alone and the update container respects. It has to
be in the folder **before** the installation. `proxy` is the name of your existing network:

```yaml
services:
  app:
    ports: !reset []          # no port on the host (needs Docker Compose 2.24 or newer)
    volumes:
      - ./data:/app/data      # database and uploads in the folder instead of the Docker volume
    networks:
      - proxy

networks:
  proxy:
    external: true
```

The installation folder can be on a disk of its own, e.g. `/storage/3dprintstudio`; `install.sh` sets it as `PROJECT_DIR`
by itself. In the reverse proxy (e.g. Nginx Proxy Manager) enter the target `http`, `3d-printstudio-app-1`, port `3000`.
The app runs as root inside the container, so the files in the folder usually belong to root. Only copy `data/` while
the app is stopped.

The reverse proxy must pass on the real address of visitors (header `X-Forwarded-For`) – the limits
that protect against password guessing and abuse depend on it. If the proxy itself runs as a Docker
container, some systems (e.g. Synology Container Manager) only show the internal Docker address instead
of the real one; the app then warns under Info → System. Fix: run the proxy container in the host
network (`network_mode: host`) or use the NAS's own reverse proxy.

## Desktop app

Installers for Windows, macOS and Linux are under
[Releases](https://github.com/jdeixi/3d-printstudio-install/releases). The desktop app is meant for
one person on one computer; for several users, customer portal and shop use the Docker installation.

## Manual

The user manual (German, English, French and Italian, PDF) is attached to every version under
[Releases](https://github.com/jdeixi/3d-printstudio-install/releases).

## Sample data

The folder [`beispieldaten`](beispieldaten) holds filament types, manufacturers, 71 filaments and consumables
to import, as a larger selection next to the 13 example filaments of a new installation. The instructions are in
its `README.md`.
