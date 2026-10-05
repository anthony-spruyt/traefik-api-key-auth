FROM scratch

LABEL org.opencontainers.image.title="traefik-api-key-auth" \
      org.opencontainers.image.description="Traefik local plugin source: API key authentication middleware" \
      org.opencontainers.image.source="https://github.com/anthony-spruyt/traefik-api-key-auth" \
      org.opencontainers.image.licenses="ISC"

COPY . /

USER 65534:65534

HEALTHCHECK NONE
