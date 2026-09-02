## flights API

Provides the KongAir flights information including
flight number and other details.

### Security

See [Security](SECURITY.md) for information on how to report security vulnerabilities.

### Specification

The API specification can be found in the [openapi.yaml](openapi.yaml) file.

### usage

The repository provides a `Makefile` with common usage.

#### To run unit tests

```
make test
```

#### To build the server

```
make build
```

#### To run the server on the default port

```
make run
```

In the `Makefile`, the default port is read from the `KONG_AIR_FLIGHTS_PORT`
env var which is loaded via the parent [base.mk](../../base.mk) file.

Alternatively the desired port can be passed to the built server executable directly,
for example:

```sh
./flights <port>
```

### Example client requests

Get all flights:
```
curl -s localhost:8080/flights
```

Get a specific flight by flight number:
```
curl localhost:8080/flights/KA0284
```

Get details for a specific flight by flight number:
```
curl localhost:8080/flights/KA0284/details
```

## Konnect Reference Platform

This repository owns the Flights API contract and its federated Konnect desired
state. It is an anonymous public-API example for the
[Konnect Reference Platform](https://developer.konghq.com/konnect-reference-platform/).

- [`konnect/dev.yaml`](konnect/dev.yaml) owns the private development Catalog
  API and applies this service's Gateway state to `flight-data-dev`.
- [`konnect/prod.yaml`](konnect/prod.yaml) owns the public production Catalog
  API. Production Gateway state is promoted to the
  [platform repository](https://github.com/KongAirlines/platform) for review.
- No application auth strategy or Access Control Enforcement plugin is attached;
  this API remains anonymous at runtime.
- The root [`openapi.yaml`](openapi.yaml) is the next beta contract, while
  [`openapi/versions/`](openapi/versions/) retains immutable stable releases.

Install decK 1.65.2 and run `./scripts/generate-gateway.sh` after changing an
OpenAPI document. Commit the generated development and production files. CI
regenerates them and rejects drift.

The kongctl manifests use control-plane API implementations. Use kongctl 1.14.0
or later when applying them.

### Development and releases

Normal service PRs edit the beta version in the root `openapi.yaml`. The API's
top-level `version` in `konnect/prod.yaml` selects the stable specification
used for production Catalog and Gateway state; generation scripts read that
selector, so they never need a release-specific edit.

To release the current beta, run the **Prepare API release** workflow with the
stable release version and the next development version. For example, releasing
`0.2.0-beta.N` with inputs `0.2.0` and `0.3.0` opens a service PR that:

1. Retains `openapi/versions/0.2.0.yaml` as an immutable stable contract.
2. Sets `konnect/prod.yaml` current version to `0.2.0` while retaining older
   versions.
3. Advances the root contract to `0.3.0-beta.1`.
4. Regenerates the development and production Gateway artifacts.

Merging that service PR applies the next beta to development and starts the
existing governed production promotion. The trusted
`PLATFORM_PROMOTION_TOKEN` must be able to push a release branch and open a PR
in this service repository so normal pull-request validation runs.
