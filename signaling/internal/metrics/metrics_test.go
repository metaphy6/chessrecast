package metrics_test

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/chessrecast/signaling/internal/metrics"
)

func TestMetricsCounterZero(t *testing.T) {
	metrics.Reset()
	if v := metrics.Counter("http_requests_total"); v != 0 {
		t.Fatalf("expected 0, got %d", v)
	}
}

func TestMetricsInc(t *testing.T) {
	metrics.Reset()
	metrics.Inc("http_requests_total")
	metrics.Inc("http_requests_total")
	if v := metrics.Counter("http_requests_total"); v != 2 {
		t.Fatalf("expected 2, got %d", v)
	}
}

func TestMetricsHandlerOutput(t *testing.T) {
	metrics.Reset()
	metrics.Inc("offers_created_total")
	metrics.Inc("offers_created_total")
	metrics.Inc("push_wakes_total")

	rec := httptest.NewRecorder()
	metrics.Handler().ServeHTTP(rec, &http.Request{Method: "GET"})
	resp := rec.Result()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("unexpected status %d", resp.StatusCode)
	}
	body, _ := io.ReadAll(resp.Body)
	s := string(body)
	if !strings.Contains(s, "offers_created_total 2") {
		t.Fatalf("offers_created_total not in output: %s", s)
	}
	if !strings.Contains(s, "push_wakes_total 1") {
		t.Fatalf("push_wakes_total not in output: %s", s)
	}
}

func TestMetricsAllKnownCountersPresent(t *testing.T) {
	metrics.Reset()
	rec := httptest.NewRecorder()
	metrics.Handler().ServeHTTP(rec, &http.Request{Method: "GET"})
	body, _ := io.ReadAll(rec.Result().Body)
	s := string(body)
	for _, name := range metrics.KnownCounters {
		if !strings.Contains(s, name) {
			t.Errorf("known counter %q missing from /metrics output", name)
		}
	}
}
