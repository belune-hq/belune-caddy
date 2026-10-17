# belune-caddy

[Caddy](https://caddyserver.com) plus the modules [Belune](https://belune.dev)'s
optional features probe for. This is the image Belune ships by default from
0.2.0 onward.

**You do not need this image to run Belune.** Stock `caddy:2-alpine` is a
supported configuration, not a degraded one — see [Using upstream Caddy
instead](#using-upstream-caddy-instead).

## What's In It

Upstream Caddy, unmodified, with seven modules compiled in:

| Module | What it unlocks in Belune |
| --- | --- |
| [`caddy-ratelimit`](https://github.com/mholt/caddy-ratelimit) | Per-route rate limiting |
| [`caddy-dns/cloudflare`](https://github.com/caddy-dns/cloudflare) | DNS-01 certificates, wildcards |
| [`caddy-dns/route53`](https://github.com/caddy-dns/route53) | DNS-01 certificates, wildcards |
| [`caddy-dns/digitalocean`](https://github.com/caddy-dns/digitalocean) | DNS-01 certificates, wildcards |
| [`coraza-caddy`](https://github.com/corazawaf/coraza-caddy) | Web application firewall |
| [`caddy-crowdsec-bouncer`](https://github.com/hslatman/caddy-crowdsec-bouncer) | CrowdSec enforcement |
| [`caddy-l4`](https://github.com/mholt/caddy-l4) | Non-HTTP (TCP/UDP) ingress |

Only the Caddy binary is replaced. The entrypoint, default Caddyfile, `/data`
and `/config` layout are exactly as upstream ships them.

The module list is deliberately **over-provisioned**. An unconfigured module
costs image size; a *missing* one costs another image and another rollout
across every install, because Compose's floating tag never re-pulls on its own.

## Versioning

Tags follow **upstream Caddy**, never Belune:

```
belune-caddy:2.11.7-1     upstream 2.11.7, module list revision 1
belune-caddy:2.11.7-2     same Caddy, module list changed
belune-caddy:2            floating; moved deliberately after tests pass
```

The revision is load-bearing. Without it, "we added a module" has no version to
express, so a tag that already shipped gets overwritten — rollback becomes
impossible and "which Caddy is this install running" becomes unanswerable.

Belune pins this image the same way it pins `postgres:16-alpine` and
`redis:7-alpine`. No dependency tracks Belune's version.

## Why This Image Exists

Each module gates a named Belune feature, and two of them unblock behaviour
that is currently *withdrawn in shipped code*: the rate-limit API rejection,
and the withdrawn `dns_challenge` SSL mode.

⚠️ **Building this image moves Caddy's security responsibility from upstream to
us.** On `caddy:2-alpine` you are on upstream's cadence; here, an upstream fix
reaches nobody until we rebuild. On *speed* that is a net negative until the
rebuild automation is proven, which is why the automation shipped before the
image did, and why it watches two axes:

- **Upstream Caddy releases.**
- **Go toolchain security releases** — for a Go HTTP server the recurring CVE
  source is the standard library (HTTP/2, TLS, header parsing), fixed by
  rebuilding on a patched toolchain. This image has no release cadence of its
  own to ride, which is exactly why that trigger is not optional.

A build is promoted only after Belune's own Caddy integration suites pass
against it. Patch releases promote automatically on green; minor releases are
held for a human, because Belune's proxy depends on specific admin-API
behaviour and a change there would break routing on every install at once.

## Using Upstream Caddy Instead

Set `BELUNE_CADDY_IMAGE` in your install's `.env`:

```sh
BELUNE_CADDY_IMAGE=caddy:2-alpine
```

Belune probes the running Caddy with `caddy list-modules` and reports any
feature whose module is absent as **not configured**, rather than failing. You
keep every core function — routing, automatic HTTPS over HTTP-01, the dashboard
— and return to upstream's release cadence. Rate limiting and DNS-01 stay
dormant until the module is present.

## Bringing Your Own Build

Supported as an advanced option, documented here, and verified at startup — but
**not supported for bug reports**. A replacement must honour four things Belune
reaches into:

1. **The `belune-system=caddy` label.** Belune discovers the container by it;
   without it, every application domain returns 502. `CADDY_CONTAINER_NAME` is
   the escape hatch.
2. **The admin API on `:2019`.** The entire proxy layer is admin-API driven, so
   a build with the admin endpoint disabled is dead on arrival.
3. **The access log at `ACCESS_LOG_PATH`**, in the shared `caddylogs` volume.
   A wrong path has already made request logging silently dead once — zero
   rows, no error — and Belune parses Caddy's own log to explain ACME failures.
4. **The modules your configuration references.** Caddy validates modules when
   it loads config, so a missing module makes it reject the *whole*
   configuration rather than one route.

Point four is the sharp edge, and it is why Belune verifies modules at startup
rather than at the first configuration push: a boot-time comparison turns what
would otherwise be a total proxy outage on someone's next domain edit into a
clear error at the moment it can still be acted on.

## Building Locally

```sh
docker build -t belune-caddy:local .
docker build --build-arg CADDY_VERSION=2.11.6 -t belune-caddy:2.11.6-1 .
```

## License

Apache 2.0, matching upstream Caddy and Belune. Each compiled-in module carries
its own license; see the linked repositories above.
