package auth_test

import (
	"testing"

	"github.com/chessrecast/signaling/internal/auth"
)

// TestMinEngineReplayVersionAccepted verifies that an engine_replay_version
// at or above the operator floor is accepted.
func TestMinEngineReplayVersionAccepted(t *testing.T) {
	cases := []struct {
		clientVer uint32
		minVer    uint32
	}{
		{clientVer: 1, minVer: 1},
		{clientVer: 2, minVer: 1},
		{clientVer: 100, minVer: 1},
		{clientVer: 5, minVer: 5},
	}
	for _, tc := range cases {
		if err := auth.CheckMinEngineReplayVersion(tc.clientVer, tc.minVer); err != nil {
			t.Errorf("clientVer=%d minVer=%d: expected nil, got %v", tc.clientVer, tc.minVer, err)
		}
	}
}

// TestMinEngineReplayVersionRejected verifies that an engine_replay_version
// below the operator floor returns ErrEngineReplayVersionTooOld.
func TestMinEngineReplayVersionRejected(t *testing.T) {
	cases := []struct {
		clientVer uint32
		minVer    uint32
	}{
		{clientVer: 0, minVer: 1},
		{clientVer: 1, minVer: 2},
		{clientVer: 3, minVer: 10},
	}
	for _, tc := range cases {
		err := auth.CheckMinEngineReplayVersion(tc.clientVer, tc.minVer)
		if err == nil {
			t.Errorf("clientVer=%d minVer=%d: expected error, got nil", tc.clientVer, tc.minVer)
			continue
		}
		if err != auth.ErrEngineReplayVersionTooOld {
			t.Errorf("clientVer=%d minVer=%d: expected ErrEngineReplayVersionTooOld, got %v",
				tc.clientVer, tc.minVer, err)
		}
	}
}

// TestMinEngineReplayVersionFloorZero verifies that floor=0 accepts all
// non-negative versions (u32 is always ≥ 0 so this is a no-reject sentinel).
func TestMinEngineReplayVersionFloorZero(t *testing.T) {
	const minVer uint32 = 0
	cases := []uint32{0, 1, 100, 0xFFFF_FFFF}
	for _, v := range cases {
		if err := auth.CheckMinEngineReplayVersion(v, minVer); err != nil {
			t.Errorf("clientVer=%d with floor=0: expected nil, got %v", v, err)
		}
	}
}
