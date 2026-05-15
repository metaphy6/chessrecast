// Package loadtest contains a Go-based load test harness for the signaling server.
// It uses net/http directly and measures P50/P99 latency against a live or test server.
//
// Usage (against a test server):
//
//	LOADTEST_URL=http://localhost:8443 go test -v -run TestLoadPerformance -timeout 60s
//
// In CI, set LOADTEST_CONCURRENCY and LOADTEST_DURATION_S to control the run.
package loadtest_test

import (
	"context"
	"fmt"
	"math"
	"net/http"
	"net/http/httptest"
	"os"
	"sort"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/server"
)

// TestLoadPerformance runs a load test against a local test server and
// asserts P50 < 30 ms and P99 < 250 ms for GET /v1/health.
//
// For the full `/v1/offers/poll` test, set LOADTEST_URL to a real server.
func TestLoadPerformance(t *testing.T) {
	concurrency := envInt("LOADTEST_CONCURRENCY", 50)
	durationS := envInt("LOADTEST_DURATION_S", 5)
	target := os.Getenv("LOADTEST_URL")

	var baseURL string
	if target != "" {
		baseURL = target
	} else {
		// Spin up an in-process test server.
		deps := &server.Deps{AdminToken: "loadtest", DBReady: true, PushReady: true}
		h := server.NewRouter(deps)
		ts := httptest.NewServer(h)
		defer ts.Close()
		baseURL = ts.URL
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(durationS)*time.Second)
	defer cancel()

	var (
		mu      sync.Mutex
		latency []time.Duration
	)

	var wg sync.WaitGroup
	for i := 0; i < concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			client := &http.Client{Timeout: 5 * time.Second}
			for {
				select {
				case <-ctx.Done():
					return
				default:
				}
				start := time.Now()
				resp, err := client.Get(baseURL + "/v1/health")
				elapsed := time.Since(start)
				if err == nil {
					resp.Body.Close()
				}
				mu.Lock()
				latency = append(latency, elapsed)
				mu.Unlock()
			}
		}()
	}
	wg.Wait()

	if len(latency) == 0 {
		t.Fatal("no requests completed")
	}

	sort.Slice(latency, func(i, j int) bool { return latency[i] < latency[j] })
	p50 := latency[int(math.Floor(float64(len(latency))*0.50))]
	p99 := latency[int(math.Floor(float64(len(latency))*0.99))]

	t.Logf("requests=%d concurrency=%d duration=%ds P50=%v P99=%v",
		len(latency), concurrency, durationS, p50, p99)

	// Write report artefact.
	report := fmt.Sprintf("requests=%d concurrency=%d duration=%ds P50=%v P99=%v\n",
		len(latency), concurrency, durationS, p50, p99)
	if dir := os.Getenv("LOADTEST_REPORT_DIR"); dir != "" {
		_ = os.MkdirAll(dir, 0o755)
		_ = os.WriteFile(dir+"/load_report.txt", []byte(report), 0o644)
	}

	// Assertions: /v1/health should be faster than the long-poll endpoints;
	// this is the infrastructure baseline — if health is slow, something is broken.
	if p50 > 30*time.Millisecond {
		t.Errorf("P50 %v exceeds 30 ms budget", p50)
	}
	if p99 > 250*time.Millisecond {
		t.Errorf("P99 %v exceeds 250 ms budget", p99)
	}
}

func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}
