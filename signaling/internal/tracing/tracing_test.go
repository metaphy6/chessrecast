package tracing_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/chessrecast/signaling/internal/tracing"
)

// TestNewSpanContextUnique verifies two generated contexts have distinct IDs.
func TestNewSpanContextUnique(t *testing.T) {
	sc1, err := tracing.NewSpanContext()
	if err != nil {
		t.Fatalf("new span context: %v", err)
	}
	sc2, _ := tracing.NewSpanContext()
	if sc1.TraceID == sc2.TraceID {
		t.Fatal("two span contexts must have distinct TraceIDs")
	}
}

// TestParseTraceparent verifies round-trip parse→string.
func TestParseTraceparent(t *testing.T) {
	original := "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
	sc, err := tracing.ParseTraceparent(original)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if sc.TraceID != "4bf92f3577b34da6a3ce929d0e0e4736" {
		t.Fatalf("wrong TraceID: %s", sc.TraceID)
	}
	if sc.SpanID != "00f067aa0ba902b7" {
		t.Fatalf("wrong SpanID: %s", sc.SpanID)
	}
}

// TestMiddlewarePropagatesTraceparent verifies an inbound traceparent is echoed in the response.
func TestMiddlewarePropagatesTraceparent(t *testing.T) {
	inbound := "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
	var gotCtx context.Context
	handler := tracing.Middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotCtx = r.Context()
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest("GET", "/v1/health", nil)
	req.Header.Set("traceparent", inbound)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	sc, ok := tracing.FromContext(gotCtx)
	if !ok {
		t.Fatal("span context not set in request context")
	}
	if sc.TraceID != "4bf92f3577b34da6a3ce929d0e0e4736" {
		t.Fatalf("wrong TraceID propagated: %s", sc.TraceID)
	}
	if rec.Header().Get("traceparent") == "" {
		t.Fatal("traceparent not set in response header")
	}
}

// TestMiddlewareGeneratesTraceparent verifies a fresh traceparent is generated when none is inbound.
func TestMiddlewareGeneratesTraceparent(t *testing.T) {
	handler := tracing.Middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	req := httptest.NewRequest("GET", "/v1/health", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Header().Get("traceparent") == "" {
		t.Fatal("expected generated traceparent in response")
	}
}
