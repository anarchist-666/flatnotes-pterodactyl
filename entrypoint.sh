#!/bin/sh

# Проверка и создание данных
if [ ! -f /home/container/server/main.py ]; then
    echo "Copying files to /home/container..."
    cp -r /app/* /home/container/
fi

# Проверка прав на директорию
if [ ! -w "${FLATNOTES_PATH}" ]; then
    echo "WARNING: No write access to ${FLATNOTES_PATH} for UID $(id -u)"
    ls -ld "${FLATNOTES_PATH}"
    exit 1
fi

cd /home/container

[ "$EXEC_TOOL" ] || EXEC_TOOL=gosu
[ "$FLATNOTES_HOST" ] || FLATNOTES_HOST=0.0.0.0
[ "$FLATNOTES_PORT" ] || FLATNOTES_PORT=8080

set -e

echo "\
======================================
======== Welcome to flatnotes ========
======================================

If you enjoy using flatnotes, please
consider sponsoring the project at:

https://sponsor.flatnotes.io

It would really make my day 🙏.

──────────────────────────────────────
"

flatnotes_command="python -m \
                  uvicorn \
                  main:app \
                  --app-dir server \
                  --host ${FLATNOTES_HOST} \
                  --port ${FLATNOTES_PORT} \
                  --proxy-headers \
                  --forwarded-allow-ips '*'"


if [ `id -u` -eq 0 ] && [ `id -g` -eq 0 ]; then
    echo Setting file permissions...
    chown -R ${PUID}:${PGID} ${FLATNOTES_PATH}

    echo Starting flatnotes as user ${PUID}...
    exec ${EXEC_TOOL} ${PUID}:${PGID} ${flatnotes_command}

else
    echo "A user was set by docker, skipping file permission changes."
    echo Starting flatnotes as user $(id -u)...
    exec ${flatnotes_command}
fi
