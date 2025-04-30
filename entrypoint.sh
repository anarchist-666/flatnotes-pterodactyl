#!/bin/sh

# Проверка наличия файлов и копирование их в домашнюю директорию контейнера
if [ ! -f /home/container/server/main.py ]; then
    echo "Copying files to /home/container..."
    cp -r /app/* /home/container/
fi

# Переменные по умолчанию
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

# Убедимся, что каталоги для Flatnotes существуют и принадлежат правильному пользователю
mkdir -p /home/container/data/.flatnotes
chown -R 1000:1000 /home/container

# Команда для запуска приложения
flatnotes_command="python -m \
                  uvicorn \
                  main:app \
                  --app-dir server \
                  --host ${FLATNOTES_HOST} \
                  --port ${FLATNOTES_PORT} \
                  --proxy-headers \
                  --forwarded-allow-ips '*'"

# Запуск от имени пользователя container (UID=1000)
echo "Starting flatnotes as user $(id -u)..."
exec su-exec container ${flatnotes_command}
