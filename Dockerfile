# Build Container
FROM --platform=$BUILDPLATFORM node:20-alpine AS build

ARG BUILD_DIR=/build

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

# Runtime Container
FROM python:3.11-slim-bullseye

ARG BUILD_DIR

ENV PUID=1000
ENV PGID=1000
ENV EXEC_TOOL=gosu
ENV FLATNOTES_HOST=0.0.0.0
ENV FLATNOTES_PORT=8080

ENV APP_PATH=/app
ENV FLATNOTES_PATH=/data

# Создаем пользователя container с домашним каталогом /home/container
RUN useradd -m -d /home/container container

# Создаем необходимые каталоги
RUN mkdir -p ${APP_PATH} ${FLATNOTES_PATH}

RUN apt update && apt install -y \
    curl \
    gosu \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir pipenv

WORKDIR ${APP_PATH}

COPY LICENSE Pipfile Pipfile.lock ./ 
RUN pipenv install --deploy --ignore-pipfile --system && \
    pipenv --clear

COPY server ./server
COPY --from=build --chmod=777 ${BUILD_DIR}/client/dist ./client/dist

COPY entrypoint.sh healthcheck.sh / 
RUN chmod +x /entrypoint.sh /healthcheck.sh

# Устанавливаем владельца каталогов
RUN chown -R container:container /home/container /app /data

# Устанавливаем пользователя container
USER container

VOLUME /data
EXPOSE ${FLATNOTES_PORT}/tcp
HEALTHCHECK --interval=60s --timeout=10s CMD /healthcheck.sh

ENTRYPOINT [ "/entrypoint.sh" ]
