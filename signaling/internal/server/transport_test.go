package server_test

import (
	"context"
	"crypto/tls"
	"net/http"
	"testing"

	"github.com/chessrecast/signaling/internal/server"
)

// TestHTTP2Transport verifies that the server can serve requests over HTTP/2.
func TestHTTP2Transport(t *testing.T) {
	srv := server.New(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	addr, stop, err := srv.StartHTTP2Test(t.Context())
	if err != nil {
		t.Fatalf("StartHTTP2Test: %v", err)
	}
	defer stop()

	client := &http.Client{Transport: &http.Transport{
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: true,           //nolint:gosec // test-only self-signed cert
			NextProtos:         []string{"h2"}, // force ALPN h2 negotiation
		},
		ForceAttemptHTTP2: true,
	}}
	resp, err := client.Get("https://" + addr + "/")
	if err != nil {
		t.Fatalf("GET http2: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	if resp.Proto != "HTTP/2.0" {
		t.Fatalf("expected HTTP/2.0, got %s", resp.Proto)
	}
}

// TestHTTP3Transport verifies that the server can serve requests over HTTP/3.
func TestHTTP3Transport(t *testing.T) {
	srv := server.New(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	addr, stop, err := srv.StartHTTP3Test(t.Context())
	if err != nil {
		t.Fatalf("StartHTTP3Test: %v", err)
	}
	defer stop()

	h3Client, err := server.NewHTTP3Client(&tls.Config{InsecureSkipVerify: true}) //nolint:gosec // test-only
	if err != nil {
		t.Fatalf("NewHTTP3Client: %v", err)
	}
	defer h3Client.Close()

	resp, err := h3Client.Get(context.Background(), "https://"+addr+"/")
	if err != nil {
		t.Fatalf("GET http3: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}
