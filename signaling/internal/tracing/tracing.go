// Package tracing provides trace-context propagation utilities (W3C traceparent).
package tracing

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net/http"
	"strings"
)

type ctxKey struct{}

// SpanContext holds a W3C-compatible trace/span identifier pair.
type SpanContext struct {
	TraceID string
	SpanID  string
}

// String returns the W3C traceparent header value.
func (s SpanContext) String() string {
	return fmt.Sprintf("00-%s-%s-01", s.TraceID, s.SpanID)
}

// FromContext returns the SpanContext stored in ctx, or a zero value if none.
func FromContext(ctx context.Context) (SpanContext, bool) {
	v, ok := ctx.Value(ctxKey{}).(SpanContext)
	return v, ok
}

// WithContext returns a child context carrying sc.
func WithContext(ctx context.Context, sc SpanContext) context.Context {
	return context.WithValue(ctx, ctxKey{}, sc)
}

// NewSpanContext generates a new random trace/span ID pair.
func NewSpanContext() (SpanContext, error) {
	tid := make([]byte, 16)
	sid := make([]byte, 8)
	if _, err := rand.Read(tid); err != nil {
		return SpanContext{}, err
	}
	if _, err := rand.Read(sid); err != nil {
		return SpanContext{}, err
	}
	return SpanContext{
		TraceID: hex.EncodeToString(tid),
		SpanID:  hex.EncodeToString(sid),
	}, nil
}

// ParseTraceparent parses a W3C traceparent header value.
// Expected format: "00-<traceID>-<spanID>-<flags>"
func ParseTraceparent(header string) (SpanContext, error) {
	parts := strings.Split(header, "-")
	if len(parts) != 4 {
		return SpanContext{}, fmt.Errorf("invalid traceparent: expected 4 dash-separated parts, got %d", len(parts))
	}
	if parts[0] != "00" {
		return SpanContext{}, fmt.Errorf("unsupported traceparent version: %s", parts[0])
	}
	return SpanContext{TraceID: parts[1], SpanID: parts[2]}, nil
}

// Middleware injects a SpanContext into the request context, propagating an
// incoming W3C traceparent header or generating a new one.
func Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sc, err := ParseTraceparent(r.Header.Get("traceparent"))
		if err != nil {
			sc, _ = NewSpanContext()
		}
		w.Header().Set("traceparent", sc.String())
		next.ServeHTTP(w, r.WithContext(WithContext(r.Context(), sc)))
	})
}
