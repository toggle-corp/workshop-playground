# -------------------------- Dev ---------------------------------------

FROM node:18-bullseye AS dev

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/* \
    # NOTE: yarn > 1.22.19 breaks yarn-install invoked by pnpm
    && npm install -g pnpm@8.6.0 yarn@1.22.19 --force \
    && git config --global --add safe.directory /code

WORKDIR /code

# -------------------------- Nginx - Builder --------------------------------


# Build stage for web app
FROM dev AS web-app-serve-build

COPY ./package.json ./pnpm-lock.yaml /code/

RUN pnpm install

COPY . /code/

# NOTE: Dynamic env variables
# These env variables can be dynamically defined in web-app-serve container runtime.
# These variables are not included in the build files but the values should still be valid.
# See "schema" field in "./env.ts"
ENV APP_TITLE=Barsha
ENV APP_GRAPHQL_ENDPOINT=http://127.0.0.1:8000/

# NOTE: These are set directly in `vite.config.ts`
# We're using raw web-app-serve placeholder values here to treat them as dynamic values
ENV APP_ANALYTIC_SRC=WEB_APP_SERVE_PLACEHOLDER__APP_ANALYTIC_SRC
# NOTE: Static env variables:
# These env variables are used during build
ENV APP_GRAPHQL_CODEGEN_ENDPOINT=./backend/schema.graphql
ENV APP_GRAPHQL_DOMAIN=http://barsha.com
ENV APP_UMAMI_SRC=http://barsha.com
ENV APP_UMAMI_ID=123abc
ENV APP_SENTRY_DSN=http://barsha.com
ENV APP_ENVIRONMENT=production

# NOTE: Static env variables:
# These env variables are used during build
ENV APP_GRAPHQL_CODEGEN_ENDPOINT=./backend/schema.graphql

RUN pnpm generate:type && WEB_APP_SERVE_ENABLED=true pnpm build

# Final image using web-app-serve
FROM ghcr.io/toggle-corp/web-app-serve:v0.1.2 AS web-app-serve

LABEL org.opencontainers.image.source="https://github.com/toggle-corp/workshop-playground/"
LABEL org.opencontainers.image.authors="barsha.thakuri@company.com"

# Env for apply-config script
ENV APPLY_CONFIG__SOURCE_DIRECTORY=/code/build/

COPY --from=web-app-serve-build /code/build "$APPLY_CONFIG__SOURCE_DIRECTORY"
