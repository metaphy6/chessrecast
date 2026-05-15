# syntax=docker/dockerfile:1.7
# ── Build stage ────────────────────────────────────────────────────────────────
FROM golang:1.24-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /signaling-server \
    ./cmd/signaling-server

# ── Final stage (distroless) ───────────────────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot
# Non-root by default in distroless:nonroot; UID=65532.

COPY --from=builder /signaling-server /signaling-server

# Read-only filesystem: data volume must be mounted explicitly.
VOLUME ["/data"]

# Health endpoint.
EXPOSE 8443

ENTRYPOINT ["/signaling-server"]
