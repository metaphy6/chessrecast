// anon_join_rejected_test.go — §7.8.3 proof test (roadmap-named file)
package spectator_test

import (
	"testing"

	"github.com/chessrecast/signaling/internal/spectator"
)

// TestAnonJoinRejected_RoadmapProof is the primary proof test for §7.8.3.
func TestAnonJoinRejected_RoadmapProof(t *testing.T) {
	m := spectator.NewManager("anon_test", 0)

	cases := []struct {
		name            string
		isAuthenticated bool
		wantErr         string
	}{
		{"anonymous_nil_pubkey", false, spectator.ErrAuthRequired},
		{"authenticated_registered", true, ""},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			r := m.Admit("acc_"+tc.name, tc.isAuthenticated)
			if tc.wantErr != "" {
				if r.ErrCode != tc.wantErr {
					t.Fatalf("want err=%s got=%s", tc.wantErr, r.ErrCode)
				}
			} else {
				if r.ErrCode != "" {
					t.Fatalf("expected no error, got %s", r.ErrCode)
				}
			}
		})
	}
}
