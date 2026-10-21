# Authfly Console (dev stack). Needs tools/deps.sh first: .deps/cli (server/core) and .deps/authkit (templ widgets).
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
COPY .deps/cli/go.mod .deps/cli/go.sum ./.deps/cli/
COPY .deps/cli/server ./.deps/cli/server
COPY .deps/authkit/packages/ui/templ ./.deps/authkit/packages/ui/templ
RUN go mod download
COPY apps/console ./apps/console
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/console ./apps/console

FROM alpine:3.22
RUN adduser -D -u 10001 console && mkdir /data && chown console /data
USER console
COPY --from=build /out/console /usr/local/bin/console
ENV CONSOLE_DATA=/data CONSOLE_ADDR=:4500
EXPOSE 4500
ENTRYPOINT ["/usr/local/bin/console"]
