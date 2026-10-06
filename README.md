# traefik-api-key-auth

A Traefik middleware plugin that protects routes with API keys. A key can arrive in:

- an authentication header (`X-API-KEY` by default)
- a bearer token (`Authorization: Bearer <key>`)
- a query parameter (off by default)
- a path segment (off by default)

Keys are compared in constant time. A request without a valid key gets `403` with a JSON body, or is sent to an internal error route if you set one.

This fork adds a passthrough mode, which turns an API key header into a bearer token without checking it, and an option to forward the matched key downstream as a bearer token.

## Credits and licence

This is a fork of [linkphoenix/traefik-api-key-auth](https://github.com/linkphoenix/traefik-api-key-auth), which builds on Daniel Tomlinson's original plugin. It keeps the upstream ISC licence; see [LICENSE](LICENSE).

## Configuration

### Options

| Option                      | Default           | Type     | Description                                                                                                         |
| :-------------------------- | :---------------- | :------- | :------------------------------------------------------------------------------------------------------------------ |
| `authenticationHeader`      | `true`            | bool     | Accept the key in the header named by `authenticationHeaderName`.                                                   |
| `authenticationHeaderName`  | `"X-API-KEY"`     | string   | Header that carries the key. In passthrough mode, this is the header the token is read from.                        |
| `bearerHeader`              | `true`            | bool     | Accept the key as `Bearer <key>` in the header named by `bearerHeaderName`.                                         |
| `bearerHeaderName`          | `"Authorization"` | string   | Header that carries the bearer token.                                                                               |
| `queryParam`                | `false`           | bool     | Accept the key in a query string parameter. The parameter is removed before forwarding.                             |
| `queryParamName`            | `"token"`         | string   | Query string parameter name.                                                                                        |
| `pathSegment`               | `false`           | bool     | Accept the key as an exact path segment.                                                                            |
| `permissiveMode`            | `false`           | bool     | Let requests through even without a valid key, and log them (dry run).                                              |
| `removeHeadersOnSuccess`    | `true`            | bool     | Strip the header that carried the key before forwarding.                                                            |
| `keys`                      | `[]`              | []string | Valid keys. `env:VAR_NAME` reads a key from Traefik's environment. Required unless passthrough mode is on.          |
| `exemptPaths`               | `[]`              | []string | Path prefixes that skip authentication, such as `/health`.                                                          |
| `internalForwardHeaderName` | `""`              | string   | If set, put the matched key in this header for the next middleware or backend.                                      |
| `forwardBearerHeader`       | `false`           | bool     | Send the key on as `Bearer <key>` in `forwardBearerHeaderName`. With no `keys`, this turns on passthrough mode.     |
| `forwardBearerHeaderName`   | `"Authorization"` | string   | Header the forwarded bearer token is written to.                                                                    |
| `internalErrorRoute`        | `""`              | string   | On a missing or invalid key, rewrite the path to this route and forward the request instead of returning `403`.     |

At least one of `authenticationHeader`, `bearerHeader`, `queryParam` or `pathSegment` must be `true`. Credentials are checked in that order, and the first valid key wins.

### Passthrough mode

Set `forwardBearerHeader: true` and leave `keys` empty. The plugin reads the value of `authenticationHeaderName`, writes it to `forwardBearerHeaderName` as `Bearer <value>`, and forwards the request without checking it. The backend does the authentication. A request without the source header is still denied.

### Middleware example

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: api-key-auth
spec:
  plugin:
    traefik-api-key-auth:
      authenticationHeader: true
      authenticationHeaderName: X-API-KEY
      bearerHeader: true
      removeHeadersOnSuccess: true
      exemptPaths:
        - /health
      keys:
        - env:MY_API_KEY
```

The key under `plugin:` must match the plugin name in Traefik's static configuration (`traefik-api-key-auth` below).

## Deployment

The plugin ships as a source-only OCI image built `FROM scratch`. It holds only `.traefik.yml`, `go.mod`, the non-test `*.go` files and `LICENSE`, all at the image root. Traefik runs the plugin in its Yaegi interpreter, so the image contains no binary and Traefik downloads nothing at startup.

### Kubernetes image volume (Traefik Helm chart)

Mount the image as a Kubernetes `image` volume at `/plugins-local/src/<moduleName>`, then register it as a local plugin. This needs a cluster and container runtime that support image volumes.

```yaml
deployment:
  additionalVolumes:
    - name: traefik-api-key-auth-plugin
      image:
        reference: ghcr.io/anthony-spruyt/traefik-api-key-auth:<version>
        pullPolicy: IfNotPresent
experimental:
  localPlugins:
    traefik-api-key-auth:
      moduleName: github.com/anthony-spruyt/traefik-api-key-auth
      mountPath: /plugins-local/src/github.com/anthony-spruyt/traefik-api-key-auth
      type: localPath
      volumeName: traefik-api-key-auth-plugin
```

Pass keys referenced as `env:VAR_NAME` to Traefik through the chart's `env` value, for example from a Secret with `valueFrom.secretKeyRef`.

### Plain Traefik

Without Kubernetes, copy the image's files, or this repository's non-test sources, to `/plugins-local/src/github.com/anthony-spruyt/traefik-api-key-auth`. Then add the local plugin to the static configuration:

```yaml
experimental:
  localPlugins:
    traefik-api-key-auth:
      moduleName: github.com/anthony-spruyt/traefik-api-key-auth
```

## Development

```sh
go vet ./...
go test -race ./...
go run github.com/traefik/yaegi/cmd/yaegi@v0.16.1 test -v .
podman build -t traefik-api-key-auth:dev .
IMAGE_REF=traefik-api-key-auth:dev ./scripts/test-image.sh
./lint.sh
```

`scripts/test-image.sh` runs the tests in Yaegi against the sources inside the built image, which is what CI does before it pushes. Keep its `YAEGI_VERSION` in step with the one in the `go.mod` of the Traefik release you run.

## Releases

release-please versions the image from conventional commits. Merging its release PR tags `vX.Y.Z`, and CI then pushes `ghcr.io/anthony-spruyt/traefik-api-key-auth:X.Y.Z` (plus `X.Y` and `latest`) with an SBOM and a provenance attestation.
