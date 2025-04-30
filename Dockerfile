# Build Container
FROM --platform=$BUILDPLATFORM node:20-alpine AS build

ARG BUILD_DIR

RUN mkdir ${BUILD_DIR}
WORKDIR ${BUILD_DIR}

# Copy configuration files
COPY .htmlnanorc \
    package.json \
    package-lock.json \
    postcss.config.js \
    tailwind.config.js \
    vite.config.js \
    ./

# Install dependencies
RUN npm ci

# Copy client code and build
COPY client ./client
RUN npm run build

# Runtime Container
FROM python:3.11-slim-bullseye

ARG BUILD_DIR

# Set environment variables
ENV PUID=1000
ENV PGID=1000
ENV EXEC_TOOL=gosu
ENV FLATNOTES_HOST=0.0.0.0
ENV FLATNOTES_PORT=8080
ENV APP_PATH=/app
ENV FLATNOTES_PATH=/data

# Create the container user and its home directory
RUN adduser --disabled-password --home /home/container --gecos "" container

# Set the user to "container"
USER container
ENV USER=container HOME=/home/container

# Create necessary directories
RUN mkdir -p ${APP_PATH} ${FLATNOTES_PATH}

# Install dependencies for runtime environment
RUN apt update && apt install -y \
    curl \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install pipenv for Python dependency management
RUN pip install --no-cache-dir pipenv

# Set the working directory
WORKDIR ${APP_PATH}

# Copy and install server dependencies
COPY LICENSE Pipfile Pipfile.lock ./
RUN pipenv install --deploy --ignore-pipfile --system && pipenv --clear

# Copy server and build assets
COPY server ./server
COPY --from=build --chmod=777 ${BUILD_DIR}/client/dist ./client/dist

# Copy entrypoint and healthcheck scripts
COPY entrypoint.sh healthcheck.sh / 
RUN chmod +x /entrypoint.sh /healthcheck.sh

# Expose the volume and port
VOLUME /data
EXPOSE ${FLATNOTES_PORT}/tcp

# Define health check
HEALTHCHECK --interval=60s --timeout=10s CMD /healthcheck.sh

# Set the entrypoint for the container
ENTRYPOINT [ "/entrypoint.sh" ]
