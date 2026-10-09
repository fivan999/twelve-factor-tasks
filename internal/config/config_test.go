package config

import (
	"strings"
	"testing"
)

func TestLoadRequiresPort(t *testing.T) {
	t.Setenv("PORT", "")
	t.Setenv("DATABASE_URL", "postgres://example")

	_, err := Load()
	if err == nil || !strings.Contains(err.Error(), "PORT is required") {
		t.Fatalf("Load() error = %v, want PORT is required", err)
	}
}

func TestLoadReadsRequiredConfig(t *testing.T) {
	t.Setenv("PORT", "8080")
	t.Setenv("DATABASE_URL", "postgres://example")
	t.Setenv("SHUTDOWN_TIMEOUT", "5s")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.Port != "8080" || cfg.DatabaseURL != "postgres://example" || cfg.ShutdownTimeout.String() != "5s" {
		t.Fatalf("unexpected config: %+v", cfg)
	}
}
