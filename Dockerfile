ARG BUILD_DIR=/build

# Build Stage
FROM --platform=$BUILDPLATFORM node:20-alpine AS build

ARG BUILD_DIR
RUN mkdir ${BUILD_DIR}
WORKDIR ${BUILD_DIR}

COPY .htmlnanorc \
    package.json \
    package-lock.json \
    postcss.config.js \
    tailwind.config.js \
    vite.config.js \
    ./

RUN npm ci
COPY client ./client
RUN npm run build

# Runtime Stage
FROM python:3.11-slim-bullseye

ARG BUILD_DIR

ENV FLATNOTES_HOST=0.0.0.0
ENV FLATNOTES_PORT=8080
ENV APP_PATH=/home/container
ENV FLATNOTES_PATH=/home/container/data
ENV EXEC_TOOL=gosu

# Создание нужных директорий
RUN mkdir -p ${APP_PATH} ${FLATNOTES_PATH}

# Установка зависимостей
RUN apt update && apt install -y \
    curl \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Установка Python-зависимостей
RUN pip install --no-cache-dir pipenv

# Создание пользователя container с домашней директорией
RUN useradd -m -d /home/container -u 1000 -s /bin/bash container

WORKDIR ${APP_PATH}

COPY LICENSE Pipfile Pipfile.lock ./
RUN pipenv install --deploy --ignore-pipfile --system && \
    pipenv --clear

COPY server ./server
COPY --from=build --chmod=777 ${BUILD_DIR}/client/dist ./client/dist

# Копирование скриптов в корень, не в /home/container
COPY entrypoint.sh healthcheck.sh /entrypoint.sh /healthcheck.sh
RUN chmod +x /entrypoint.sh /healthcheck.sh

# Выдача прав
RUN chown -R container:container ${APP_PATH}

# Переключение на пользователя container
USER container

# Настройки Pterodactyl
VOLUME /home/container/data
EXPOSE ${FLATNOTES_PORT}/tcp
HEALTHCHECK --interval=60s --timeout=10s CMD /healthcheck.sh
ENTRYPOINT ["/entrypoint.sh"]
