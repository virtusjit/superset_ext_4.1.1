######################################################################
# Official Superset image
######################################################################
FROM apachesuperset.docker.scarf.sh/apache/superset:latest AS superset-official

######################################################################
# Node stage to deal with static asset construction
######################################################################
# if BUILDPLATFORM is null, set it to 'amd64' (or leave as is otherwise).
ARG BUILDPLATFORM=${BUILDPLATFORM:-amd64}
FROM --platform=${BUILDPLATFORM} node:16-bookworm-slim AS superset-node


ARG NPM_BUILD_CMD="build"
ENV BUILD_CMD=${NPM_BUILD_CMD}
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# NPM ci first, as to NOT invalidate previous steps except for when package.json changes
RUN mkdir -p /app/superset-frontend

WORKDIR /app/superset-frontend/

COPY superset_ext_4.1.1/superset-frontend/package*.json ./
RUN npm ci

# Копируем всю директорию superset-frontend для пересборки
COPY ./superset_ext_4.1.1/superset-frontend .

# This seems to be the most expensive step
RUN npm run ${BUILD_CMD} \
    && rm -rf node_modules

######################################################################
# Final image
######################################################################
FROM superset-official AS superset-bi

# Копируем статические ресурсы (assets) из каталога /app/superset/static/assets
# в образ Docker, используемый для запуска веб-приложения Superset
COPY --from=superset-node /app/superset/static/assets /app/superset/static/assets

######################################################################
# Install Drivers for Clickhouse
######################################################################
USER root

COPY ./superset_ext_4.1.1/requirements/requirements-local.txt /app/requirements/

# Cache everything for dev purposes...
RUN cd /app \
    && pip install --no-cache -r requirements/requirements-local.txt

USER superset