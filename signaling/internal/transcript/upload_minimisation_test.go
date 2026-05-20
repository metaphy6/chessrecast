// T-M-005 §9.5 — Upload data minimisation: only cryptographic proof fields
// may appear in the Transcript struct.
//
// Proof: enumerate Transcript struct fields via reflection and assert every
// JSON tag is in AllowedFields.  A field added by mistake (e.g. chat text,
// IP address, timestamps) will cause this test to fail.
package transcript_test

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"

	"github.com/chessrecast/signaling/internal/transcript"
)

// TestTranscriptFieldsAreMinimal is the T-M-005 proof test.
// It uses reflection to enumerate every JSON tag on Transcript and asserts
// each one is in the AllowedFields allowlist.
func TestTranscriptFieldsAreMinimal(t *testing.T) {
	rt := reflect.TypeOf(transcript.Transcript{})
	for i := 0; i < rt.NumField(); i++ {
		field := rt.Field(i)
		tag := field.Tag.Get("json")
		if tag == "" || tag == "-" {
			continue
		}
		// Strip omitempty and other options.
		name := strings.Split(tag, ",")[0]
		if !transcript.AllowedFields[name] {
			t.Errorf("field %q (json:%q) is not in AllowedFields — remove or justify it (T-M-005)", field.Name, name)
		}
	}
}

// TestAllowedFieldsArePresent verifies that every entry in AllowedFields
// actually maps to a struct field (guards against stale entries).
func TestAllowedFieldsArePresent(t *testing.T) {
	rt := reflect.TypeOf(transcript.Transcript{})
	present := map[string]bool{}
	for i := 0; i < rt.NumField(); i++ {
		tag := rt.Field(i).Tag.Get("json")
		if tag == "" || tag == "-" {
			continue
		}
		name := strings.Split(tag, ",")[0]
		present[name] = true
	}
	for allowed := range transcript.AllowedFields {
		if !present[allowed] {
			t.Errorf("AllowedFields contains %q but Transcript has no such field", allowed)
		}
	}
}

// TestTranscriptNoChatContent verifies that common chat-like field names
// do not appear in Transcript.
func TestTranscriptNoChatContent(t *testing.T) {
	forbidden := []string{"chat", "message", "text", "content", "timestamp", "ip", "user_id", "email"}
	raw, err := json.Marshal(transcript.Transcript{})
	if err != nil {
		t.Fatal(err)
	}
	s := strings.ToLower(string(raw))
	for _, f := range forbidden {
		if strings.Contains(s, f) {
			t.Errorf("Transcript JSON contains forbidden field %q (T-M-005)", f)
		}
	}
}
