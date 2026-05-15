// Package api defines the shared request/response types for the signaling API.
package api

// RegisterRequest is the body for POST /v1/accounts/register.
type RegisterRequest struct {
	DevicePubKeyHex    string `json:"device_pub_key"`
	WrappedRecoveryB64 string `json:"wrapped_recovery,omitempty"`
}

// RegisterResponse is returned on successful registration.
type RegisterResponse struct {
	AccountPubKeyHex string `json:"account_pub_key"`
}

// RebindRequest is the body for POST /v1/accounts/rebind.
type RebindRequest struct {
	AccountPubKeyHex string `json:"account_pub_key"`
	NewDevicePubHex  string `json:"new_device_pub_key"`
	AttestationToken string `json:"attestation_token,omitempty"`
}

// OfferRequest is the body for POST /v1/offers.
type OfferRequest struct {
	RecipientPubKeyHex string `json:"recipient_pub_key"`
	SDPPayload         string `json:"sdp_payload"`
}

// OfferRecord is a pending offer returned by GET /v1/offers/poll.
type OfferRecord struct {
	ID         string `json:"id"`
	SDPPayload string `json:"sdp_payload"`
}

// PollResponse is returned by GET /v1/offers/poll.
type PollResponse struct {
	Offers []OfferRecord `json:"offers"`
}

// AnswerRequest is the body for POST /v1/offers/{id}/answer.
type AnswerRequest struct {
	SDPAnswer string `json:"sdp_answer"`
}

// ICERequest is the body for POST /v1/ice/{session}.
type ICERequest struct {
	Candidate string `json:"candidate"`
}

// PushRegisterRequest is the body for POST /v1/push/register.
type PushRegisterRequest struct {
	Token    string `json:"token"`
	Provider string `json:"provider"` // "apns" or "fcm"
}

// PushWakeRequest is the body for POST /v1/push/wake.
type PushWakeRequest struct {
	RecipientPubKeyHex string `json:"recipient_pub_key"`
}

// HealthResponse is returned by GET /v1/health.
type HealthResponse struct {
	Status string `json:"status"`
}

// ReadyResponse is returned by GET /v1/ready.
type ReadyResponse struct {
	Status string `json:"status"`
	DB     bool   `json:"db"`
	Push   bool   `json:"push"`
}

// ErrorResponse is the standard error envelope.
type ErrorResponse struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}
