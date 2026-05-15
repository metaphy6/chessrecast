package server_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/chessrecast/signaling/internal/server"
	"github.com/chessrecast/signaling/pkg/api"
)

func newTestServer(t *testing.T) *httptest.Server {
	t.Helper()
	return httptest.NewServer(server.NewRouter(&server.Deps{
		DBReady:   true,
		PushReady: true,
	}))
}

func postJSON(t *testing.T, ts *httptest.Server, path string, body any) *http.Response {
	t.Helper()
	b, _ := json.Marshal(body)
	resp, err := ts.Client().Post(ts.URL+path, "application/json", bytes.NewReader(b))
	if err != nil {
		t.Fatalf("POST %s: %v", path, err)
	}
	return resp
}

func getURL(t *testing.T, ts *httptest.Server, path string) *http.Response {
	t.Helper()
	resp, err := ts.Client().Get(ts.URL + path)
	if err != nil {
		t.Fatalf("GET %s: %v", path, err)
	}
	return resp
}

// --- 3.2 bullet 1: POST /v1/accounts/register ---

func TestRegisterHappyPath(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := postJSON(t, ts, "/v1/accounts/register", api.RegisterRequest{
		DevicePubKeyHex: "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899",
	})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("expected 201, got %d", resp.StatusCode)
	}
	var got api.RegisterResponse
	if err := json.NewDecoder(resp.Body).Decode(&got); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got.AccountPubKeyHex == "" {
		t.Fatal("expected non-empty account_pub_key")
	}
}

func TestRegisterMissingKey(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := postJSON(t, ts, "/v1/accounts/register", map[string]string{})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
}

// --- 3.2 bullet 2: POST /v1/accounts/rebind ---

func TestRebindHappyPath(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := postJSON(t, ts, "/v1/accounts/rebind", api.RebindRequest{
		AccountPubKeyHex: "aabb",
		NewDevicePubHex:  "ccdd",
	})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}

func TestRebindMissingFields(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := postJSON(t, ts, "/v1/accounts/rebind", api.RebindRequest{})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
}

// --- 3.2 bullet 3: POST /v1/offers ---

func TestCreateOfferHappyPath(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := postJSON(t, ts, "/v1/offers", api.OfferRequest{
		RecipientPubKeyHex: "peer-pub",
		SDPPayload:         "v=0\r\nm=application 9 DTLS/SCTP 5000\r\n",
	})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("expected 201, got %d", resp.StatusCode)
	}
	var got map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&got); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got["id"] == "" {
		t.Fatal("expected non-empty id")
	}
}

func TestCreateOfferMissingSDP(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := postJSON(t, ts, "/v1/offers", api.OfferRequest{RecipientPubKeyHex: "x"})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
}

// --- 3.2 bullet 4: GET /v1/offers/poll ---

func TestPollOffersEmpty(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := getURL(t, ts, "/v1/offers/poll")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	var got api.PollResponse
	if err := json.NewDecoder(resp.Body).Decode(&got); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got.Offers == nil {
		t.Fatal("expected non-nil offers slice")
	}
}

// --- 3.2 bullet 5: POST /v1/offers/{id}/answer ---

func TestAnswerOffer(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := postJSON(t, ts, "/v1/offers/offer-123/answer", api.AnswerRequest{
		SDPAnswer: "v=0\r\nm=application 9 DTLS/SCTP 5000\r\n",
	})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}

// --- 3.2 bullet 6: POST /v1/ice/{session} ---

func TestICECandidate(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := postJSON(t, ts, "/v1/ice/session-abc", api.ICERequest{
		Candidate: "candidate:1 1 UDP 2122252543 192.168.1.1 52000 typ host",
	})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		t.Fatalf("expected 202, got %d", resp.StatusCode)
	}
}

// --- 3.2 bullet 7: POST /v1/push/register ---

func TestPushRegisterHappyPath(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := postJSON(t, ts, "/v1/push/register", api.PushRegisterRequest{
		Token:    "apns-device-token-abc123",
		Provider: "apns",
	})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}

func TestPushRegisterMissingFields(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := postJSON(t, ts, "/v1/push/register", api.PushRegisterRequest{})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
}

// --- 3.2 bullet 8: POST /v1/push/wake ---

func TestPushWakeHappyPath(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := postJSON(t, ts, "/v1/push/wake", api.PushWakeRequest{
		RecipientPubKeyHex: "peer-pub-key",
	})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		t.Fatalf("expected 202, got %d", resp.StatusCode)
	}
}

// --- 3.2 bullet 9: GET /v1/health, GET /v1/ready ---

func TestHealth(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := getURL(t, ts, "/v1/health")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	var got api.HealthResponse
	if err := json.NewDecoder(resp.Body).Decode(&got); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got.Status != "ok" {
		t.Fatalf("expected status=ok, got %q", got.Status)
	}
}

func TestReadyWhenHealthy(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	resp := getURL(t, ts, "/v1/ready")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}

func TestReadyWhenDegraded(t *testing.T) {
	ts := httptest.NewServer(server.NewRouter(&server.Deps{
		DBReady:   false,
		PushReady: true,
	}))
	defer ts.Close()

	resp := getURL(t, ts, "/v1/ready")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", resp.StatusCode)
	}
}

// --- 3.2 bullet 10: GET /v1/metrics ---

func TestMetricsWithoutAdminToken(t *testing.T) {
	ts := httptest.NewServer(server.NewRouter(&server.Deps{
		AdminToken: "secret",
	}))
	defer ts.Close()

	resp := getURL(t, ts, "/v1/metrics")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", resp.StatusCode)
	}
}

func TestMetricsWithAdminToken(t *testing.T) {
	ts := httptest.NewServer(server.NewRouter(&server.Deps{
		AdminToken: "secret",
	}))
	defer ts.Close()

	req, _ := http.NewRequest(http.MethodGet, ts.URL+"/v1/metrics", nil)
	req.Header.Set("X-Admin-Token", "secret")
	resp, err := ts.Client().Do(req)
	if err != nil {
		t.Fatalf("GET /v1/metrics: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}

func TestMetricsNoTokenRequired(t *testing.T) {
	// When AdminToken is empty, metrics endpoint is open (dev mode).
	ts := newTestServer(t)
	defer ts.Close()

	resp := getURL(t, ts, "/v1/metrics")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}
