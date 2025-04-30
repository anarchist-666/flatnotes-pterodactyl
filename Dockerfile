ARG BUILD_DIR=/build

# Build Container
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

# Runtime Container
FROM python:3.11-slim-bullseye

ARG BUILD_DIR

# Set environment variables expected by flatnotes
ENV FLATNOTES_HOST=0.0.0.0
ENV FLATNOTES_PORT=8080
ENV APP_PATH=/home/container
ENV FLATNOTES_PATH=/home/container/data
ENV EXEC_TOOL=gosu

# Create the required directories
RUN mkdir -p /home/container /home/container/data

# Create user 'container' with home directory /home/container
RUN useradd -m -d /home/container -u 1000 -s /bin/bash container

# Install dependencies
RUN apt update && apt install -y \
    curl \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir pipenv

# Set working directory
WORKDIR /home/container

# Copy necessary files
COPY LICENSE Pipfile Pipfile.lock ./
RUN pipenv install --deploy --ignore-pipfile --system && \
    pipenv --clear

COPY server ./server
COPY --from=build --chmod=777 ${BUILD_DIR}/client/dist ./client/dist
COPY entrypoint.sh healthcheck.sh /home/container/

# Make entrypoints executable
RUN chmod +x /home/container/entrypoint.sh /home/container/healthcheck.sh

# Change ownership to the 'container' user
RUN chown -R container:container /home/container

# Switch to non-root user
USER container

VOLUME /home/container/data
EXPOSE ${FLATNOTES_PORT}/tcp
HEALTHCHECK --interval=60s --timeout=10s CMD /home/container/healthcheck.sh

ENTRYPOINT [ "/home/container/entrypoint.sh" ]
