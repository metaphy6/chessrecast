// Package auth: min_client_version enforcement (§3.10).
package auth

import (
	"errors"
	"fmt"
	"strconv"
	"strings"
)

// ErrClientVersionTooOld is returned when the client version is below the server floor.
var ErrClientVersionTooOld = errors.New("CVE_REQUIRES_FORCED_UPDATE: client version is below the minimum required")

// Version is a semver-compatible version tuple (major.minor.patch).
type Version struct {
	Major, Minor, Patch int
}

// ParseVersion parses a "major.minor.patch" version string.
func ParseVersion(s string) (Version, error) {
	parts := strings.Split(s, ".")
	if len(parts) != 3 {
		return Version{}, fmt.Errorf("invalid version %q: want major.minor.patch", s)
	}
	var v Version
	var err error
	if v.Major, err = strconv.Atoi(parts[0]); err != nil {
		return Version{}, err
	}
	if v.Minor, err = strconv.Atoi(parts[1]); err != nil {
		return Version{}, err
	}
	if v.Patch, err = strconv.Atoi(parts[2]); err != nil {
		return Version{}, err
	}
	return v, nil
}

// Less returns true if v is older than other.
func (v Version) Less(other Version) bool {
	if v.Major != other.Major {
		return v.Major < other.Major
	}
	if v.Minor != other.Minor {
		return v.Minor < other.Minor
	}
	return v.Patch < other.Patch
}

// CheckMinClientVersion returns ErrClientVersionTooOld if clientVer is below minVer.
func CheckMinClientVersion(clientVer, minVer Version) error {
	if clientVer.Less(minVer) {
		return ErrClientVersionTooOld
	}
	return nil
}
