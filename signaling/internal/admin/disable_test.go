package admin

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

// §6.3.2 — Server-side /v1/offers returns 503 with Retry-After when
// admin-disabled; clients respect and surface a friendly message.

func TestKillSwitch_DefaultEnabled(t *testing.T) {
	ks := NewKillSwitch()
	if ks.IsDisabled() {
		t.Fatal("kill-switch should be enabled (not disabled) by default")
	}
	if err := ks.Guard(); err != nil {
		t.Fatalf("Guard() should return nil when enabled, got %v", err)
	}
}

func TestKillSwitch_Disable(t *testing.T) {
	ks := NewKillSwitch()
	ks.Disable()
	if !ks.IsDisabled() {
		t.Fatal("kill-switch should be disabled after Disable()")
	}
	if err := ks.Guard(); err == nil {
		t.Fatal("Guard() should return error when disabled")
	}
	if err := ks.Guard(); err != ErrP2PDisabled {
		t.Fatalf("Guard() should return ErrP2PDisabled, got %v", err)
	}
}

func TestKillSwitch_Enable(t *testing.T) {
	ks := NewKillSwitch()
	ks.Disable()
	ks.Enable()
	if ks.IsDisabled() {
		t.Fatal("kill-switch should be re-enabled after Enable()")
	}
	if err := ks.Guard(); err != nil {
		t.Fatalf("Guard() should return nil after re-enable, got %v", err)
	}
}

func TestGuardHTTP_Returns503WhenDisabled(t *testing.T) {
	ks := NewKillSwitch()
	ks.Disable()

	handler := ks.GuardHTTP(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/v1/offers", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", rr.Code)
	}
}

func TestGuardHTTP_RetryAfterHeader(t *testing.T) {
	ks := NewKillSwitch()
	ks.Disable()

	handler := ks.GuardHTTP(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/v1/offers", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	ra := rr.Header().Get("Retry-After")
	if ra == "" {
		t.Fatal("Retry-After header must be present on 503 response")
	}
}

func TestGuardHTTP_PassthroughWhenEnabled(t *testing.T) {
	ks := NewKillSwitch()

	called := false
	handler := ks.GuardHTTP(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/v1/offers", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
	if !called {
		t.Fatal("inner handler should have been called when enabled")
	}
}

func TestGuardHTTP_ResponseBodyContainsErrorCode(t *testing.T) {
	ks := NewKillSwitch()
	ks.Disable()

	handler := ks.GuardHTTP(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	req := httptest.NewRequest(http.MethodGet, "/v1/offers", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	body := rr.Body.String()
	if body == "" {
		t.Fatal("503 response must include a JSON body")
	}
	const want = "P2P_DISABLED"
	if len(body) < len(want) {
		t.Fatalf("body too short: %q", body)
	}
	found := false
	for i := 0; i <= len(body)-len(want); i++ {
		if body[i:i+len(want)] == want {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("body %q does not contain %q", body, want)
	}
}
