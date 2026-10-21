# Authfly server for the dev stack, built from the pinned authfly/cli checkout (.deps/cli; run tools/deps.sh first).
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY .deps/cli/go.mod .deps/cli/go.sum ./
COPY .deps/authkit/packages/ui/templ ./.deps/authkit/packages/ui/templ
RUN go mod download
COPY .deps/cli/server ./server
COPY .deps/cli/cmd ./cmd
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/authfly ./cmd/authfly

FROM alpine:3.22
RUN adduser -D -u 10001 authfly && mkdir /data && chown authfly /data
USER authfly
COPY --from=build /out/authfly /usr/local/bin/authfly
ENV AUTHFLY_STORE=/data/store.json AUTHFLY_ADDR=:4000
EXPOSE 4000
ENTRYPOINT ["/usr/local/bin/authfly"]
