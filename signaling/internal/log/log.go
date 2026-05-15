// Package log provides structured logging with built-in PII redaction.
package log

import (
	"io"
	"os"
	"strings"
	"sync"
)

// piiFields lists field names that must never appear verbatim in log output.
var piiFields = []string{
	"email", "name", "full_ip", "phone", "dob", "raw_push_token",
	"password", "token", "secret",
}

// Logger is a minimal structured logger that redacts PII fields.
type Logger struct {
	mu  sync.Mutex
	out io.Writer
}

// New returns a Logger writing to w (defaults to os.Stderr if w is nil).
func New(w io.Writer) *Logger {
	if w == nil {
		w = os.Stderr
	}
	return &Logger{out: w}
}

// Log writes a key=value line, redacting any key that matches a PII field name.
func (l *Logger) Log(msg string, fields map[string]string) {
	var sb strings.Builder
	sb.WriteString("msg=")
	sb.WriteString(redactValue(msg, false))
	for k, v := range fields {
		sb.WriteByte(' ')
		sb.WriteString(k)
		sb.WriteByte('=')
		sb.WriteString(redactValue(v, isPIIField(k)))
	}
	sb.WriteByte('\n')

	l.mu.Lock()
	_, _ = l.out.Write([]byte(sb.String()))
	l.mu.Unlock()
}

func isPIIField(key string) bool {
	key = strings.ToLower(key)
	for _, f := range piiFields {
		if key == f || strings.Contains(key, f) {
			return true
		}
	}
	return false
}

func redactValue(v string, redact bool) string {
	if !redact {
		return v
	}
	if len(v) == 0 {
		return "[REDACTED]"
	}
	return "[REDACTED]"
}

// IsPIIField is exported for testing.
func IsPIIField(key string) bool { return isPIIField(key) }
