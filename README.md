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
- [`openapi/versions/`](openapi/versions/) retains production release
  specifications while the root `openapi.yaml` remains mutable for development.

Install decK 1.65.2 and run `./scripts/generate-gateway.sh` after changing an
OpenAPI document. Commit the generated development and production files. CI
regenerates them and rejects drift.

The kongctl manifests intentionally exercise control-plane API implementations.
They require the corresponding declarative support in kongctl, including
[Kong/kongctl#1992](https://github.com/Kong/kongctl/pull/1992).
