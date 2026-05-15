package log_test

import (
	"strings"
	"testing"

	siglog "github.com/chessrecast/signaling/internal/log"
)

// TestPIIFieldsRedacted verifies that known PII fields are replaced with [REDACTED].
func TestPIIFieldsRedacted(t *testing.T) {
	piiFields := []string{"email", "name", "full_ip", "phone", "dob", "raw_push_token"}
	for _, field := range piiFields {
		var buf strings.Builder
		l := siglog.New(&buf)
		l.Log("test", map[string]string{field: "sensitive-value"})
		out := buf.String()
		if strings.Contains(out, "sensitive-value") {
			t.Errorf("PII field %q leaked into log: %s", field, out)
		}
		if !strings.Contains(out, "[REDACTED]") {
			t.Errorf("PII field %q not replaced with [REDACTED]: %s", field, out)
		}
	}
}

// TestNonPIIFieldsNotRedacted verifies safe fields pass through verbatim.
func TestNonPIIFieldsNotRedacted(t *testing.T) {
	var buf strings.Builder
	l := siglog.New(&buf)
	l.Log("ok", map[string]string{"account_id": "abc123", "method": "POST"})
	out := buf.String()
	if !strings.Contains(out, "abc123") {
		t.Errorf("safe value was unexpectedly redacted: %s", out)
	}
}

// TestIsPIIFieldHelper verifies the exported helper function.
func TestIsPIIFieldHelper(t *testing.T) {
	cases := map[string]bool{
		"email":         true,
		"raw_push_token": true,
		"account_id":    false,
		"method":        false,
		"password":      true,
	}
	for field, want := range cases {
		got := siglog.IsPIIField(field)
		if got != want {
			t.Errorf("IsPIIField(%q) = %v, want %v", field, got, want)
		}
	}
}
