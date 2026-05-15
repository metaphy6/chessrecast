// Command cve_watcher is a small cron service that polls security advisory
// feeds and writes new entries to the CVE queue (§3.10).
//
// In production it is run as a Kubernetes CronJob or ECS scheduled task once
// per day. For the v7 milestone the watcher runs in "dry-run" mode by default
// (WATCHER_DRY_RUN=true) so it can be exercised in tests without hitting real
// network endpoints.
package main

import (
	"fmt"
	"os"

	"github.com/chessrecast/signaling/internal/cve"
)

func main() {
	queuePath := os.Getenv("CVE_QUEUE_PATH")
	if queuePath == "" {
		queuePath = "internal/cve/queue.json"
	}

	q, err := cve.OpenQueue(queuePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "cve_watcher: open queue: %v\n", err)
		os.Exit(1)
	}

	dryRun := os.Getenv("WATCHER_DRY_RUN") != "false"
	if dryRun {
		fmt.Println("cve_watcher: dry-run mode; no external advisories fetched")
		entries := q.Entries()
		fmt.Printf("cve_watcher: %d existing entries in queue\n", len(entries))
		for _, e := range entries {
			patched := "unpatched"
			if e.IsPatched() {
				patched = "patched"
			}
			fmt.Printf("  %s [%s] %s (%s)\n", e.ID, e.Severity, e.Package, patched)
		}
		return
	}

	// Production: advisory polling would be wired here (GitHub Security
	// Advisories, NVD, Sigstore Rekor).  Stubbed until network layer is
	// provisioned.
	fmt.Println("cve_watcher: production polling not yet implemented; use dry-run")
	os.Exit(1)
}
