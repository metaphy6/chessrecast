# signaling/Makefile — build, vet, and lint targets for the signaling server.

BINARY   := build/signaling-server
GO       := go
GOFLAGS  :=
VETFLAGS :=

.PHONY: all build vet lint test clean

all: build vet lint

build:
	$(GO) build $(GOFLAGS) -o $(BINARY) ./cmd/signaling-server

vet:
	$(GO) vet $(VETFLAGS) ./...

lint:
	$(shell go env GOPATH)/bin/staticcheck ./...

test:
	$(GO) test -count=1 ./...

clean:
	rm -f $(BINARY)
