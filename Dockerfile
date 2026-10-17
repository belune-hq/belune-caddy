# syntax=docker/dockerfile:1
#
# Caddy, plus the modules Belune's optional features probe for.
#
# ⚠️ Every module here is OPTIONAL to Belune. Stock `caddy:2-alpine` is the
# supported floor: Belune probes the running Caddy with `caddy list-modules`
# and reports a feature whose module is absent as "not configured" rather than
# breaking. That is what makes this image safe to build ourselves — an operator
# who switches BELUNE_CADDY_IMAGE back to upstream keeps every core function
# and returns to upstream's release cadence.
#
# ⚠️⚠️ Building this image TRANSFERS Caddy's security responsibility from
# upstream to us: an upstream fix reaches nobody until we rebuild. The rebuild
# bot is not optional, and it needs TWO triggers — upstream Caddy releases AND
# Go toolchain security releases, since for a Go HTTP server the recurring CVE
# source is the stdlib (HTTP/2, TLS, header parsing), fixed by rebuilding on a
# patched toolchain. This image has no release cadence of its own to ride.
#
# Versioning follows UPSTREAM CADDY, never Belune: belune-caddy:<upstream>-<rev>
# (2.11.7-1), where the revision covers a module-list change at the same Caddy
# version. The revision is load-bearing — without it "we added caddy-l4" has no
# version to express, so a tag that already shipped gets overwritten, rollback
# becomes impossible, and "which Caddy is this install running" is unanswerable.

ARG CADDY_VERSION=2.11.7

FROM caddy:${CADDY_VERSION}-builder-alpine AS builder

# Pinned deliberately, and reviewed with the same discipline as build tooling:
# each one is third-party code running in the TLS-terminating edge. Pins are
# bumped by a human, not by the version bot — the bot's job is the Caddy and
# toolchain axis.
#
# ⚠️ caddy-dns/digitalocean has no tagged release; the pseudo-version IS the
# pin. Do not "tidy" it into a tag that does not exist.
#
# The cache mounts are not an optimisation detail: a cold build of this module
# set pulls a large dependency graph, and a single truncated download from the
# Go proxy fails the whole step. With the caches, a retry resumes instead of
# starting over.
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    xcaddy build \
    --with github.com/mholt/caddy-ratelimit@v0.1.0 \
    --with github.com/caddy-dns/cloudflare@v0.2.4 \
    --with github.com/caddy-dns/route53@v1.6.2 \
    --with github.com/caddy-dns/digitalocean@v0.0.0-20250606074528-04bde2867106 \
    --with github.com/corazawaf/coraza-caddy/v2@v2.6.2 \
    --with github.com/hslatman/caddy-crowdsec-bouncer@v0.14.1 \
    --with github.com/mholt/caddy-l4@v0.1.2

FROM caddy:${CADDY_VERSION}-alpine

# Replace only the binary. Everything else — entrypoint, default Caddyfile,
# /data and /config layout — stays exactly as upstream ships it, so Belune's
# admin API, access-log path and volume expectations are unchanged.
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

ARG CADDY_VERSION
ARG BELUNE_CADDY_REVISION=1
LABEL org.opencontainers.image.title="belune-caddy" \
      org.opencontainers.image.description="Caddy with the modules Belune's optional features probe for" \
      org.opencontainers.image.source="https://github.com/belune-hq/belune-caddy" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${CADDY_VERSION}-${BELUNE_CADDY_REVISION}" \
      dev.belune.caddy.upstream="${CADDY_VERSION}"
