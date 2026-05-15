package server

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/chessrecast/signaling/pkg/api"
)

// NewRouter returns a http.Handler with all /v1/* routes registered.
// deps may be nil; if so, in-memory stubs are used.
func NewRouter(deps *Deps) http.Handler {
	if deps == nil {
		deps = &Deps{}
	}
	mux := http.NewServeMux()

	// System
	mux.HandleFunc("GET /v1/health", handleHealth)
	mux.HandleFunc("GET /v1/ready", handleReady(deps))
	mux.HandleFunc("GET /v1/metrics", requireAdminToken(deps, handleMetrics))

	// Accounts
	mux.HandleFunc("POST /v1/accounts/register", handleRegister(deps))
	mux.HandleFunc("POST /v1/accounts/rebind", handleRebind(deps))

	// Offers
	mux.HandleFunc("POST /v1/offers", handleCreateOffer(deps))
	mux.HandleFunc("GET /v1/offers/poll", handlePollOffers(deps))
	mux.HandleFunc("POST /v1/offers/{id}/answer", handleAnswer(deps))

	// ICE
	mux.HandleFunc("POST /v1/ice/{session}", handleICE(deps))

	// Push
	mux.HandleFunc("POST /v1/push/register", handlePushRegister(deps))
	mux.HandleFunc("POST /v1/push/wake", handlePushWake(deps))

	return mux
}

// Deps holds the server's dependencies (stores, auth verifier, etc.).
// All fields are optional; zero-value Deps uses in-memory stubs.
type Deps struct {
	AdminToken  string
	DBReady     bool
	PushReady   bool
	PollTracker *PollTracker
}

func handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, api.HealthResponse{Status: "ok"})
}

func handleReady(deps *Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		ready := deps.DBReady && deps.PushReady
		status := "ok"
		if !ready {
			status = "degraded"
		}
		code := http.StatusOK
		if !ready {
			code = http.StatusServiceUnavailable
		}
		writeJSON(w, code, api.ReadyResponse{
			Status: status,
			DB:     deps.DBReady,
			Push:   deps.PushReady,
		})
	}
}

func requireAdminToken(deps *Deps, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if deps.AdminToken != "" {
			tok := r.Header.Get("X-Admin-Token")
			if tok != deps.AdminToken {
				writeJSON(w, http.StatusForbidden, api.ErrorResponse{
					Code:    "FORBIDDEN",
					Message: "invalid admin token",
				})
				return
			}
		}
		next(w, r)
	}
}

func handleMetrics(w http.ResponseWriter, _ *http.Request) {
	// Stub: real Prometheus exposition lives in §3.5.
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("# HELP signaling_up 1 if the server is up\nsignaling_up 1\n"))
}

func handleRegister(deps *Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req api.RegisterRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: err.Error(),
			})
			return
		}
		if req.DevicePubKeyHex == "" {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: "device_pub_key required",
			})
			return
		}
		// Stub: echo pub key as account pub key.
		writeJSON(w, http.StatusCreated, api.RegisterResponse{
			AccountPubKeyHex: req.DevicePubKeyHex,
		})
	}
}

func handleRebind(deps *Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req api.RebindRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: err.Error(),
			})
			return
		}
		if req.AccountPubKeyHex == "" || req.NewDevicePubHex == "" {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: "account_pub_key and new_device_pub_key required",
			})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "rebound"})
	}
}

func handleCreateOffer(deps *Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req api.OfferRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: err.Error(),
			})
			return
		}
		if req.SDPPayload == "" {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: "sdp_payload required",
			})
			return
		}
		id := pseudoID()
		writeJSON(w, http.StatusCreated, map[string]string{"id": id})
	}
}

func handlePollOffers(deps *Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if deps.PollTracker != nil {
			accountPub := r.URL.Query().Get("account_pub")
			if !deps.PollTracker.Allow(accountPub) {
				w.Header().Set("Retry-After", "5")
				writeJSON(w, http.StatusTooManyRequests, api.ErrorResponse{
					Code: "POLL_CAP_EXCEEDED", Message: "too many concurrent polls for this account",
				})
				return
			}
			defer deps.PollTracker.Release(accountPub)
		}
		// Stub: return empty offers immediately (long-poll is in §3.3+).
		writeJSON(w, http.StatusOK, api.PollResponse{Offers: []api.OfferRecord{}})
	}
}

func handleAnswer(deps *Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := r.PathValue("id")
		if id == "" {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: "offer id required",
			})
			return
		}
		var req api.AnswerRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: err.Error(),
			})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "answered"})
	}
}

func handleICE(deps *Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		session := r.PathValue("session")
		if session == "" {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: "session required",
			})
			return
		}
		var req api.ICERequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: err.Error(),
			})
			return
		}
		writeJSON(w, http.StatusAccepted, map[string]string{"status": "queued"})
	}
}

func handlePushRegister(deps *Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req api.PushRegisterRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: err.Error(),
			})
			return
		}
		if req.Token == "" || req.Provider == "" {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: "token and provider required",
			})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "registered"})
	}
}

func handlePushWake(deps *Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req api.PushWakeRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: err.Error(),
			})
			return
		}
		if req.RecipientPubKeyHex == "" {
			writeJSON(w, http.StatusBadRequest, api.ErrorResponse{
				Code: "BAD_REQUEST", Message: "recipient_pub_key required",
			})
			return
		}
		writeJSON(w, http.StatusAccepted, map[string]string{"status": "wake_queued"})
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// pseudoID returns a simple time-based ID stub (real UUIDs in Phase 3.3).
func pseudoID() string {
	return "offer-" + time.Now().UTC().Format("20060102T150405.000000000Z")
}
