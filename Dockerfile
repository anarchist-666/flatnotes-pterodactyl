ARG BUILD_DIR=/build

# -----------------------
# Build Container
# -----------------------
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

# Мы создаем пользователя здесь, но он не перенесется в runtime
# Оставим для симметрии, но не обязательный шаг:
RUN adduser --disabled-password --home /home/container container

# -----------------------
# Runtime Container
# -----------------------
FROM python:3.11-slim-bullseye

ARG BUILD_DIR

ENV EXEC_TOOL=gosu
ENV FLATNOTES_HOST=0.0.0.0
ENV FLATNOTES_PORT=8080

ENV APP_PATH=/app
ENV FLATNOTES_PATH=/data

# Создаем необходимые директории
RUN mkdir -p ${APP_PATH} ${FLATNOTES_PATH}

# Устанавливаем зависимости
RUN apt update && apt install -y \
    curl \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Создаем пользователя container (в runtime!)
RUN adduser --disabled-password --home /home/container container

# Установка pipenv
RUN pip install --no-cache-dir pipenv

WORKDIR ${APP_PATH}

# Копируем Python-зависимости
COPY LICENSE Pipfile Pipfile.lock ./
RUN pipenv install --deploy --ignore-pipfile --system && \
    pipenv --clear

# Копируем сервер и клиент
COPY server ./server
COPY --from=build --chmod=777 ${BUILD_DIR}/client/dist ./client/dist

# Копируем скрипты запуска
COPY entrypoint.sh healthcheck.sh /
RUN chmod +x /entrypoint.sh /healthcheck.sh

# Контейнерная директория и порты
VOLUME /data
EXPOSE ${FLATNOTES_PORT}/tcp

# Здоровье и пользователь
HEALTHCHECK --interval=60s --timeout=10s CMD /healthcheck.sh
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

ENTRYPOINT [ "/entrypoint.sh" ]
