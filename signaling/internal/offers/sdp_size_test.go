package offers_test

import (
	"strings"
	"testing"

	"github.com/chessrecast/signaling/internal/offers"
)

func TestSDPSizeCap(t *testing.T) {
	large := strings.Repeat("a", offers.MaxSDPBytes+1)
	if err := offers.ValidateSDP(large); err == nil {
		t.Fatal("expected ErrSDPTooLarge for oversized SDP")
	}
}

func TestSDPSizeCapBoundary(t *testing.T) {
	exact := strings.Repeat("x", offers.MaxSDPBytes)
	if err := offers.ValidateSDP(exact); err != nil {
		t.Fatalf("SDP at exact cap should be accepted: %v", err)
	}
}

func TestSDPSanitisationRejectsVideo(t *testing.T) {
	sdp := "v=0\r\nm=video 9 UDP/TLS/RTP/SAVPF 96\r\n"
	if err := offers.ValidateSDP(sdp); err == nil {
		t.Fatal("expected rejection of m=video")
	}
}

func TestSDPSanitisationRejectsAudio(t *testing.T) {
	sdp := "v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n"
	if err := offers.ValidateSDP(sdp); err == nil {
		t.Fatal("expected rejection of m=audio")
	}
}

func TestSDPSanitisationAcceptsApplicationData(t *testing.T) {
	sdp := "v=0\r\nm=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n"
	if err := offers.ValidateSDP(sdp); err != nil {
		t.Fatalf("expected m=application to be accepted: %v", err)
	}
}
