#!/bin/sh

# Проверка наличия файлов и копирование их в домашнюю директорию контейнера
if [ ! -f /home/container/server/main.py ]; then
    echo "Copying files to /home/container..."
    cp -r /app/* /home/container/
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


    echo Setting file permissions...
    echo Starting flatnotes as user ${PUID}...
    chown -R ${PUID}:${PGID} ${FLATNOTES_PATH}
    exec ${EXEC_TOOL} ${PUID}:${PGID} ${flatnotes_command}
fi
