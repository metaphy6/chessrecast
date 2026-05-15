package store

import (
	"embed"
	"fmt"
)

//go:embed migrations
var migrationsFS embed.FS

// MigrationFile returns the raw bytes of a migration file by its relative path.
// Path should be of the form "migrations/000001_foo.up.sql".
func MigrationFile(path string) ([]byte, error) {
	data, err := migrationsFS.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("MigrationFile %q: %w", path, err)
	}
	return data, nil
}
