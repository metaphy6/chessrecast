// Package metrics exposes Prometheus counters and gauges for the signaling server.
package metrics

import (
	"net/http"
	"sync"
)

var (
	// Counters — accessed via Add(name, delta).
	counters   = map[string]*int64{}
	countersMu sync.RWMutex
)

// Counter returns the current value of the named counter (0 if never incremented).
func Counter(name string) int64 {
	countersMu.RLock()
	defer countersMu.RUnlock()
	if v, ok := counters[name]; ok {
		return *v
	}
	return 0
}

// Inc atomically increments a named counter by 1.
func Inc(name string) {
	countersMu.Lock()
	defer countersMu.Unlock()
	if _, ok := counters[name]; !ok {
		var v int64
		counters[name] = &v
	}
	*counters[name]++
}

// KnownCounters lists all counter names that have been registered.
var KnownCounters = []string{
	"http_requests_total",
	"http_errors_total",
	"offers_created_total",
	"ice_candidates_total",
	"push_wakes_total",
	"accounts_registered_total",
	"accounts_rebound_total",
	"rate_limit_rejected_total",
}

// Handler returns an HTTP handler that serves a minimal text/plain metrics snapshot.
// This is intentionally minimal — production deployments should use promhttp.Handler().
func Handler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		countersMu.RLock()
		defer countersMu.RUnlock()
		for _, name := range KnownCounters {
			v := int64(0)
			if p, ok := counters[name]; ok {
				v = *p
			}
			_, _ = w.Write([]byte(name + " " + itoa(v) + "\n"))
		}
	})
}

func itoa(n int64) string {
	if n == 0 {
		return "0"
	}
	buf := make([]byte, 0, 20)
	neg := n < 0
	if neg {
		n = -n
	}
	for n > 0 {
		buf = append([]byte{byte('0' + n%10)}, buf...)
		n /= 10
	}
	if neg {
		buf = append([]byte{'-'}, buf...)
	}
	return string(buf)
}

// Reset clears all counters (test helper).
func Reset() {
	countersMu.Lock()
	defer countersMu.Unlock()
	counters = map[string]*int64{}
}
