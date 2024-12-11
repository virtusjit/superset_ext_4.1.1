######################################################################
# Official Superset image
######################################################################
FROM apachesuperset.docker.scarf.sh/apache/superset:latest AS superset-official

######################################################################
# Node stage to deal with static asset construction
######################################################################
# if BUILDPLATFORM is null, set it to 'amd64' (or leave as is otherwise).
ARG BUILDPLATFORM=linux/amd64
#FROM --platform=${BUILDPLATFORM} node:16-bookworm-slim AS superset-node
FROM --platform=${BUILDPLATFORM} node:20-bookworm-slim AS superset-node


ARG NPM_BUILD_CMD="build"
ENV BUILD_CMD=${NPM_BUILD_CMD}

# NPM ci first, as to NOT invalidate previous steps except for when package.json changes
RUN mkdir -p /app/superset-frontend

WORKDIR /app/superset-frontend/

COPY superset_ext_0.1.0/superset-frontend/package*.json ./

RUN echo 'deb http://mirror.yandex.ru/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://mirror.yandex.ru/debian/ bookworm main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

deb http://mirror.yandex.ru/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://mirror.yandex.ru/debian/ bookworm-updates main contrib non-free non-free-firmware' > /etc/apt/sources.list

RUN apt-get update && \
    apt-get install -y zstd && \
    rm -rf /var/lib/apt/lists/*

RUN npm config set registry http://registry.npmjs.org/ && \
    npm config set fetch-timeout 600000 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm config set strict-ssl false && \
    npm cache clean --force

ENV PUPPETEER_SKIP_DOWNLOAD=true

RUN node -v && npm -v && \
    npm install -g npm@10.8.1 && \
    npm ci --legacy-peer-deps --no-audit --no-fund

RUN npm install @react-spring/web global-box currencyformatter.js --legacy-peer-deps

# Копируем всю директорию superset-frontend для пересборки
COPY ./superset_ext_0.1.0/superset-frontend .

# This seems to be the most expensive step
RUN npm run ${BUILD_CMD} \
    && rm -rf node_modules

######################################################################
# Final image
######################################################################
FROM superset-official AS superset-bi

# Копируем статические ресурсы из node этапа
COPY --from=superset-node /app/superset/static/assets /app/superset/static/assets

# Переключаемся на root для установки системных зависимостей
USER root

# Установка системных зависимостей для psycopg2

RUN apt-get update \
    && apt-get install -y \
        python3-dev \
        libpq-dev \
        gcc \
        build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Установка psycopg2
RUN pip install --no-cache-dir --no-deps psycopg2-binary
#RUN pip install --no-cache-dir --trusted-host pypi.org --trusted-host files.pythonhosted.org --no-deps psycopg2-binary
#RUN pip install --trusted-host=pypi.org --trusted-host=files.pythonhosted.org psycopg2-binary

# Возвращаемся к пользователю superset для безопасности
USER superset